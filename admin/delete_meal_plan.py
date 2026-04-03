"""
Kullanıcının meal plan'ını siler.
Kullanım: python delete_meal_plan.py <email>
"""
import sys
import firebase_admin
from firebase_admin import credentials, firestore

CRED_PATH = "ceptesef-32545-firebase-adminsdk-fbsvc-617481d20d.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(CRED_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()


def delete_plans(email: str):
    users = db.collection("users").where("email", "==", email).limit(1).get()
    if not users:
        print(f"Kullanıcı bulunamadı: {email}")
        return

    uid = users[0].id
    print(f"UID: {uid}")

    # meal_plans subcollection'daki tüm dokümanları listele
    plans = db.collection("users").document(uid).collection("meal_plans").get()
    if not plans:
        print("Meal plan bulunamadı.")
        return

    for plan in plans:
        data = plan.to_dict()
        gunler = data.get("gunler", [])
        gun_adlari = [g.get("gun_adi", "?") for g in gunler]
        print(f"  Plan: {plan.id} — {len(gunler)} gün: {', '.join(gun_adlari)}")

    confirm = input(f"\n{len(plans)} plan silinecek. Devam? (y/n): ")
    if confirm.lower() != "y":
        print("İptal edildi.")
        return

    for plan in plans:
        db.collection("users").document(uid).collection("meal_plans").document(plan.id).delete()
        print(f"  ✓ Silindi: {plan.id}")

    print("Tamamlandı.")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Kullanım: python delete_meal_plan.py <email>")
        sys.exit(1)
    delete_plans(sys.argv[1])
