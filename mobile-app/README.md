# mobile_app

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
# 🛡️ AegisMesh

### Phase 1 — Autonomous AI Fraud Defense & Communication Security

> **AegisMesh** is a defensive mobile communication system designed to detect simulated AI-powered fraud calls and automatically activate an autonomous defensive counter-agent.

---

## 🚨 Problem

AI-powered voice scams are becoming increasingly convincing.

Attackers can use:

- AI-generated voices
- Social engineering
- Fake bank representatives
- Urgency and fear tactics
- Automated conversations
- Real-time voice agents

Traditional fraud detection systems often depend on the user recognizing the scam.

**AegisMesh takes a different approach:**

> Instead of relying entirely on the victim to identify the scam, AegisMesh continuously analyzes the communication and can automatically activate a defensive AI agent when a high-risk interaction is detected.

---

# 🎯 Objective

AegisMesh aims to create an intelligent communication security layer capable of:

1. Establishing secure communication.
2. Monitoring call audio and metadata.
3. Detecting suspicious conversational patterns.
4. Calculating a real-time threat score.
5. Automatically intercepting high-risk calls.
6. Muting the legitimate user's microphone.
7. Activating an autonomous defensive AI agent.
8. Keeping the suspicious caller engaged.
9. Generating a security report after the interaction.

---

# 🏗️ Architecture

```text
                         🛡️ AEGISMESH
                              │
                              ▼
                   📱 FLUTTER MOBILE APP
                              │
                         USER-1234
                              │
              ┌───────────────┼───────────────┐
              │               │               │
              ▼               ▼               ▼
         Firebase Auth     Firestore      WebRTC Signaling
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                       🌐 REAL WEBRTC
                              │
                              ▼
                    🤖 SCAM-7829
                    REAL AI AGENT
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
                   STT       LLM       TTS
                    │         │         │
                    └─────────┼─────────┘
                              │
                              ▼
                    🔐 SECURITY SIDECAR
                              │
                       Python FastAPI
                              │
              ┌───────────────┼───────────────┐
              ▼               ▼               ▼
            Audio          Context         Metadata
              │               │               │
              └───────────────┼───────────────┘
                              │
                              ▼
                       🧠 THREAT ENGINE
                              │
                       Threat Score
                              │
                       Score ≥ 0.85
                              │
                              ▼
                       🚨 INTERCEPT
                              │
                    USER MICROPHONE OFF
                              │
                              ▼
                    🛡️ PROTECTED OBSERVER
                              │
                              ▼
                    🤖 EVELYN COUNTER-AGENT
                              │
                    ┌─────────┼─────────┐
                    ▼         ▼         ▼
                   STT       LLM       TTS
                              │
                              ▼
                       🌐 WebRTC
                              │
                              ▼
                         SCAM-7829
                              │
                       AI ↔ AI SESSION
                              │
                              ▼
                         👁️ OBSERVER
                              │
                              ▼
                     📊 SECURITY REPORT
```

---

# 🔄 How AegisMesh Works

### 1. 📱 User Starts Communication

The user communicates through the AegisMesh Flutter application.

Firebase provides authentication and supporting backend services.

---

### 2. 🌐 WebRTC Communication

The communication session is established using WebRTC.

```text
User
  │
  ▼
Flutter App
  │
  ▼
WebRTC
  │
  ▼
AI Fraud Agent
```

---

### 3. 🤖 Simulated AI Fraud Agent

For the Phase 1 prototype, AegisMesh uses a simulated AI scammer.

The fraud agent can perform realistic conversational interactions using:

- Speech-to-Text
- Large Language Model
- Text-to-Speech

```text
Audio
  ↓
STT
  ↓
LLM
  ↓
TTS
  ↓
Audio
```

---

### 4. 🔐 Security Sidecar

The security sidecar runs independently from the main communication application.

It receives relevant:

- Audio information
- Conversation context
- Call metadata

The sidecar is implemented using **Python + FastAPI**.

---

### 5. 🧠 Threat Detection

The Threat Engine analyzes the communication and calculates a risk score.

Example:

```text
Threat Score = 0.32
        ↓
Normal

Threat Score = 0.67
        ↓
Suspicious

Threat Score = 0.91
        ↓
🚨 HIGH RISK
        ↓
INTERCEPT
```

The Phase 1 prototype uses:

```text
THRESHOLD = 0.85
```

When the threat score reaches or exceeds the threshold, AegisMesh activates the defensive response.

---

# 🚨 Interception

When a high-risk interaction is detected:

```text
Threat Score ≥ 0.85
          │
          ▼
     🚨 INTERCEPT
          │
          ▼
 User Microphone OFF
          │
          ▼
 Protected Observer
          │
          ▼
 Evelyn Counter-Agent
```

The legitimate user is removed from the active conversation while the defensive agent handles the simulated attacker.

---

# 🛡️ Evelyn — Defensive Counter-Agent

**Evelyn** is the autonomous defensive AI agent in the AegisMesh architecture.

Instead of allowing the scammer to continue interacting with the victim, Evelyn takes over the conversation in the simulated environment.

### Evelyn Pipeline

```text
Incoming Audio
      │
      ▼
     STT
      │
      ▼
 Defensive LLM
      │
      ▼
     TTS
      │
      ▼
Outgoing Audio
      │
      ▼
   WebRTC
      │
      ▼
 Scam Agent
```

This creates an experimental:

```text
        AI
         ↕
        AI
```

interaction between the simulated fraud agent and the defensive counter-agent.

---

# 👁️ Protected Observer

During the defensive interaction, the original user is placed into a protected observer state.

The observer can receive:

- Current threat status
- Interception status
- Call activity
- AI interaction status
- Final security report

The objective is to keep the user informed without requiring them to directly engage with the suspected scammer.

---

# 📊 Security Report

After the interaction, AegisMesh generates a security report containing information such as:

```text
AegisMesh Security Report
──────────────────────────

Call ID:
SCAM-7829

Threat Level:
HIGH

Threat Score:
0.91

Detection:
AI-powered fraud interaction

Interception:
ACTIVATED

User Protection:
MICROPHONE MUTED

Defensive Agent:
EVELYN

Session:
AI ↔ AI

Status:
PROTECTED
```

---

# 🧰 Technology Stack

## 📱 Mobile Application

- Flutter
- Dart
- flutter_webrtc

## 🔥 Backend Infrastructure

- Firebase Authentication
- Firebase Firestore
- Firebase Cloud Messaging
- WebRTC Signaling

## 🔐 Security Sidecar

- Python
- FastAPI
- NumPy
- librosa
- WebSockets

## 🤖 AI Agents

- Deepgram — Speech-to-Text
- Groq — LLM
- TTS Provider — Text-to-Speech

---

# 📁 Project Structure

```text
AegisMesh/
│
├── mobile-app/
│   ├── lib/
│   ├── android/
│   ├── ios/
│   ├── web/
│   ├── pubspec.yaml
│   └── README.md
│
├── detection-server/
│   ├── app/
│   ├── models/
│   ├── services/
│   ├── main.py
│   ├── requirements.txt
│   └── README.md
│
├── fraud-agent/
│   ├── agent/
│   ├── services/
│   ├── main.py
│   ├── requirements.txt
│   └── README.md
│
├── .gitignore
└── README.md
```

---

# ⚙️ Setup

AegisMesh consists of three primary components.

## 1. Mobile Application

Navigate to:

```bash
cd mobile-app
```

Install dependencies:

```bash
flutter pub get
```

Run the application:

```bash
flutter run
```

For additional configuration, see:

```text
mobile-app/README.md
```

---

## 2. Detection Server

Navigate to:

```bash
cd detection-server
```

Create a virtual environment:

```bash
python -m venv venv
```

Activate it on Windows:

```powershell
venv\Scripts\activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Start the FastAPI server:

```bash
uvicorn main:app --reload
```

For server-specific configuration, see:

```text
detection-server/README.md
```

---

## 3. Fraud Agent

Navigate to:

```bash
cd fraud-agent
```

Create a virtual environment:

```bash
python -m venv venv
```

Activate it:

```powershell
venv\Scripts\activate
```

Install dependencies:

```bash
pip install -r requirements.txt
```

Start the fraud agent:

```bash
python main.py
```

For agent-specific configuration, see:

```text
fraud-agent/README.md
```

---

# 🔑 Environment Variables

**Never commit API keys or credentials to GitHub.**

Create `.env` files locally.

Example:

```env
DEEPGRAM_API_KEY=your_api_key
GROQ_API_KEY=your_api_key
TTS_API_KEY=your_api_key

FIREBASE_PROJECT_ID=your_project_id
```

Add environment files to `.gitignore`:

```gitignore
.env
.env.local
.env.*.local
```

If a secret has already been committed to Git, remove it from tracking and **rotate the exposed credential**.

---

# 🗺️ Development Roadmap

AegisMesh Phase 1 development is organized into the following milestones:

| # | Milestone | Status |
|---|---|---|
| 1 | 🔥 Firebase Integration | 🚧 |
| 2 | 📱 Flutter Foundation | 🚧 |
| 3 | 🆔 Aegis ID | 🚧 |
| 4 | 🌐 Real WebRTC | 🚧 |
| 5 | 🤖 Real AI Fraud Agent | 🚧 |
| 6 | 🧠 Security Detection | 🚧 |
| 7 | 🚨 Interception | 🚧 |
| 8 | 🛡️ Evelyn Counter-Agent | 🚧 |
| 9 | 🔄 Takeover | 🚧 |
| 10 | 👁️ Protected Observer | 🚧 |
| 11 | 📊 End-to-End Demo | 🚧 |

> Replace the status indicators with `✅ Completed`, `🚧 In Progress`, or `⏳ Planned` as development progresses.

---

# 🧪 Phase 1 Demo Flow

The intended hackathon demonstration follows this sequence:

```text
1. User opens AegisMesh
             ↓
2. User starts a call
             ↓
3. Simulated AI scammer joins
             ↓
4. Conversation begins
             ↓
5. Security Sidecar analyzes interaction
             ↓
6. Threat Engine calculates risk
             ↓
7. Risk score crosses 0.85
             ↓
8. 🚨 AegisMesh activates interception
             ↓
9. User microphone is muted
             ↓
10. 🛡️ Evelyn becomes active
             ↓
11. Evelyn communicates with scam agent
             ↓
12. 👁️ User observes protected session
             ↓
13. 📊 Security report generated
```

---

# 🎥 Hackathon Demonstration

### Scenario

A simulated fraudster contacts the user and attempts to perform a typical social-engineering attack.

The conversation contains suspicious indicators.

AegisMesh detects the interaction and determines:

```text
Threat Score: 0.91
Risk Level: HIGH
```

The system automatically transitions from:

```text
USER ↔ SCAMMER
```

to:

```text
USER
 │
 │ Protected
 ▼
OBSERVER

EVELYN ↔ SCAMMER
```

The user remains protected while the defensive agent handles the simulated interaction.

---

# 🔐 Security & Ethics

AegisMesh is a **defensive research prototype**.

The Phase 1 fraud agent is intended only for controlled simulation and security testing.

The project is designed to:

- Study AI-powered social engineering.
- Demonstrate autonomous fraud detection.
- Explore defensive AI agents.
- Protect users from simulated malicious interactions.
- Generate security insights from communication patterns.

The system should only be tested with authorized participants and controlled environments.

---

# ⚠️ Phase 1 Prototype Limitations

This is an experimental hackathon prototype.

Potential limitations include:

- Detection accuracy may vary.
- Threat scoring is prototype-level.
- WebRTC infrastructure may require additional production hardening.
- AI transcription may contain errors.
- AI-generated responses may occasionally be incorrect.
- Real-world carrier/PSTN integration is outside the initial scope.
- Production-grade privacy, security, compliance, and latency testing are still required.

---

# 🚀 Future Scope

Future versions of AegisMesh could explore:

- Real-time voice fraud detection
- Advanced behavioral analysis
- Speaker verification
- Deepfake voice detection
- Multilingual scam detection
- Continuous risk scoring
- On-device threat detection
- Privacy-preserving audio processing
- Explainable threat scoring
- Automated incident reporting
- Enterprise fraud protection
- Integration with telecom infrastructure

---

# 🏆 Hackathon

### HackAthena

**Project:** AegisMesh  
**Phase:** Phase 1 — Master Development Prototype

> **Detect. Intercept. Protect.**

---

# 👥 Team

**AegisMesh Development Team**

Building an autonomous defensive layer for the next generation of AI-powered communication threats.

---

## 📜 License

This project is intended for research, education, and controlled security demonstration purposes.

Add an appropriate open-source license before publicly distributing the project.