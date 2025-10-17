import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _boot());
  }

  Future<void> _boot() async {
    try {
      final auth = FirebaseAuth.instance;
      final current = auth.currentUser;

      if (current == null) {
        _go('/login');
        return;
      }

      // Carga rol del usuario (ajusta colección/campo si usas otros nombres)
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(current.uid)
          .get();

      final data = doc.data() ?? {};
      final role = (data['role'] ?? data['rol'] ?? 'worker').toString();

      if (role == 'admin') {
        _go('/admin'); // <- tu shell responsive con sidebar/bottom bar
      } else {
        _go('/worker/home');
      }
    } catch (e) {
      // En caso de error, mejor ir a login
      _go('/login');
    }
  }

  void _go(String route) {
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(route, (r) => false);
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
