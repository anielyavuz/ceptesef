import 'package:cloud_firestore/cloud_firestore.dart';

/// Kaydedilmiş alışveriş listesi modeli.
class ShoppingList {
  final String id;
  final String title;
  final List<ShoppingItem> items;
  final List<String> selectedMeals; // "GünAdı - TarifAdı" formatında
  final DateTime createdAt;

  const ShoppingList({
    required this.id,
    required this.title,
    required this.items,
    this.selectedMeals = const [],
    required this.createdAt,
  });

  factory ShoppingList.fromMap(Map<String, dynamic> map, String docId) {
    return ShoppingList(
      id: docId,
      title: map['title'] as String? ?? '',
      items: (map['items'] as List<dynamic>?)
              ?.map((e) => ShoppingItem.fromMap(e as Map<String, dynamic>))
              .toList() ??
          [],
      selectedMeals: List<String>.from(map['selectedMeals'] ?? []),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'items': items.map((e) => e.toMap()).toList(),
      'selectedMeals': selectedMeals,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  int get checkedCount => items.where((i) => i.checked).length;
}

/// Alışveriş listesindeki tek bir öğe.
class ShoppingItem {
  final String name;
  final String quantity;
  bool checked;

  ShoppingItem({
    required this.name,
    required this.quantity,
    this.checked = false,
  });

  factory ShoppingItem.fromMap(Map<String, dynamic> map) {
    return ShoppingItem(
      name: map['name'] as String? ?? '',
      quantity: map['quantity'] as String? ?? '',
      checked: map['checked'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'quantity': quantity,
      'checked': checked,
    };
  }

  String get displayText {
    if (quantity.isEmpty) return name;
    return '$quantity $name';
  }
}
