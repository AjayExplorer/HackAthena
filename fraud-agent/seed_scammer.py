import os
import firebase_admin
from firebase_admin import credentials, firestore

def seed_scammer_user():
    key_path = "serviceAccountKey.json"
    if not os.path.exists(key_path):
        print(f"Error: {key_path} not found.")
        return

    if not firebase_admin._apps:
        cred = credentials.Certificate(key_path)
        firebase_admin.initialize_app(cred)

    db = firestore.client()

    scammer_data = {
        "uid": "USER-1234",
        "email": "scammer.bot@aegismesh.internal",
        "displayName": "Security Verification Bot (Scammer)",
        "userCode": "USER-1234",
        "isFraudAgent": True,
        "status": "active"
    }

    # Seed in users collection with document ID USER-1234
    db.collection("users").document("USER-1234").set(scammer_data, merge=True)
    print("Successfully seeded USER-1234 (Scammer Bot) into Firestore database!")

if __name__ == "__main__":
    seed_scammer_user()
