"""
audio_track.py — Pushable AudioStreamTrack for aiortc
=======================================================
Allows the fraud agent to push numpy int16 frames into a queue that
is consumed by aiortc's MediaPlayer / RTCPeerConnection as a live
audio track — no file needed.
"""
import asyncio
import fractions
import time

import numpy as np
from aiortc import MediaStreamTrack
from av import AudioFrame

SAMPLE_RATE = 48_000
CHANNELS = 1
SAMPLES_PER_FRAME = 960          # 20 ms at 48 kHz


class PushAudioStreamTrack(MediaStreamTrack):
    """
    An audio track that we can push PCM data into on demand.
    While idle it emits silence; when speak() is called the frames
    are played out in order.
    """

    kind = "audio"

    def __init__(self):
        super().__init__()
        self._queue: asyncio.Queue[np.ndarray | None] = asyncio.Queue()
        self._timestamp = 0
        self._started = False

    # ------------------------------------------------------------------
    # Public API
    # ------------------------------------------------------------------

    def push_frames(self, frames: list[np.ndarray]):
        """Enqueue a list of (1, 960) int16 frames for playback."""
        for f in frames:
            self._queue.put_nowait(f)

    def push_silence(self, n_frames: int = 1):
        """Enqueue *n_frames* frames of silence."""
        silence = np.zeros((CHANNELS, SAMPLES_PER_FRAME), dtype=np.int16)
        for _ in range(n_frames):
            self._queue.put_nowait(silence)

    async def wait_for_drain(self):
        """Block until the audio queue is completely empty (all frames played)."""
        while not self._queue.empty():
            await asyncio.sleep(0.05)

    # ------------------------------------------------------------------
    # aiortc interface
    # ------------------------------------------------------------------

    async def recv(self) -> AudioFrame:
        """Called by aiortc ~50 times/second (every 20 ms) to pull a frame."""
        # Pacing: delay frame generation to match real-time playback
        if not hasattr(self, "_start"):
            self._start = time.time()
            
        wait = self._start + (self._timestamp / SAMPLE_RATE) - time.time()
        if wait > 0:
            await asyncio.sleep(wait)

        # Try to get a queued frame (non-blocking); fall back to silence
        try:
            samples = self._queue.get_nowait()
        except asyncio.QueueEmpty:
            samples = np.zeros((CHANNELS, SAMPLES_PER_FRAME), dtype=np.int16)

        frame = AudioFrame(format="s16", layout="mono", samples=SAMPLES_PER_FRAME)
        frame.planes[0].update(samples.tobytes())
        frame.sample_rate = SAMPLE_RATE
        frame.time_base = fractions.Fraction(1, SAMPLE_RATE)
        frame.pts = self._timestamp
        self._timestamp += SAMPLES_PER_FRAME
        return frame
