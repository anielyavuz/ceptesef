"""
Kullanıcı profilini ve meal plan durumunu incele.
Kullanım: python inspect_user.py <email>
"""
import sys
import json
from datetime import datetime
import firebase_admin
from firebase_admin import credentials, firestore

CRED_PATH = "ceptesef-32545-firebase-adminsdk-fbsvc-def17fcf88.json"

if not firebase_admin._apps:
    cred = credentials.Certificate(CRED_PATH)
    firebase_admin.initialize_app(cred)

db = firestore.client()


def inspect(email: str):
    # 1. Kullanıcı dokümanı bul
    users = db.collection("users").where("email", "==", email).limit(1).get()
    if not users:
        print(f"Kullanıcı bulunamadı: {email}")
        return

    user_doc = users[0]
    uid = user_doc.id
    user_data = user_doc.to_dict()
    print(f"\n{'='*60}")
    print(f"KULLANICI: {user_data.get('displayName', 'N/A')} ({email})")
    print(f"UID: {uid}")
    print(f"{'='*60}")

    # 2. Preferences
    prefs_ref = db.collection("users").document(uid).collection("preferences").document("main")
    prefs_doc = prefs_ref.get()
    if prefs_doc.exists:
        prefs = prefs_doc.to_dict()
        print(f"\nTERCİHLER:")
        print(f"  Öğün planı: {prefs.get('ogunPlani', 'N/A')}")
        print(f"  Kişi sayısı: {prefs.get('kisiSayisi', 'N/A')}")
        print(f"  Mutfaklar: {prefs.get('mutfaklar', [])}")
        print(f"  Alerjiler: {prefs.get('alerjenler', [])}")
        print(f"  Diyetler: {prefs.get('diyetler', [])}")
    else:
        print(f"\nTERCİHLER: Tercih dokümanı yok!")

    # 3. Meal Plans
    plans_ref = db.collection("users").document(uid).collection("meal_plans")
    plans = plans_ref.order_by("createdAt", direction=firestore.Query.DESCENDING).limit(5).get()

    print(f"\nYEMEK PLANLARI ({len(plans)} adet, son 5):")

    now = datetime.now()
    today = datetime(now.year, now.month, now.day)

    # Bu haftanın pazartesisi
    days_from_monday = (today.weekday()) % 7  # Python: Monday=0
    this_monday = today.replace(hour=0, minute=0, second=0)
    from datetime import timedelta
    this_monday = today - timedelta(days=days_from_monday)
    monday_str = this_monday.strftime("%Y-%m-%d")

    print(f"  Bu haftanın Pazartesi'si: {monday_str}")
    print()

    for plan_doc in plans:
        plan = plan_doc.to_dict()
        doc_id = plan_doc.id
        hafta_baslangic = plan.get("haftaBaslangic", plan.get("hafta_baslangic", "N/A"))
        ogun_plani = plan.get("ogunPlani", plan.get("ogun_plani", "N/A"))
        created_at = plan.get("createdAt")
        gunler = plan.get("gunler", [])

        # Expire check
        try:
            start = datetime.strptime(hafta_baslangic, "%Y-%m-%d")
            end = start + timedelta(days=6)
            is_expired = today > end
            end_str = end.strftime("%Y-%m-%d")
        except:
            is_expired = "?"
            end_str = "?"

        print(f"  📅 Doc ID: {doc_id}")
        print(f"     haftaBaslangic: {hafta_baslangic}")
        print(f"     Bitiş (Pazar): {end_str}")
        print(f"     Expired: {is_expired}")
        print(f"     Öğün planı: {ogun_plani}")
        print(f"     Gün sayısı: {len(gunler)}")
        if created_at:
            print(f"     Oluşturulma: {created_at}")

        # Her günün öğün sayısı
        for i, gun in enumerate(gunler):
            gun_str = gun.get("gun", f"gun_{i}")
            gun_adi = gun.get("gun_adi", "?")
            ogunler = gun.get("ogunler", {})
            meal_names = [r.get("yemek_adi", "?") for r in ogunler.values() if isinstance(r, dict)]
            print(f"       {gun_adi} ({gun_str}): {len(ogunler)} öğün — {', '.join(meal_names[:3])}")
        print()

    # 4. Exact match test
    exact_doc = plans_ref.document(monday_str).get()
    print(f"EXACT MATCH ({monday_str}): {'VAR' if exact_doc.exists else 'YOK'}")

    # 5. Saved recipes count
    saved = db.collection("users").document(uid).collection("saved_recipes").get()
    print(f"\nKAYDEDİLEN TARİFLER: {len(saved)} adet")

    # 6. Shopping lists
    shopping = db.collection("users").document(uid).collection("shopping_lists").get()
    print(f"ALIŞVERİŞ LİSTELERİ: {len(shopping)} adet")


if __name__ == "__main__":
    email = sys.argv[1] if len(sys.argv) > 1 else "mtmt@gmail.com"
    inspect(email)
