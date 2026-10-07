import asyncio
import json
import os
import re
from fastapi import FastAPI, WebSocket, WebSocketDisconnect
from pydantic import BaseModel
from evelyn_agent import EvelynAgent
from typing import Dict
from dotenv import load_dotenv

load_dotenv()

try:
    from groq import AsyncGroq
    _groq_client = AsyncGroq(api_key=os.getenv("GROQ_API_KEY"))
except ImportError:
    _groq_client = None

app = FastAPI(title="CallGuard AI - Detection Server")

# Multi-Modal State
active_calls: Dict[str, dict] = {}

class ScammerMessage(BaseModel):
    callee: str
    text: str

@app.get("/")
def root():
    return {"status": "CallGuard AI Detection Server running"}

async def broadcast_state(callee_id: str):
    """Sends the multi-modal risk state to the Flutter UI."""
    if callee_id not in active_calls:
        return
    call_data = active_calls[callee_id]
    ws = call_data["websocket"]
    try:
        await ws.send_text(json.dumps({
            "event": "RISK_STATE_UPDATE",
            "risk_score": call_data["risk_score"],
            "liveness_score": call_data["liveness_score"],
            "synthetic_probability": call_data["synthetic_probability"],
            "temporal_variance": call_data["temporal_variance"],
            "stress_score": call_data["stress_score"],
            "semantic_threat_probability": call_data["semantic_threat_probability"],
            "speaking_rate": call_data["speaking_rate"],
        }))
        
        # Backward compatibility for the current Flutter UI which expects a score between 0.0 and 1.0
        normalized_score = min(call_data["risk_score"] / 100.0, 1.0)
        await ws.send_text(json.dumps({
            "event": "THREAT_SCORE_UPDATE",
            "score": normalized_score,
            "intercept_recommended": call_data["risk_score"] >= 85,
        }))
    except Exception:
        pass

async def check_interception_threshold(callee_id: str):
    """Central logic to trigger handoff if risk >= 85."""
    if callee_id not in active_calls:
        return
    call_data = active_calls[callee_id]
    
    if call_data["risk_score"] >= 85 and not call_data["intercepted"]:
        call_data["intercepted"] = True
        print(f"🚨 THRESHOLD REACHED ({call_data['risk_score']} pts): TRIGGERING AGENT HANDOFF!")
        
        ws = call_data["websocket"]
        try:
            await ws.send_text(json.dumps({
                "event": "INTERCEPT_CALL",
                "reason": "High fraud probability: Multi-Modal threshold exceeded.",
                "agent": "Evelyn",
            }))
            
            # Agent Handoff logic
            await asyncio.sleep(1)
            reply = await call_data["evelyn"].generate_response("The call was intercepted due to severe security risks. Acknowledge and secure the user.")
            
            await ws.send_text(json.dumps({
                "event": "EVELYN_SPEECH",
                "text": reply,
            }))
            await ws.send_text(json.dumps({
                "event": "TRANSCRIPT_UPDATE",
                "speaker": "Evelyn",
                "text": reply,
            }))
        except Exception:
            pass

async def calculate_dynamic_threat_llm(text: str) -> float:
    """Uses Groq LLM to analyze the transcript and return a probability (0.0 to 1.0)."""
    if not _groq_client:
        return 0.15
        
    prompt = f"""You are an advanced fraud detection AI analyzing a phone call transcript sentence.
Your job is to determine the threat level of this sentence in the context of a potential scam (e.g., tech support, IRS, bank fraud).
Return a SINGLE FLOAT NUMBER between 0.00 and 1.00 representing the threat probability.

Guidelines:
- 0.0 to 0.1: Benign conversation, greetings, standard questions.
- 0.2 to 0.4: Suspicious requests, asking for personal details, high-pressure urgency.
- 0.5 to 0.7: Mentions of bank accounts, SSN, passwords, or downloading software (AnyDesk).
- 0.8 to 1.0: Direct scam indicators (asking for wire transfers, gift cards, stating "safe account", threatening arrest).

Sentence to analyze: "{text}"

Output ONLY the float number (e.g. 0.85) and nothing else.
"""
    try:
        response = await _groq_client.chat.completions.create(
            model="qwen/qwen3.8-27b",
            messages=[{"role": "user", "content": prompt}],
            max_tokens=10,
            temperature=0.0
        )
        score_str = response.choices[0].message.content.strip()
        
        match = re.search(r"0\.\d+|1\.0+", score_str)
        if match:
            score = float(match.group(0))
        else:
            score = float(score_str)
            
        return min(max(score, 0.0), 1.0)
    except Exception as e:
        print(f"[ThreatAnalyzer] Error: {e}")
        return 0.2

# TRACK 2: Background Tasks
async def analyze_semantic_threat_background(callee_id: str, text: str):
    """Background task to analyze transcript for semantic threats."""
    if callee_id not in active_calls or active_calls[callee_id]["intercepted"]:
        return
        
    call_data = active_calls[callee_id]
    prob = await calculate_dynamic_threat_llm(text)
    call_data["semantic_threat_probability"] = prob
    
    if prob > 0.8:
        call_data["risk_score"] += 40
        print(f"[Track 2] High semantic threat detected ({prob}). +40 risk points.")
    else:
        added_points = int(prob * 20)
        call_data["risk_score"] += added_points
        if added_points > 0:
            print(f"[Track 2] Moderate semantic threat ({prob}). +{added_points} risk points.")
            
    await broadcast_state(callee_id)
    await check_interception_threshold(callee_id)

async def analyze_speaking_rate_background(callee_id: str, text: str, estimated_duration_s: float = 2.0):
    """Background task to calculate speaking rate."""
    if callee_id not in active_calls or active_calls[callee_id]["intercepted"]:
        return
        
    call_data = active_calls[callee_id]
    word_count = len(text.split())
    
    # Rough estimation if duration is very small
    rate = word_count / max(estimated_duration_s, 1.0)
    call_data["speaking_rate"] = rate
    
    if rate > 3.0:
        call_data["risk_score"] += 15
        print(f"[Track 2] Fast speaking rate detected ({rate:.1f} w/s). +15 risk points.")
        await broadcast_state(callee_id)
        await check_interception_threshold(callee_id)

@app.websocket("/ws/audio")
async def websocket_audio_endpoint(websocket: WebSocket):
    await websocket.accept()
    print("[Server] Flutter app connected.")
    
    callee_id = None
    try:
        raw = await asyncio.wait_for(websocket.receive_text(), timeout=10)
        msg = json.loads(raw)
        
        if msg.get("type") == "call_start":
            callee_id = msg.get("callee")
            active_calls[callee_id] = {
                "websocket": websocket,
                "evelyn": EvelynAgent(),
                "risk_score": 0,
                "intercepted": False,
                "liveness_score": 0,
                "synthetic_probability": 0.0,
                "temporal_variance": 0.0,
                "stress_score": 0,
                "semantic_threat_probability": 0.0,
                "speaking_rate": 0.0,
                "user_speech_queue": asyncio.Queue()
            }
            print(f"[Server] Call registered: {callee_id}")

        while True:
            data = await websocket.receive_text()
            try:
                msg_json = json.loads(data)
                if msg_json.get("event") == "USER_SPEECH" and callee_id in active_calls:
                    user_text = msg_json.get("text")
                    call_data = active_calls[callee_id]
                    
                    await call_data["user_speech_queue"].put(user_text)
                    
                    await websocket.send_text(json.dumps({
                        "event": "TRANSCRIPT_UPDATE",
                        "speaker": "USER",
                        "text": user_text,
                    }))
                    
                    # TRACK 2: Fire background analysis tasks asynchronously
                    estimated_duration = max(len(user_text.split()) * 0.4, 1.0)
                    asyncio.create_task(analyze_semantic_threat_background(callee_id, user_text))
                    asyncio.create_task(analyze_speaking_rate_background(callee_id, user_text, estimated_duration))
                    
            except json.JSONDecodeError:
                pass

    except asyncio.TimeoutError:
        print("[Server] Handshake timeout.")
    except WebSocketDisconnect:
        print(f"[Server] Flutter disconnected {callee_id}.")
    except Exception as e:
        print(f"[Server] Error: {e}")
    finally:
        if callee_id in active_calls:
            del active_calls[callee_id]

@app.get("/api/call_registered")
async def call_registered(callee: str):
    return {"registered": callee in active_calls, "callee": callee}

@app.get("/api/wait_for_user_speech")
async def wait_for_user_speech(callee: str):
    if callee not in active_calls:
        return {"text": "", "registered": False}
    
    call_data = active_calls[callee]
    try:
        text = await asyncio.wait_for(call_data["user_speech_queue"].get(), timeout=15.0)
        return {"text": text, "registered": True}
    except asyncio.TimeoutError:
        return {"text": "", "registered": True}

@app.post("/api/victim_speak")
async def victim_speak(msg: ScammerMessage):
    callee_id = msg.callee
    if callee_id not in active_calls:
        return {"error": "Call not found"}
        
    call_data = active_calls[callee_id]
    await call_data["user_speech_queue"].put(msg.text)
    
    await call_data["websocket"].send_text(json.dumps({
        "event": "TRANSCRIPT_UPDATE",
        "speaker": "USER",
        "text": msg.text,
    }))
    
    # TRACK 2: Async analysis
    estimated_duration = max(len(msg.text.split()) * 0.4, 1.0)
    asyncio.create_task(analyze_semantic_threat_background(callee_id, msg.text))
    asyncio.create_task(analyze_speaking_rate_background(callee_id, msg.text, estimated_duration))
    
    return {"status": "success"}

@app.post("/api/scammer_speak")
async def scammer_speak(msg: ScammerMessage):
    callee_id = msg.callee
    if callee_id not in active_calls:
        return {"error": "Call not found"}
        
    call_data = active_calls[callee_id]
    ws = call_data["websocket"]
    evelyn = call_data["evelyn"]
    
    # TRACK 1: Fast conversational updates
    await ws.send_text(json.dumps({
        "event": "SCAMMER_SPEECH",
        "text": msg.text,
    }))
    await ws.send_text(json.dumps({
        "event": "TRANSCRIPT_UPDATE",
        "speaker": "SCAMMER",
        "text": msg.text,
    }))
    
    if not call_data["intercepted"]:
        # TRACK 2: Fire background analysis tasks without blocking
        estimated_duration = max(len(msg.text.split()) * 0.4, 1.0)
        asyncio.create_task(analyze_semantic_threat_background(callee_id, msg.text))
        asyncio.create_task(analyze_speaking_rate_background(callee_id, msg.text, estimated_duration))
        
        return {"status": "listening"}
    else:
        # Already intercepted, agent takes over
        reply = await evelyn.generate_response(msg.text)
        speech_duration = max(3.0, min(7.0, len(msg.text) * 0.07))
        await asyncio.sleep(speech_duration)
        
        await ws.send_text(json.dumps({
            "event": "EVELYN_SPEECH",
            "text": reply,
        }))
        await ws.send_text(json.dumps({
            "event": "TRANSCRIPT_UPDATE",
            "speaker": "Evelyn",
            "text": reply,
        }))
        return {"status": "intercepted", "evelyn_reply": reply}

@app.post("/api/end_call")
async def end_call(msg: ScammerMessage):
    callee_id = msg.callee
    if callee_id in active_calls:
        call_data = active_calls[callee_id]
        report = call_data["evelyn"].generate_security_report()
        await call_data["websocket"].send_text(json.dumps({
            "event": "CALL_REPORT",
            **report,
        }))
        return {"status": "report_sent"}
    return {"error": "Call not found"}

if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000, reload=False)
