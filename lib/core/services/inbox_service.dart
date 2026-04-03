import 'package:cloud_firestore/cloud_firestore.dart';
import '../constants/firestore_paths.dart';
import '../models/inbox_notification.dart';

/// Bildirim inbox'ı yöneten servis
/// users/{uid}/notifications alt koleksiyonunu kullanır
class InboxService {
  final FirebaseFirestore _firestore;

  InboxService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Kullanıcının bildirim koleksiyonu referansı
  CollectionReference<Map<String, dynamic>> _notificationsRef(String uid) {
    return _firestore
        .collection(FirestorePaths.usersCollection)
        .doc(uid)
        .collection(FirestorePaths.notificationsSubcollection);
  }

  /// Push bildirimi Firestore'a kaydeder
  Future<void> savePushNotification({
    required String uid,
    required String title,
    required String body,
  }) async {
    final notification = InboxNotification(
      id: '',
      type: InboxNotificationType.pushNotification,
      title: title,
      body: body,
      createdAt: DateTime.now(),
      read: false,
    );
    await _notificationsRef(uid).add(notification.toMap());
  }

  /// Tüm bildirimleri getirir (yeniden eskiye)
  Future<List<InboxNotification>> getNotifications(String uid) async {
    final snapshot = await _notificationsRef(uid)
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => InboxNotification.fromMap(doc.data(), doc.id))
        .toList();
  }

  /// Okunmamış bildirim sayısını döndürür
  Future<int> getUnreadCount(String uid) async {
    final snapshot = await _notificationsRef(uid)
        .where('read', isEqualTo: false)
        .count()
        .get();

    return snapshot.count ?? 0;
  }

  /// Bildirimi okundu olarak işaretler
  Future<void> markAsRead(String uid, String notificationId) async {
    await _notificationsRef(uid).doc(notificationId).update({'read': true});
  }

  /// Bildirimi siler
  Future<void> deleteNotification(String uid, String notificationId) async {
    await _notificationsRef(uid).doc(notificationId).delete();
  }
}
