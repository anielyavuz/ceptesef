"""
Cepte Şef — marketFiyatlar Ürün Kontrol Scripti
Firestore'daki marketFiyatlar koleksiyonundan belirli malzemeler için
mevcut ürünleri listeler.

Yapı:
  marketFiyatlar/{YYYYMMDD}  -> metadata (urunIndex, kategoriler, vb.)
  marketFiyatlar/{YYYYMMDD}/kategoriler/{kategoriAdi} -> { urunler: { malzemeKey: { products: [...] } } }

Kullanım:
  python3 check_products.py
"""

import firebase_admin
from firebase_admin import credentials, firestore
from datetime import datetime, timedelta
import json
import os

# Firebase Admin SDK başlat
SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
CRED_PATH = os.path.join(SCRIPT_DIR, "ceptesef-32545-firebase-adminsdk-fbsvc-617481d20d.json")
cred = credentials.Certificate(CRED_PATH)
firebase_admin.initialize_app(cred)
db = firestore.client()

# Aranan malzeme terimleri
SEARCH_TERMS = [
    "zeytinyağı", "zeytinyagi",
    "tavuk göğsü", "tavuk gogsu",
    "marul",
    "ıspanak", "ispanak",
]

# Geniş arama: urunIndex'te bu alt-string'leri içeren TÜM key'leri listele
BROAD_SEARCH = ["zeytin", "tavuk", "marul", "ispanak", "ıspanak"]


def main():
    date_str = "20260331"
    print(f"=== marketFiyatlar Ürün Kontrol ===")
    print(f"Tarih: {date_str}\n")

    doc_ref = db.collection("marketFiyatlar").document(date_str)
    doc = doc_ref.get()

    if not doc.exists:
        print(f"Doküman bulunamadı: {date_str}")
        # Dünü dene
        date_str = "20260330"
        print(f"Dün deneniyor: {date_str}")
        doc_ref = db.collection("marketFiyatlar").document(date_str)
        doc = doc_ref.get()

    if not doc.exists:
        print("Doküman bulunamadı! Çıkılıyor.")
        return

    metadata = doc.to_dict()
    urun_index = metadata.get("urunIndex", {})
    print(f"Doküman bulundu: {date_str}")
    print(f"urunIndex key sayısı: {len(urun_index)}\n")

    # ============================================================
    # BÖLÜM 1: Geniş arama — urunIndex key'lerini listele
    # ============================================================
    print("=" * 70)
    print("  BÖLÜM 1: urunIndex'te geniş arama (alt-string eşleşme)")
    print("=" * 70)

    for broad_term in BROAD_SEARCH:
        matching = [k for k in urun_index.keys() if broad_term.lower() in k.lower()]
        print(f"\n  \"{broad_term}\" içeren key'ler ({len(matching)} adet):")
        if not matching:
            print(f"    (hiç eşleşme yok)")
        for k in sorted(matching):
            print(f"    - \"{k}\"  ->  kategori: \"{urun_index[k]}\"")

    # ============================================================
    # BÖLÜM 2: Her arama terimi için detaylı ürün bilgisi
    # ============================================================
    print(f"\n\n{'=' * 70}")
    print("  BÖLÜM 2: Detaylı ürün bilgisi")
    print("=" * 70)

    kat_ref = doc_ref.collection("kategoriler")
    loaded_categories = {}

    for term in SEARCH_TERMS:
        # Hem exact hem partial match
        exact_keys = [k for k in urun_index.keys() if k.lower() == term.lower()]
        partial_keys = [k for k in urun_index.keys() if term.lower() in k.lower() and k.lower() != term.lower()]

        all_keys = exact_keys + partial_keys

        print(f"\n{'─' * 70}")
        print(f"  ARAMA: \"{term}\"")
        if exact_keys:
            print(f"  Tam eşleşme: {exact_keys}")
        if partial_keys:
            print(f"  Kısmi eşleşme: {partial_keys}")
        if not all_keys:
            print(f"  -> urunIndex'te HİÇ eşleşme yok!")
            continue
        print(f"{'─' * 70}")

        for key in all_keys:
            category = urun_index[key]

            # Kategori verisini yükle (cache)
            if category not in loaded_categories:
                cat_doc = kat_ref.document(category).get()
                if cat_doc.exists:
                    loaded_categories[category] = cat_doc.to_dict()
                else:
                    loaded_categories[category] = None

            cat_data = loaded_categories[category]
            if cat_data is None:
                print(f"\n  [{key}] -> kategori '{category}' bulunamadı!")
                continue

            urunler = cat_data.get("urunler", {})
            ingredient_data = urunler.get(key, {})
            products = ingredient_data.get("products", [])

            print(f"\n  [{key}] (kategori: {category}) — {len(products)} ürün")
            print(f"  {'-' * 60}")

            if not products:
                print(f"  Ürün bulunamadı!")
                continue

            for i, product in enumerate(products, 1):
                title = product.get("title", "N/A")
                brand = product.get("brand", "N/A")
                weight = product.get("weightLabel", "N/A")

                cheapest = product.get("cheapest", {})
                cheapest_price = cheapest.get("price", "N/A")
                cheapest_market = cheapest.get("displayName", cheapest.get("name", "N/A"))

                markets = product.get("markets", [])

                print(f"\n  {i}. {title}")
                print(f"     Marka: {brand}")
                print(f"     Gramaj: {weight}")
                print(f"     En Ucuz: {cheapest_price} TL @ {cheapest_market}")

                if len(markets) > 1:
                    print(f"     Tüm marketler:")
                    for m in markets:
                        m_name = m.get("displayName", m.get("name", "?"))
                        m_price = m.get("price", "?")
                        m_unit = m.get("unitPrice", "")
                        print(f"       - {m_name}: {m_price} TL  ({m_unit})")
                elif markets:
                    m = markets[0]
                    print(f"     Market: {m.get('displayName', m.get('name', '?'))} — {m.get('price', '?')} TL ({m.get('unitPrice', '')})")

        print()


if __name__ == "__main__":
    main()
