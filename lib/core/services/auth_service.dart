import 'package:firebase_auth/firebase_auth.dart';
import 'remote_logger_service.dart';
import 'slack_notification_service.dart';


/// Firebase Authentication servisi
/// Email/şifre ile giriş, kayıt ve şifre sıfırlama işlemlerini yönetir
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Mevcut kullanıcıyı döndürür (null ise giriş yapılmamış)
  User? get currentUser => _auth.currentUser;

  /// Auth durumu değişikliklerini dinler
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Email ve şifre ile giriş yapar
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      RemoteLoggerService.authEvent('login_success', email: email);
      RemoteLoggerService.setUserContext(
        userId: result.user?.uid ?? '',
        email: email,
      );
      return result;
    } catch (e) {
      RemoteLoggerService.error('login_failed', screen: 'auth',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  /// Email ve şifre ile yeni hesap oluşturur
  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      final result = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      RemoteLoggerService.authEvent('register_success', email: email);
      RemoteLoggerService.setUserContext(
        userId: result.user?.uid ?? '',
        email: email,
      );
      SlackNotificationService.notifyNewUser(email: email);
      return result;
    } catch (e) {
      RemoteLoggerService.error('register_failed', screen: 'auth',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  /// Şifre sıfırlama bağlantısı gönderir
  Future<void> sendPasswordResetEmail({required String email}) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
      RemoteLoggerService.authEvent('password_reset_sent', email: email);
    } catch (e) {
      RemoteLoggerService.error('password_reset_failed', screen: 'auth',
          error: e, stackTrace: StackTrace.current);
      rethrow;
    }
  }

  /// Kullanıcının görünen adını günceller
  Future<void> updateDisplayName(String displayName) async {
    await _auth.currentUser?.updateDisplayName(displayName);
    await _auth.currentUser?.reload();
  }

  /// Hesabı kalıcı olarak siler (Firebase Auth)
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) return;
    final email = user.email ?? 'unknown';
    RemoteLoggerService.authEvent('account_deleted');
    SlackNotificationService.notifyAccountDeleted(email: email);
    RemoteLoggerService.clearContext();
    await user.delete();
  }

  /// Çıkış yapar
  Future<void> signOut() async {
    RemoteLoggerService.authEvent('logout');
    RemoteLoggerService.clearContext();
    await _auth.signOut();
  }
}
