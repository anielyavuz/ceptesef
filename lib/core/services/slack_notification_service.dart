import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import '../constants/firestore_paths.dart';

/// Slack webhook ile bildirim gönderen servis.
/// Webhook URL'i Firestore system/general dokümanından alınır.
class SlackNotificationService {
  static String? _webhookUrl;

  /// Firestore'dan webhook URL'ini çeker (lazy, bir kez)
  static Future<String?> _getWebhookUrl() async {
    if (_webhookUrl != null) return _webhookUrl;
    try {
      final doc = await FirebaseFirestore.instance
          .doc('${FirestorePaths.systemCollection}/${FirestorePaths.generalDoc}')
          .get();
      _webhookUrl = doc.data()?['slackInfoURL'] as String?;
    } catch (_) {}
    return _webhookUrl;
  }

  /// Slack'e mesaj gönderir (fire-and-forget)
  static Future<void> _send(String text) async {
    try {
      final url = await _getWebhookUrl();
      if (url == null || url.isEmpty) return;
      await http.post(
        Uri.parse(url),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'text': text}),
      );
    } catch (_) {
      // Fire-and-forget — hata uygulama akışını etkilemez
    }
  }

  /// Yeni kullanıcı kayıt bildirimi
  static Future<void> notifyNewUser({required String email}) async {
    await _send('🎉 Yeni kullanıcı kayıt oldu: $email');
  }

  /// Hesap silme bildirimi
  static Future<void> notifyAccountDeleted({required String email}) async {
    await _send('🗑️ Hesap silindi: $email');
  }
}
