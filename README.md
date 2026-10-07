# AegisMesh

## Phase 1 Master Development Prototype

AegisMesh is a defensive mobile communication system designed to detect simulated AI-powered fraud calls and automatically activate an autonomous defensive counter-agent.

### Architecture

```
                 AEGISMESH

          📱 FLUTTER MOBILE APP
                 USER-1234
                    │
            Firebase Authentication
                    │
               Firestore
                    │
             WebRTC Signaling
                    │
              REAL WEBRTC
                    │
             🤖 SCAM-7829
             REAL AI AGENT
                    │
          ┌─────────┼─────────┐
         STT       LLM       TTS
          └─────────┼─────────┘
                    │
                  WebRTC

             SECURITY SIDECAR
                    │
              Python FastAPI
                    │
          ┌─────────┼─────────┐
        Audio    Context    Metadata
          └─────────┼─────────┘
              Threat Engine
                    │
                Score ≥ 0.85
                    │
             🚨 INTERCEPT
                    │
          USER MICROPHONE OFF
                    │
          🛡 PROTECTED OBSERVER
                    │
               🛡 EVELYN
               REAL AI AGENT
                    │
             ┌──────┼──────┐
            STT     LLM    TTS
                    │
                 WebRTC
                    │
               SCAM-7829
                    │
               AI ↔ AI
                    │
                Observer
                    │
             Security Report
```

### Technology Stack
- **Mobile Frontend**: Flutter, Dart, flutter_webrtc
- **Backend Infrastructure**: Firebase (Auth, Firestore, Cloud Messaging)
- **Security Sidecar / Detection Server**: Python, FastAPI, NumPy, librosa, WebSockets
- **AI Agents**: Deepgram (STT), Groq (LLM), TTS provider

### Setup Instructions
Please refer to individual directories for setup instructions:
1. `mobile-app/` - Flutter application setup
2. `detection-server/` - Python FastAPI security sidecar setup
3. `fraud-agent/` - Python simulated fraud agent setup

### Hackathon Milestones
1. Firebase
2. Flutter foundation
3. Aegis ID
4. Real WebRTC
5. Real AI Fraud Agent
6. Security Detection
7. Interception
8. Real Evelyn Counter-Agent
9. Takeover
10. Observer
11. Final End-to-End Demo
