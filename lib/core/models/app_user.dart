import 'package:cloud_firestore/cloud_firestore.dart';

/// Firestore'daki kullanıcı doküman modeli
class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final DateTime createdAt;

  /// Kullanıcının bağlı olduğu aile planı (household) ID'si
  final String? householdId;

  const AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.createdAt,
    this.householdId,
  });

  /// Firestore dokümanından AppUser oluşturur
  factory AppUser.fromMap(Map<String, dynamic> map, String uid) {
    return AppUser(
      uid: uid,
      email: map['email'] as String? ?? '',
      displayName: map['displayName'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      householdId: map['householdId'] as String?,
    );
  }

  /// Firestore'a yazılacak Map formatı
  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'createdAt': FieldValue.serverTimestamp(),
      if (householdId != null) 'householdId': householdId,
    };
  }
}
