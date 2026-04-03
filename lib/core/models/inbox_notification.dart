import 'package:cloud_firestore/cloud_firestore.dart';

/// Bildirim türleri
enum InboxNotificationType { pushNotification }

/// Firestore users/{uid}/notifications/{id} doküman modeli
class InboxNotification {
  final String id;
  final InboxNotificationType type;
  final String title;
  final String body;
  final DateTime createdAt;
  final bool read;

  const InboxNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.createdAt,
    required this.read,
  });

  factory InboxNotification.fromMap(Map<String, dynamic> map, String id) {
    return InboxNotification(
      id: id,
      type: InboxNotificationType.pushNotification,
      title: map['title'] as String? ?? '',
      body: map['body'] as String? ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      read: map['read'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type.name,
      'title': title,
      'body': body,
      'createdAt': FieldValue.serverTimestamp(),
      'read': read,
    };
  }
}
