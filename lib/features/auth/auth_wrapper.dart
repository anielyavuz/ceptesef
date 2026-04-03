import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/services/auth_service.dart';
import '../../core/services/firestore_service.dart';
import '../../core/services/remote_logger_service.dart';
import '../home/screens/main_shell.dart';
import '../onboarding/screens/onboarding_screen.dart';
import 'screens/login_screen.dart';

/// Auth durumuna göre Login, Onboarding, MealPlan veya Home ekranına yönlendirir.
class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (context.mounted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
          }
        });

        if (snapshot.hasData) {
          return _UserGate(uid: snapshot.data!.uid);
        }
        return const LoginScreen();
      },
    );
  }
}

/// Onboarding kontrolü yaparak doğru ekrana yönlendirir.
/// 1. Onboarding tamamlanmamış → OnboardingScreen
/// 2. Onboarding tamam → HomeScreen (plan yoksa home'daki butonla oluşturulur)
class _UserGate extends StatefulWidget {
  final String uid;
  const _UserGate({required this.uid});

  @override
  State<_UserGate> createState() => _UserGateState();
}

enum _GateResult { onboarding, home }

class _UserGateState extends State<_UserGate> {
  late Future<_GateCheckData> _check;

  @override
  void initState() {
    super.initState();
    _check = _runChecks();
  }

  Future<_GateCheckData> _runChecks() async {
    final firestoreService = context.read<FirestoreService>();

    try {
      // Önce onboarding kontrolü
      final prefs = await firestoreService.getUserPreferences(widget.uid);
      if (prefs == null || !prefs.onboardingCompleted) {
        return _GateCheckData(_GateResult.onboarding);
      }

      return _GateCheckData(_GateResult.home);
    } catch (e) {
      RemoteLoggerService.error('user_gate_check_failed', error: e);
      // Hata durumunda home'a yönlendir
      return _GateCheckData(_GateResult.home);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_GateCheckData>(
      future: _check,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final data = snapshot.data ?? _GateCheckData(_GateResult.home);

        switch (data.result) {
          case _GateResult.onboarding:
            return const OnboardingScreen();
          case _GateResult.home:
            return const MainShell();
        }
      },
    );
  }
}

class _GateCheckData {
  final _GateResult result;
  const _GateCheckData(this.result);
}
