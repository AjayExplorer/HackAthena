import os

base_dir = "f:/Aegismesh/mobile-app/lib"

folders = [
    "core/config",
    "core/constants",
    "core/theme",
    "core/utils",
    "models",
    "services",
    "state",
    "screens/splash",
    "screens/auth",
    "screens/home",
    "screens/calls",
    "screens/security",
    "screens/profile",
    "widgets"
]

files = [
    "models/user_model.dart",
    "models/call_session.dart",
    "models/threat_model.dart",
    "models/transcript_model.dart",
    "models/ioc_model.dart",
    "services/auth_service.dart",
    "services/firestore_service.dart",
    "services/signaling_service.dart",
    "services/webrtc_service.dart",
    "services/call_service.dart",
    "services/notification_service.dart",
    "services/security_service.dart",
    "state/call_state.dart",
    "widgets/call_controls.dart",
    "widgets/threat_meter.dart",
    "widgets/transcript_view.dart",
    "widgets/security_status.dart",
    "widgets/call_status.dart"
]

for folder in folders:
    os.makedirs(os.path.join(base_dir, folder), exist_ok=True)

for file in files:
    file_path = os.path.join(base_dir, file)
    with open(file_path, "w") as f:
        f.write("// Placeholder for " + file.split("/")[-1] + "\n")

print("Scaffolding complete.")
