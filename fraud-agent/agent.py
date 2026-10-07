"""
AegisMesh — Fraud Agent (USER-1234)
=====================================
Simulates a scammer who:
  1. Authenticates as USER-1234 (via Firebase service-account key)
  2. Places an outbound WebRTC call to the target victim
  3. Synthesizes speech with edge-tts and streams PCM audio over the WebRTC track
  4. Listens for the victim's speech (transcribed by the browser Web-Speech API
     and forwarded by the detection server)
  5. When the scripted lines are exhausted OR the victim asks something unexpected,
     it falls back to the Groq LLM brain (qwen/qwen3.8-27b) for a dynamic reply

Architecture
------------
  fraud-agent ──(WebRTC audio)──▶ victim's browser
  fraud-agent ──(HTTP POST)────▶ detection server  (SCAMMER_SPEECH event)
  fraud-agent ◀──(HTTP GET)────  detection server  (victim STT text via Web Speech API)
  fraud-agent ──(edge-tts)────▶ PCM ──▶ WebRTC track ──▶ victim audio

Usage:
    python agent.py <VICTIM-UID>
"""
import asyncio
import os
import sys
import wave
import io
import numpy as np

import aiohttp
from dotenv import load_dotenv
from groq import AsyncGroq
import librosa
import random

USE_MOCK_ACOUSTICS = os.getenv("USE_MOCK_ACOUSTICS", "True").lower() == "true"

# Load GROQ_API_KEY from the detection-server .env (sibling directory)
_here = os.path.dirname(os.path.abspath(__file__))
for _env_candidate in [
    os.path.join(_here, ".env"),
    os.path.join(_here, "..", "detection-server", ".env"),
    os.path.join(_here, "..", ".env"),
]:
    if os.path.exists(_env_candidate):
        load_dotenv(_env_candidate)
        print(f"[AGENT] Loaded .env from {_env_candidate}")
        break

from agent_brain import FraudAgentBrain          # noqa: E402  (after env load)
from audio_track import PushAudioStreamTrack      # noqa: E402
from tts_engine import synthesize_to_pcm, pcm_to_frames  # noqa: E402
from webrtc_client import WebRTCClient            # noqa: E402

SCAMMER_UID = "USER-1234"

# Detection-server endpoints
_DS_BASE = "http://localhost:8000"
_SPEAK_URL = f"{_DS_BASE}/api/scammer_speak"
_WAIT_URL  = f"{_DS_BASE}/api/wait_for_user_speech"
_END_URL   = f"{_DS_BASE}/api/end_call"

# How long to wait for the victim to reply before falling back to the script (seconds)
_VICTIM_WAIT_TIMEOUT = 12.0

# Pause between script lines when there is no victim reply (seconds)
_SCRIPT_PAUSE = 3.5

# How many times to retry scammer_speak when Flutter WS isn't registered yet
_SPEAK_RETRIES = 8
_SPEAK_RETRY_DELAY = 2.0   # seconds between retries

class VictimSTTRecorder:
    """Consumes the WebRTC track from the victim and records audio for Whisper STT."""
    def __init__(self, victim_uid):
        self.victim_uid = victim_uid
        api_key = os.getenv("GROQ_API_KEY")
        self.groq_client = AsyncGroq(api_key=api_key) if api_key else None
        self.track = None
        self.recording = False
        self.buffer = []

    async def process_acoustic_telemetry(self, audio_data: bytes, text: str, duration: float):
        wpm = len(text.split()) / max(duration / 60.0, 0.01) if text else 0.0

        if USE_MOCK_ACOUSTICS:
            print("[AGENT - MOCK ACOUSTICS] Generating mock acoustic telemetry...")
            pitch_variance = random.uniform(0.01, 0.04) if "password" in text.lower() or "urgent" in text.lower() else random.uniform(0.1, 0.3)
        else:
            print("[AGENT - REAL ACOUSTICS] Running librosa.pyin()...")
            try:
                audio_np = np.frombuffer(audio_data, dtype=np.int16).astype(np.float32) / 32768.0
                loop = asyncio.get_running_loop()
                f0, voiced_flag, voiced_prob = await loop.run_in_executor(
                    None, lambda: librosa.pyin(audio_np, fmin=50, fmax=500, sr=48000))
                
                valid_f0 = f0[voiced_flag]
                if len(valid_f0) > 0:
                    pitch_variance = float(np.var(valid_f0)) / 1000.0
                else:
                    pitch_variance = 0.1
            except Exception as e:
                print(f"[Acoustic Error] {e}")
                pitch_variance = 0.1

        telemetry = {
            "callee": self.victim_uid,
            "pitch_variance": pitch_variance,
            "wpm": wpm
        }
        try:
            async with aiohttp.ClientSession() as session:
                await session.post("http://localhost:8000/api/telemetry", json=telemetry)
        except Exception as e:
            print(f"[Telemetry Error] {e}")

    def start_track_consumer(self, track):
        self.track = track
        asyncio.create_task(self._consume())
        
    async def _consume(self):
        while True:
            try:
                frame = await self.track.recv()
                if self.recording:
                    arr = frame.to_ndarray()
                    self.buffer.append(arr.tobytes())
            except Exception:
                break
                
    async def listen_and_transcribe(self, duration: float = 4.0) -> str:
        if not self.track or not self.groq_client:
            await asyncio.sleep(duration)
            return ""
            
        self.buffer = []
        self.recording = True
        print(f"[STT] Listening to victim for {duration}s...")
        await asyncio.sleep(duration)
        self.recording = False
        
        if not self.buffer:
            return ""
            
        audio_data = b"".join(self.buffer)
        
        # ── PREVENT HALLUCINATIONS ON SILENCE ──
        # Check the RMS volume of the audio buffer. If it's too quiet (just background static),
        # return empty string instead of sending to Whisper, as Whisper hallucinates on silence.
        audio_np = np.frombuffer(audio_data, dtype=np.int16)
        rms = np.sqrt(np.mean(audio_np.astype(np.float32)**2))
        if rms < 50.0:  # Silence threshold
            print(f"[STT] Audio too quiet (RMS: {rms:.1f}), skipping transcription.")
            return ""
            
        wav_io = io.BytesIO()
        with wave.open(wav_io, 'wb') as wav_file:
            wav_file.setnchannels(1)
            wav_file.setsampwidth(2)
            wav_file.setframerate(48000)
            wav_file.writeframes(audio_data)
            
        wav_io.seek(0)
        
        try:
            resp = await self.groq_client.audio.transcriptions.create(
                file=("audio.wav", wav_io.read()),
                model="whisper-large-v3",
                response_format="json"
            )
            text = resp.text.strip()
            
            # ── ACOUSTIC TELEMETRY MOVED ──
            # The fraud agent should analyze its OWN synthetic audio for liveness telemetry, 
            # not the victim's microphone audio. Moved to `_speak()`.
            
            return text
        except Exception as e:
            print(f"[STT Error] {e}")
            return ""

class ScamAgent:
    """
    Fully automated fraud agent with:
      • edge-tts voice synthesis streamed over WebRTC
      • Groq LLM dynamic replies when victim speaks
      • Detection-server integration (threat scoring + Evelyn interception)
    """

    OPENING_SCRIPT = [
        "Hello, this is a security alert from your bank's fraud prevention department.",
        "We have detected suspicious activity on your account in the last 24 hours.",
        "To verify your identity and secure your account, I need to confirm a few details.",
        "An OTP has been sent to your registered mobile number. Please read it out to me now.",
        "This is urgent — failure to act within 5 minutes will result in your account being suspended.",
        "Can you confirm the one-time password you just received? We need it to stop the fraudulent transfer.",
    ]

    def __init__(self, victim_uid: str, audio_track: PushAudioStreamTrack, stt_recorder: VictimSTTRecorder):
        self.victim_uid = victim_uid
        self.audio_track = audio_track
        self.stt_recorder = stt_recorder
        self.brain = FraudAgentBrain()

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    async def _wait_for_call_registered(self, session: aiohttp.ClientSession, timeout: float = 30.0) -> bool:
        """
        Poll the detection server until the Flutter WebSocket has registered
        this callee_id in active_calls (i.e., GET /api/wait_for_user_speech
        returns something other than {"error": "Call not found"}).
        Returns True when the call is registered, False on timeout.
        """
        deadline = asyncio.get_event_loop().time() + timeout
        print(f"[AGENT] Waiting for Flutter WebSocket to register call for {self.victim_uid} ...")
        while asyncio.get_event_loop().time() < deadline:
            try:
                # Probe by calling wait_for_user_speech with a very short timeout
                # If it returns {"error": "Call not found"} the WS isn't up yet.
                # If it returns {"text": ...} or blocks, the call IS registered.
                async with session.get(
                    f"http://localhost:8000/api/call_registered?callee={self.victim_uid}",
                    timeout=aiohttp.ClientTimeout(total=3),
                ) as resp:
                    data = await resp.json()
                    if data.get("registered"):
                        print(f"[AGENT] Flutter WebSocket registered! Proceeding.")
                        return True
            except Exception:
                pass
            await asyncio.sleep(1.5)
        print(f"[AGENT] Timed out waiting for Flutter WebSocket — proceeding anyway.")
        return False

    async def _speak(self, session: aiohttp.ClientSession, text: str) -> tuple[str, str]:
        """
        1. Synthesize *text* with edge-tts → push PCM to the WebRTC track (victim hears it)
        2. POST to detection server (threat scoring + Flutter transcript)
           Retries up to _SPEAK_RETRIES times if Flutter WS isn't registered yet.
        Returns a tuple of (status, evelyn_reply).
        """
        print(f"\n[SCAMMER >>] {text}")
        evelyn_speech_duration_s = 0.0
        evelyn_reply_text = ""

        # ── 1. Synthesize & stream audio ──────────────────────────────────
        duration_s = 0.0
        try:
            pcm = await synthesize_to_pcm(text)
            frames = pcm_to_frames(pcm)
            self.audio_track.push_frames(frames)
            duration_s = len(frames) * 0.02  # 20ms per frame
            print(f"[TTS] Pushed {len(frames)} frames ({duration_s:.1f}s audio) to WebRTC track.")
            
            # Analyze the generated scammer voice for liveness telemetry
            asyncio.create_task(self.stt_recorder.process_acoustic_telemetry(pcm, text, max(duration_s, 1.0)))
        except Exception as exc:
            print(f"[TTS] Synthesis failed: {exc}")

        # ── 2. Notify detection server (with retry on "Call not found") ──────────
        status = "listening"
        for attempt in range(1, _SPEAK_RETRIES + 1):
            try:
                async with session.post(
                    _SPEAK_URL,
                    json={"callee": self.victim_uid, "text": text, "audio_duration_s": duration_s},
                    timeout=aiohttp.ClientTimeout(total=8),
                ) as resp:
                    data = await resp.json()

                    # "Call not found" means Flutter WS not registered yet — retry
                    if data.get("error") == "Call not found":
                        if attempt == 1:
                            print(f"[AGENT] Flutter WS not registered on detection-server (threat scoring disabled)...")
                        await asyncio.sleep(_SPEAK_RETRY_DELAY)
                        continue

                    status = data.get("status", "listening")
                    if status == "call_ended":
                        print("[AGENT] Server indicated call is already ended.")
                        return "call_ended", ""
                        
                    if status == "intercepted":
                        evelyn_reply = data.get("evelyn_reply", "")
                        if evelyn_reply:
                            evelyn_reply_text = evelyn_reply
                            print(f"[EVELYN **] {evelyn_reply}")
                            # Track Evelyn's reply length to add to the final pause (slower TTS rate)
                            evelyn_speech_duration_s = len(evelyn_reply) / 13.0
                    break

            except aiohttp.ClientConnectorError:
                # Server not reachable at all — this IS a fatal error
                print(f"[AGENT] Cannot reach detection server (connection refused).")
                return "error", ""
            except Exception as exc:
                print(f"[AGENT] Detection-server error: {exc} (attempt {attempt}/{_SPEAK_RETRIES})")
                await asyncio.sleep(_SPEAK_RETRY_DELAY)

        # ── 3. Wait for audio playback to actually complete in real-time ────────
        if duration_s > 0:
            await self.audio_track.wait_for_drain()
            
        # Tell the server our audio is fully done playing
        try:
            async with session.post(f"{_DS_BASE}/api/scammer_audio_end", json={"callee": self.victim_uid, "text": ""}) as resp:
                pass
        except Exception:
            pass

        # ── 4. Wait for Evelyn to finish speaking if she intercepted ────────
        if status == "intercepted":
            print(f"[AGENT] Waiting {evelyn_speech_duration_s:.1f}s for Evelyn TTS to finish...")
            await asyncio.sleep(evelyn_speech_duration_s)

        return status, evelyn_reply_text

    async def _wait_for_victim(self, session: aiohttp.ClientSession) -> str:
        """
        Records the victim's voice via WebRTC for a few seconds, runs it through Groq Whisper,
        and posts the transcribed text to the detection server's /api/victim_speak endpoint.
        """
        try:
            # Listen and transcribe
            text = await self.stt_recorder.listen_and_transcribe(duration=4.0)
            
            # If the user actually said something, post it to the detection server
            if text and len(text) > 1:
                url = f"{_DS_BASE}/api/victim_speak"
                async with session.post(url, json={"callee": self.victim_uid, "text": text}) as resp:
                    pass
                return text
            return ""
        except Exception as exc:
            print(f"[AGENT] wait_for_victim STT error: {exc}")
            return ""

    async def _end_call(self, session: aiohttp.ClientSession):
        try:
            async with session.post(_END_URL, json={"callee": self.victim_uid}) as resp:
                pass
        except Exception:
            pass

    # ------------------------------------------------------------------
    # Main conversation loop
    # ------------------------------------------------------------------

    async def run(self):
        print(f"[AGENT] Starting scam conversation with {self.victim_uid} ...")

        async with aiohttp.ClientSession() as session:
            # Wait up to 30 s for Flutter to open its WebSocket to the detection server
            await self._wait_for_call_registered(session, timeout=30.0)

            script_idx = 0
            status = "listening"
            last_evelyn_reply = ""

            while True:
                # ── A. If Evelyn intercepted, converse with Evelyn ──
                if status == "intercepted":
                    print("[AGENT] Evelyn intercepted! Scam agent conversing with Evelyn...")
                    ai_line = await self.brain.respond(last_evelyn_reply if last_evelyn_reply else "Who is this?")
                    status, last_evelyn_reply = await self._speak(session, ai_line)
                    continue

                # ── B. Speak the next scripted line if we haven't started yet ──
                if script_idx < len(self.OPENING_SCRIPT) and script_idx == 0:
                    status, last_evelyn_reply = await self._speak(session, self.OPENING_SCRIPT[script_idx])
                    script_idx += 1
                    continue

                # ── C. Wait for victim to respond ─────────────────────────────
                print(f"[AGENT] Waiting up to {_VICTIM_WAIT_TIMEOUT}s for victim to speak ...")
                victim_text = await self._wait_for_victim(session)

                if victim_text:
                    print(f"[VICTIM 🎤] {victim_text}")
                    # Generate AI reply
                    reply = await self.brain.respond(victim_text)
                    status, last_evelyn_reply = await self._speak(session, reply)
                else:
                    # No reply — push the next scripted line or AI prod
                    print("[AGENT] Victim silent. Continuing script...")
                    if script_idx < len(self.OPENING_SCRIPT):
                        status, last_evelyn_reply = await self._speak(session, self.OPENING_SCRIPT[script_idx])
                        script_idx += 1
                    else:
                        # Script exhausted — LLM generates a prod
                        prod = await self.brain.respond("The victim is silent. Prod them urgently.")
                        status, last_evelyn_reply = await self._speak(session, prod)

                # Small breath between turns
                await asyncio.sleep(1.5)

                # ── D. Only abort on true connection failure (server down) ──────────
                # "no_ws" means Flutter WS not connected but server IS up — keep going.
                # "error" means connection refused — abort.
                if status == "error":
                    print("[AGENT] Detection server connection refused — ending call.")
                    break
                elif status == "call_ended":
                    print("[AGENT] Call was ended by the victim — terminating agent.")
                    break

        print("[AGENT] Scam conversation complete.")


# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------

async def main(victim_uid: str):
    print(f"[USER-1234] Fraud agent starting — target: {victim_uid}")

    # Create the pushable audio track BEFORE the WebRTC peer connection so
    # we can add it to the offer (track must be added before createOffer).
    audio_track = PushAudioStreamTrack()

    # Initialise WebRTC client as USER-1234
    client = WebRTCClient(audio_track=audio_track)
    
    # Initialise STT Recorder and attach to incoming track
    recorder = VictimSTTRecorder(victim_uid)
    client.on_audio_track = recorder.start_track_consumer

    # Create the scam agent
    agent = ScamAgent(victim_uid, audio_track, recorder)

    async def run_conversation_after_connect():
        """
        Wait for WebRTC to be truly connected (SDP answer applied + ICE wired),
        then give the Flutter/browser side 2 more seconds to open its WebSocket
        to the detection server before the first scammer line is spoken.
        """
        print("[AGENT] Waiting for WebRTC connection to be established...")
        try:
            await asyncio.wait_for(client.connected_event.wait(), timeout=90)
        except asyncio.TimeoutError:
            print("[AGENT] WebRTC connect timeout — aborting conversation.")
            return

        # Give the browser/Flutter app 2 s to open its WebSocket to the
        # detection server and send the call_start handshake.
        print("[AGENT] WebRTC connected! Waiting 2s for detection-server handshake...")
        await asyncio.sleep(2)
        await agent.run()

    # Start conversation in the background — it fires after WebRTC connects
    asyncio.create_task(run_conversation_after_connect())

    # USER-1234 places the outbound WebRTC call (blocks until call ends)
    await client.call_user(victim_uid)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python agent.py <VICTIM-UID>")
        sys.exit(1)

    asyncio.run(main(sys.argv[1]))
