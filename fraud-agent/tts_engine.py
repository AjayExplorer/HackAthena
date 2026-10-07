"""
tts_engine.py — edge-tts → PCM audio pipeline
================================================
Uses Microsoft Edge TTS (free, no API key) to synthesize text and
return raw 16-bit PCM samples at 48 kHz / mono so they can be fed
directly into an aiortc AudioStreamTrack.
"""
import asyncio
import io
import struct

import edge_tts
import numpy as np

# Voice used for the fraud agent — confident, neutral US English male
FRAUD_VOICE = "en-US-GuyNeural"

# Target sample-rate and channel count expected by aiortc
SAMPLE_RATE = 48_000
CHANNELS = 1


async def synthesize_to_pcm(text: str) -> bytes:
    """
    Convert *text* to raw 16-bit little-endian PCM at SAMPLE_RATE Hz.
    Returns a bytes object ready to be decoded as np.int16 frames.
    """
    communicate = edge_tts.Communicate(text, FRAUD_VOICE)

    # Collect all audio chunks (MP3 bytes)
    mp3_chunks: list[bytes] = []
    async for chunk in communicate.stream():
        if chunk["type"] == "audio":
            mp3_chunks.append(chunk["data"])

    if not mp3_chunks:
        # Return 0.5 s of silence as a fallback
        silence_samples = SAMPLE_RATE // 2
        return struct.pack(f"<{silence_samples}h", *([0] * silence_samples))

    mp3_bytes = b"".join(mp3_chunks)
    pcm_bytes = _decode_mp3_to_pcm(mp3_bytes)
    return pcm_bytes


def _decode_mp3_to_pcm(mp3_bytes: bytes) -> bytes:
    """
    Decode MP3 bytes to 16-bit PCM at SAMPLE_RATE Hz.
    Priority:
      1. miniaudio  — pure Python, no external binaries needed
      2. pydub/ffmpeg — if ffmpeg is on PATH
      3. silence fallback
    """
    # ── 1. miniaudio (preferred) ──────────────────────────────────────
    try:
        import miniaudio
        decoded = miniaudio.decode(mp3_bytes, output_format=miniaudio.SampleFormat.SIGNED16,
                                   nchannels=CHANNELS, sample_rate=SAMPLE_RATE)
        return bytes(decoded.samples)
    except Exception as exc:
        print(f"[TTS] miniaudio decode failed: {exc}. Trying pydub...")

    # ── 2. pydub + ffmpeg ─────────────────────────────────────────────
    try:
        from pydub import AudioSegment
        audio = AudioSegment.from_file(io.BytesIO(mp3_bytes), format="mp3")
        audio = audio.set_channels(CHANNELS).set_frame_rate(SAMPLE_RATE).set_sample_width(2)
        return audio.raw_data
    except Exception as exc:
        print(f"[TTS] pydub decode failed: {exc}. Returning silence.")

    # ── 3. Silence fallback ───────────────────────────────────────────
    silence_samples = SAMPLE_RATE // 2
    return struct.pack(f"<{silence_samples}h", *([0] * silence_samples))


def pcm_to_frames(pcm_bytes: bytes, samples_per_frame: int = 960) -> list[np.ndarray]:
    """
    Split a flat PCM byte string into fixed-size numpy int16 frames
    compatible with aiortc's AudioFrame API.
    Each frame is (channels, samples_per_frame) shaped.
    """
    samples = np.frombuffer(pcm_bytes, dtype=np.int16)
    frames = []
    for start in range(0, len(samples), samples_per_frame):
        chunk = samples[start : start + samples_per_frame]
        if len(chunk) < samples_per_frame:
            # Pad the last frame with silence
            chunk = np.pad(chunk, (0, samples_per_frame - len(chunk)))
        frames.append(chunk.reshape(1, samples_per_frame))
    return frames
