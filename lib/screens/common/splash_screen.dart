import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../../routes/app_routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  bool _navigated = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    try {
      // ✅ Espera a que FirebaseAuth restaure sesión (clave en web)
      final user = await FirebaseAuth.instance.authStateChanges().first;

      if (user == null) {
        _go(Routes.welcome); // o Routes.loginZip si prefieres
        return;
      }

      final email = (user.email ?? '').trim();
      // ✅ Query rápido (collectionGroup), con timeout para evitar “splash infinito”
      final empresaAdminId = await AuthService.instance
          .getEmpresaIdForAdminEmail(email)
          .timeout(const Duration(seconds: 6), onTimeout: () => null);

      if (empresaAdminId != null) {
        _go(Routes.adminShell);
      } else {
        _go(Routes.workerHome);
      }
    } catch (_) {
      _go(Routes.welcome);
    }
  }

  void _go(String route) {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
