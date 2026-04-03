"""
Cepte Şef — Test Bildirim Gönderici
Firebase Admin SDK ile data-only FCM mesajı gönderir.

Kullanım:
  python test_notification.py <kullanici_email>

Gereksinimler:
  pip install firebase-admin
"""

import sys
import firebase_admin
from firebase_admin import credentials, firestore, messaging

# Firebase Admin SDK başlat
CRED_PATH = "ceptesef-32545-firebase-adminsdk-fbsvc-def17fcf88.json"
cred = credentials.Certificate(CRED_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()


def get_fcm_token(email: str) -> str | None:
    """Kullanıcının FCM token'ını Firestore'dan getirir."""
    users = db.collection("users").where("email", "==", email).limit(1).get()
    for user in users:
        data = user.to_dict()
        token = data.get("fcmToken")
        if token:
            print(f"Kullanıcı bulundu: {data.get('displayName', 'N/A')} ({email})")
            return token
        else:
            print(f"Kullanıcı bulundu ama FCM token yok: {email}")
            return None
    print(f"Kullanıcı bulunamadı: {email}")
    return None


def send_notification(token: str, title: str, body: str) -> str:
    """Data-only FCM mesajı gönderir (Android foreground'da çalışır)."""
    message = messaging.Message(
        # DATA-ONLY: notification payload KULLANMA
        data={
            "title": title,
            "body": body,
            "type": "push",
        },
        android=messaging.AndroidConfig(priority="high"),
        # iOS: APNS alert gerekli (data-only mesajlar iOS'ta gösterilmez)
        apns=messaging.APNSConfig(
            payload=messaging.APNSPayload(
                aps=messaging.Aps(
                    content_available=True,
                    sound="default",
                    badge=1,
                    alert=messaging.ApsAlert(
                        title=title,
                        body=body,
                    ),
                ),
            ),
        ),
        token=token,
    )
    return messaging.send(message)


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Kullanım: python test_notification.py <email>")
        print("Örnek:    python test_notification.py test@mail.com")
        sys.exit(1)

    email = sys.argv[1]
    token = get_fcm_token(email)

    if not token:
        sys.exit(1)

    title = "Cepte Şef 🍳"
    body = "Bugünkü yemek planınız hazır! Mutfağa buyurun."

    try:
        result = send_notification(token, title, body)
        print(f"Bildirim gönderildi! Message ID: {result}")
    except Exception as e:
        print(f"Hata: {e}")
