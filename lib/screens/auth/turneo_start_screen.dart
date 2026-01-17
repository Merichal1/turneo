import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../routes/app_routes.dart';
import '../../core/services/auth_service.dart';

class TurneoStartScreen extends StatelessWidget {
  const TurneoStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    final isWide = w >= 1000;
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2F6BFF), Color(0xFF8B3DFF)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: isWide
                    ? Row(
                        children: [
                          const Expanded(flex: 6, child: _LeftMarketing()),
                          const SizedBox(width: 28),
                          Expanded(
                            flex: 5,
                            child: _RightCard(showApple: showApple),
                          ),
                        ],
                      )
                    : SingleChildScrollView(
                        child: Column(
                          children: [
                            const _LeftMarketing(compact: true),
                            const SizedBox(height: 18),
                            _RightCard(showApple: showApple),
                          ],
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _LeftMarketing extends StatelessWidget {
  final bool compact;
  const _LeftMarketing({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 34.0 : 52.0;

    return Align(
      alignment: Alignment.centerLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 650),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                _Logo(),
                SizedBox(width: 12),
                Text(
                  'Turneo',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              'Gestión Inteligente de\nPersonal Hostelero',
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w900,
                height: 1.05,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'La plataforma completa para administrar tu equipo, eventos y horarios en el sector de la hostelería de manera eficiente y profesional.',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.w600,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 22),
            const _Feature(
              icon: Icons.people_outline,
              title: 'Gestión de Personal',
              subtitle: 'Administra tu equipo de forma eficiente',
            ),
            const SizedBox(height: 14),
            const _Feature(
              icon: Icons.event_outlined,
              title: 'Eventos y Horarios',
              subtitle: 'Organiza eventos y asignaciones fácilmente',
            ),
            const SizedBox(height: 14),
            const _Feature(
              icon: Icons.insights_outlined,
              title: 'Seguimiento en Tiempo Real',
              subtitle: 'Monitorea el rendimiento y la disponibilidad',
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
            ),
          ],
        ),
      ),
    );
  }
}

class _RightCard extends StatelessWidget {
  final bool showApple;
  const _RightCard({required this.showApple});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          padding: const EdgeInsets.all(26),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(22),
            boxShadow: const [
              BoxShadow(
                color: Color(0x1A000000),
                blurRadius: 30,
                offset: Offset(0, 14),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Bienvenido',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              const Text(
                'Comienza a optimizar la gestión de tu equipo hoy mismo',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 18),

              // Crear cuenta
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2563EB),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, Routes.registerZip),
                  child: const Text('Crear Cuenta', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 12),

              // Ya tengo cuenta
              SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.black87,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  onPressed: () => Navigator.pushNamed(context, Routes.loginZip),
                  child: const Text('Iniciar sesión', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Feature({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: Colors.white),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ],
    );
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.restaurant_menu, color: Color(0xFF2F6BFF)),
    );
  }
}
