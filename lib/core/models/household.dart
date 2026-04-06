import 'package:cloud_firestore/cloud_firestore.dart';

/// Aile planı (household) modeli
/// Birden fazla kullanıcının yemek planlarını paylaşmasını sağlar
class Household {
  /// Firestore doküman ID'si
  final String id;

  /// Aile adı (ör. "Yavuz Ailesi")
  final String name;

  /// Aile planını oluşturan ve veri sahibi olan kullanıcı UID'si
  final String ownerUid;

  /// Tüm üyelerin UID listesi (owner dahil)
  final List<String> members;

  /// 6 haneli davet kodu (A-Z, 0-9)
  final String inviteCode;

  /// Davet kodunun geçerlilik süresi
  final DateTime? inviteCodeExpiresAt;

  /// Oluşturulma tarihi
  final DateTime createdAt;

  const Household({
    required this.id,
    required this.name,
    required this.ownerUid,
    required this.members,
    required this.inviteCode,
    this.inviteCodeExpiresAt,
    required this.createdAt,
  });

  /// Firestore dokümanından Household oluşturur
  factory Household.fromMap(Map<String, dynamic> map, String id) {
    return Household(
      id: id,
      name: map['name'] as String? ?? '',
      ownerUid: map['ownerUid'] as String? ?? '',
      members: List<String>.from(map['members'] as List? ?? []),
      inviteCode: map['inviteCode'] as String? ?? '',
      inviteCodeExpiresAt:
          (map['inviteCodeExpiresAt'] as Timestamp?)?.toDate(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Firestore'a yazılacak Map formatı
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'ownerUid': ownerUid,
      'members': members,
      'inviteCode': inviteCode,
      'inviteCodeExpiresAt': inviteCodeExpiresAt != null
          ? Timestamp.fromDate(inviteCodeExpiresAt!)
          : null,
      'createdAt': FieldValue.serverTimestamp(),
    };
  }

  /// Belirli alanları güncellenmiş yeni bir kopya döner
  Household copyWith({
    String? id,
    String? name,
    String? ownerUid,
    List<String>? members,
    String? inviteCode,
    DateTime? inviteCodeExpiresAt,
    DateTime? createdAt,
  }) {
    return Household(
      id: id ?? this.id,
      name: name ?? this.name,
      ownerUid: ownerUid ?? this.ownerUid,
      members: members ?? this.members,
      inviteCode: inviteCode ?? this.inviteCode,
      inviteCodeExpiresAt: inviteCodeExpiresAt ?? this.inviteCodeExpiresAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
