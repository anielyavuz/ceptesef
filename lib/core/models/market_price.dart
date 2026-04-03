/// Tek bir marketteki ürün fiyat bilgisi.
class MarketOffer {
  final String marketName;
  final String displayName;
  final double price;
  final String? unitPrice;
  final String? depotName;

  const MarketOffer({
    required this.marketName,
    required this.displayName,
    required this.price,
    this.unitPrice,
    this.depotName,
  });

  factory MarketOffer.fromMap(Map<String, dynamic> map) {
    return MarketOffer(
      marketName: map['name'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      price: (map['price'] as num?)?.toDouble() ?? 0,
      unitPrice: map['unitPrice'] as String?,
      depotName: map['depotName'] as String?,
    );
  }
}

/// Tek bir ürün varyantı (marka + gramaj kombinasyonu).
class MarketProduct {
  final String productId;
  final String title;
  final String? brand;
  final String? imageUrl;
  final String? weightLabel;
  final MarketOffer cheapest;
  final List<MarketOffer> markets;

  const MarketProduct({
    required this.productId,
    required this.title,
    this.brand,
    this.imageUrl,
    this.weightLabel,
    required this.cheapest,
    required this.markets,
  });

  factory MarketProduct.fromMap(Map<String, dynamic> map) {
    return MarketProduct(
      productId: map['productId'] as String? ?? '',
      title: map['title'] as String? ?? '',
      brand: map['brand'] as String?,
      imageUrl: map['imageUrl'] as String?,
      weightLabel: map['weightLabel'] as String?,
      cheapest: MarketOffer.fromMap(map['cheapest'] as Map<String, dynamic>? ?? {}),
      markets: (map['markets'] as List<dynamic>?)
              ?.map((e) => MarketOffer.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}

/// Bir malzeme için bulunan fiyat sonucu.
class IngredientPriceResult {
  final String ingredientName;
  final String? category;
  final List<MarketProduct> products;

  /// true ise taze ürün bulunamadı, sadece işlenmiş alternatifler gösteriliyor
  final bool onlyProcessed;

  const IngredientPriceResult({
    required this.ingredientName,
    this.category,
    required this.products,
    this.onlyProcessed = false,
  });

  /// En ucuz ürünün fiyatı
  double? get cheapestPrice {
    if (products.isEmpty) return null;
    double min = double.infinity;
    for (final p in products) {
      if (p.cheapest.price < min) min = p.cheapest.price;
    }
    return min == double.infinity ? null : min;
  }

  /// En ucuz ürünün marketi
  String? get cheapestMarket {
    if (products.isEmpty) return null;
    double min = double.infinity;
    String? market;
    for (final p in products) {
      if (p.cheapest.price < min) {
        min = p.cheapest.price;
        market = p.cheapest.displayName;
      }
    }
    return market;
  }
}

/// Market bazlı gruplandırılmış alışveriş önerisi.
class MarketGroup {
  final String marketDisplayName;
  final String marketName;
  final List<MarketGroupItem> items;

  const MarketGroup({
    required this.marketDisplayName,
    required this.marketName,
    required this.items,
  });

  double get totalPrice => items.fold(0, (total, item) => total + item.price);
}

/// Bir marketten alınacak tek ürün.
class MarketGroupItem {
  final String ingredientName;
  final String productTitle;
  final double price;
  final String? unitPrice;
  final String? imageUrl;
  final String? weightLabel;

  const MarketGroupItem({
    required this.ingredientName,
    required this.productTitle,
    required this.price,
    this.unitPrice,
    this.imageUrl,
    this.weightLabel,
  });
}
