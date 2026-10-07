import asyncio
import json
import os
import firebase_admin
from firebase_admin import credentials, firestore
from aiortc import RTCPeerConnection, RTCSessionDescription, RTCIceCandidate, MediaStreamTrack
from aiortc.sdp import candidate_from_sdp
from dotenv import load_dotenv

load_dotenv()

# Optional — imported lazily so webrtc_client can still be used standalone
try:
    from audio_track import PushAudioStreamTrack
except ImportError:
    PushAudioStreamTrack = None

# Scammer bot credentials — account seeded in Firestore as USER-1234
SCAMMER_UID  = "USER-1234"
SCAMMER_EMAIL = "scammer.bot@aegismesh.internal"


class WebRTCClient:
    """
    Headless WebRTC client that runs as USER-1234 (the scammer bot).

    Outbound flow  (scammer calls a victim):
        client = WebRTCClient()
        asyncio.run(client.call_user("VICTIM-UID"))

    Inbound flow  (victim calls the scammer, kept for completeness):
        asyncio.run(client.listen_for_calls())
    """

    def __init__(self, audio_track=None):
        """
        Parameters
        ----------
        audio_track : PushAudioStreamTrack | None
            When provided the track is added to the RTCPeerConnection so the
            fraud agent's synthesized PCM audio is sent to the victim.
        """
        self.agent_id = SCAMMER_UID
        self.pc = RTCPeerConnection()
        self.db = None
        self.current_call_id = None
        self.audio_track = audio_track

        # Signals when WebRTC is fully connected (answer applied + ICE ready)
        # The fraud agent waits on this before starting the conversation.
        self.connected_event: asyncio.Event = asyncio.Event()

        # Add the outbound audio track BEFORE createOffer so it is negotiated
        if audio_track is not None:
            self.pc.addTrack(audio_track)
            print("[WebRTC] Outbound audio track added to peer connection.")

        # Callback: called when audio track arrives from the victim
        self.on_audio_track = None

        @self.pc.on("track")
        def on_track(track):
            if track.kind == "audio":
                print(f"[WebRTC] Received remote audio track from victim.")
                if self.on_audio_track:
                    self.on_audio_track(track)

    # ------------------------------------------------------------------
    # Firebase
    # ------------------------------------------------------------------

    def _init_firebase(self):
        key_path = os.getenv("FIREBASE_KEY_PATH", "serviceAccountKey.json")
        if not os.path.exists(key_path):
            raise FileNotFoundError(
                f"Firebase service-account key not found at '{key_path}'."
            )
        if not firebase_admin._apps:
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
        self.db = firestore.client()
        print("[WebRTC] Firebase Admin initialised.")

    # ------------------------------------------------------------------
    # OUTBOUND CALL  —  Scammer (USER-1234) calls a victim
    # ------------------------------------------------------------------

    async def call_user(self, victim_uid: str):
        """
        Places an outbound call from USER-1234 to victim_uid.
        Mirrors the Firestore signalling flow used by the Flutter app:
          1. Create /calls doc  (status=CALLING)
          2. Create SDP offer   (status=RINGING)
          3. Wait for victim's SDP answer
          4. Exchange ICE candidates
          5. Keep connection alive while the fraud agent converses
        """
        self._init_firebase()
        print(f"[WebRTC] USER-1234 is calling victim: {victim_uid} ...")

        # 1 — Create call document (identical schema to Flutter app)
        call_ref = self.db.collection("calls").document()
        call_ref.set({
            "callerId":    self.agent_id,
            "recipientId": victim_uid,
            "status":      "CALLING",
            "createdAt":   firestore.SERVER_TIMESTAMP,
            "threatScore": 0.0,
        })
        self.current_call_id = call_ref.id
        print(f"[WebRTC] Call document created: {self.current_call_id}")

        # 2 — Create SDP offer and push to Firestore
        offer = await self.pc.createOffer()
        await self.pc.setLocalDescription(offer)

        call_ref.update({
            "offer": {
                "type": self.pc.localDescription.type,
                "sdp":  self.pc.localDescription.sdp,
            },
            "status": "RINGING",
        })
        print("[WebRTC] SDP Offer sent — waiting for victim to answer ...")

        # 3 — Wait for victim's SDP answer
        await self._wait_for_answer(call_ref)

        # 4 — Exchange ICE candidates
        self._push_ice_candidates(call_ref)
        self._listen_for_victim_ice(call_ref)

        # Signal conversation layer: WebRTC is now fully connected
        self.connected_event.set()
        print("[WebRTC] Call CONNECTED — fraud agent takes over conversation.")
        # Keep alive while the fraud agent is running
        while True:
            await asyncio.sleep(1)

    async def _wait_for_answer(self, call_ref, timeout: int = 60):
        """Poll Firestore until the victim's app pushes an SDP answer."""
        loop = asyncio.get_event_loop()
        answer_event = asyncio.Event()

        def on_snapshot(doc_snapshot, changes, read_time):
            for doc in doc_snapshot:
                data = doc.to_dict()
                if data and data.get("answer"):
                    answer_data = data["answer"]
                    answer = RTCSessionDescription(
                        sdp=answer_data["sdp"],
                        type=answer_data["type"],
                    )
                    # Schedule coroutine safely from the Firestore thread
                    asyncio.run_coroutine_threadsafe(
                        self._apply_answer(answer, answer_event), loop
                    )

        watch = call_ref.on_snapshot(on_snapshot)
        try:
            await asyncio.wait_for(answer_event.wait(), timeout=timeout)
        except asyncio.TimeoutError:
            print("[WebRTC] Victim did not answer — hanging up.")
            call_ref.update({"status": "ENDED"})
        finally:
            watch.unsubscribe()

    async def _apply_answer(self, answer: RTCSessionDescription, event: asyncio.Event):
        await self.pc.setRemoteDescription(answer)
        print("[WebRTC] Victim answered — SDP Answer applied.")
        event.set()

    def _push_ice_candidates(self, call_ref):
        """Send local ICE candidates (scammer side) to Firestore."""
        @self.pc.on("icecandidate")
        def on_icecandidate(candidate):
            if candidate:
                call_ref.collection("callerCandidates").add({
                    "candidate":     candidate.candidate,
                    "sdpMid":        candidate.sdpMid,
                    "sdpMLineIndex": candidate.sdpMLineIndex,
                })

    def _listen_for_victim_ice(self, call_ref):
        """Receive ICE candidates from the victim's app."""
        loop = asyncio.get_event_loop()

        def on_snapshot(col_snapshot, changes, read_time):
            for change in changes:
                if change.type.name == "ADDED":
                    data = change.document.to_dict()
                    if data and data.get("candidate"):
                        try:
                            # aiortc ≥ 1.6: use candidate_from_sdp then set sdpMid/Index
                            ice = candidate_from_sdp(data["candidate"].split("candidate:", 1)[-1])
                            ice.sdpMid = data.get("sdpMid", "0")
                            ice.sdpMLineIndex = data.get("sdpMLineIndex", 0)
                            asyncio.run_coroutine_threadsafe(
                                self.pc.addIceCandidate(ice), loop
                            )
                        except Exception as exc:
                            print(f"[WebRTC] ICE candidate error (victim): {exc}")

        call_ref.collection("calleeCandidates").on_snapshot(on_snapshot)

    # ------------------------------------------------------------------
    # INBOUND CALL  —  listen if someone calls USER-1234 (kept for tests)
    # ------------------------------------------------------------------

    async def listen_for_calls(self):
        self._init_firebase()
        print(f"[WebRTC] {self.agent_id} listening for INCOMING calls ...")

        calls_ref = self.db.collection("calls")
        query = (
            calls_ref
            .where("recipientId", "==", self.agent_id)
            .where("status", "==", "RINGING")
        )

        def on_snapshot(col_snapshot, changes, read_time):
            for change in changes:
                if change.type.name in ("ADDED", "MODIFIED"):
                    doc  = change.document
                    data = doc.to_dict()
                    if data and "offer" in data:
                        self.current_call_id = doc.id
                        print(f"[WebRTC] Incoming call: {self.current_call_id}")
                        asyncio.create_task(
                            self.handle_incoming_offer(self.current_call_id, data["offer"])
                        )

        query.on_snapshot(on_snapshot)
        while True:
            await asyncio.sleep(1)

    async def handle_incoming_offer(self, call_id: str, offer_data: dict):
        offer = RTCSessionDescription(sdp=offer_data["sdp"], type=offer_data["type"])
        await self.pc.setRemoteDescription(offer)

        answer = await self.pc.createAnswer()
        await self.pc.setLocalDescription(answer)

        self.db.collection("calls").document(call_id).update({
            "answer": {
                "type": self.pc.localDescription.type,
                "sdp":  self.pc.localDescription.sdp,
            },
            "status": "CONNECTED",
        })
        self._listen_for_caller_ice(call_id)

    def _listen_for_caller_ice(self, call_id: str):
        col_ref = self.db.collection("calls").document(call_id).collection("callerCandidates")
        loop = asyncio.get_event_loop()

        def on_snapshot(col_snapshot, changes, read_time):
            for change in changes:
                if change.type.name == "ADDED":
                    data = change.document.to_dict()
                    if data and data.get("candidate"):
                        try:
                            ice = candidate_from_sdp(data["candidate"].split("candidate:", 1)[-1])
                            ice.sdpMid = data.get("sdpMid", "0")
                            ice.sdpMLineIndex = data.get("sdpMLineIndex", 0)
                            asyncio.run_coroutine_threadsafe(
                                self.pc.addIceCandidate(ice), loop
                            )
                        except Exception as exc:
                            print(f"[WebRTC] ICE candidate error (caller): {exc}")

        col_ref.on_snapshot(on_snapshot)


# ------------------------------------------------------------------
# Quick CLI test:
#   python webrtc_client.py <VICTIM-UID>
# ------------------------------------------------------------------
if __name__ == "__main__":
    import sys
    victim = sys.argv[1] if len(sys.argv) > 1 else "VICTIM-UID"
    client = WebRTCClient()
    try:
        asyncio.run(client.call_user(victim))
    except Exception as e:
        print(e)
