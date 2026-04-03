import 'dart:convert';
import 'package:http/http.dart' as http;

/// Grafana/Loki tabanlı remote logging servisi
/// Fire-and-forget: Sunucu kapalıysa uygulama etkilenmez
/// Tüm loglar {app="ceptesef"} label'ıyla Loki'ye gönderilir
class RemoteLoggerService {
  static const String _lokiEndpoint = 'https://logs.heymenu.org/loki/api/v1/push';
  static const String _appName = 'ceptesef';
  static const bool _isEnabled = true;

  // Context — login sonrası set edilir
  static String? _userId;
  static String? _userEmail;
  static String? _currentScreen;

  /// Kullanıcı login olduğunda çağır
  static void setUserContext({
    required String userId,
    String? email,
  }) {
    _userId = userId;
    _userEmail = email;
  }

  /// Ekran değiştiğinde çağır
  static void setScreen(String screenName) {
    _currentScreen = screenName;
  }

  /// Logout olduğunda çağır
  static void clearContext() {
    _userId = null;
    _userEmail = null;
    _currentScreen = null;
  }

  // =============================================
  // ANA LOG METODU
  // =============================================
  static Future<void> log({
    required String level,
    required String message,
    String? screen,
    Map<String, dynamic>? extra,
  }) async {
    if (!_isEnabled || _lokiEndpoint.isEmpty) return;

    final timestamp = DateTime.now().microsecondsSinceEpoch * 1000;
    final effectiveScreen = screen ?? _currentScreen ?? 'unknown';

    final streamLabels = {
      'app': _appName,
      'level': level,
      'platform': 'flutter',
      'user_id': _userId ?? 'unknown',
      'user_email': _userEmail ?? 'unknown',
      'screen': effectiveScreen,
    };

    final logData = {
      'msg': message,
      if (_userId != null) 'user_id': _userId,
      if (_userEmail != null) 'user_email': _userEmail,
      'screen': effectiveScreen,
      ...?extra,
    };
    logData.removeWhere((key, value) => value == null);

    final payload = {
      'streams': [
        {
          'stream': streamLabels,
          'values': [
            [timestamp.toString(), jsonEncode(logData)]
          ],
        }
      ]
    };

    try {
      await http.post(
        Uri.parse(_lokiEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
    } catch (_) {
      // Fire-and-forget: Sunucu kapalıysa sessizce geç
    }
  }

  // =============================================
  // KISAYOL METODLARI
  // =============================================

  /// Bilgi logu
  static void info(String msg, {String? screen, Map<String, dynamic>? extra}) =>
      log(level: 'info', message: msg, screen: screen, extra: extra);

  /// Hata logu
  static void error(String msg,
          {String? screen, dynamic error, StackTrace? stackTrace}) =>
      log(
        level: 'error',
        message: msg,
        screen: screen,
        extra: {
          if (error != null) 'error': error.toString(),
          if (stackTrace != null) 'stack_trace': stackTrace.toString(),
        },
      );

  /// Uyarı logu
  static void warning(String msg, {String? screen}) =>
      log(level: 'warning', message: msg, screen: screen);

  /// Kullanıcı aksiyonu
  static void userAction(String action,
          {String? screen, Map<String, dynamic>? details}) =>
      log(
        level: 'info',
        message: action,
        screen: screen,
        extra: {'type': 'user_action', ...?details},
      );

  /// Auth olayları
  static void authEvent(String event, {String? email, Map<String, dynamic>? details}) =>
      log(
        level: 'info',
        message: event,
        screen: 'auth',
        extra: {
          'type': 'auth',
          if (email != null) 'email': email,
          ...?details,
        },
      );

  /// Bildirim olayları
  static void notificationEvent(String event,
          {String? screen, String? notificationId}) =>
      log(
        level: 'info',
        message: event,
        screen: screen,
        extra: {
          'type': 'notification',
          if (notificationId != null) 'notification_id': notificationId,
        },
      );
}
