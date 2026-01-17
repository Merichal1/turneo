import 'package:flutter/material.dart';
import 'package:turneo/screens/Login/login_screen.dart';
import 'package:flutter/material.dart';
import 'package:turneo/screens/Signup/signup_screen.dart';
import '../../routes/app_routes.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;



class TurneoStartScreen extends StatelessWidget {
  const TurneoStartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final w = size.width;

    final isWide = w >= 1000;       // web “real”
    final isMedium = w >= 700;      // tablet / ventana mediana

    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isWide ? 28 : 18,
                vertical: isWide ? 22 : 14,
              ),
              child: isWide
                  ? _WideLayout()
                  : isMedium
                      ? const _MediumLayout()
                      : const _NarrowLayout(),
            ),
          ),
        ),
      ),
    );
  }
}

/// ✅ WEB: dos columnas, pero con proporción 60/40 y la tarjeta centrada verticalmente
class _WideLayout extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 6, child: _LeftMarketing()),
        SizedBox(width: 32),
        Expanded(flex: 4, child: _RightAuthCentered()),
      ],
    );
  }
}

/// ✅ TABLET: dos columnas pero más compactas
class _MediumLayout extends StatelessWidget {
  const _MediumLayout();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(flex: 5, child: _LeftMarketing(compact: true)),
        SizedBox(width: 20),
        Expanded(flex: 5, child: _RightAuthCentered()),
      ],
    );
  }
}

/// ✅ MÓVIL: columna con scroll
class _NarrowLayout extends StatelessWidget {
  const _NarrowLayout();

  @override
  Widget build(BuildContext context) {
    return const SingleChildScrollView(
      child: Column(
        children: [
          _LeftMarketing(compact: true),
          SizedBox(height: 18),
          _AuthCard(maxWidth: 520),
        ],
      ),
    );
  }
}

/// ✅ Columna derecha: centra la tarjeta verticalmente en web
class _RightAuthCentered extends StatelessWidget {
  const _RightAuthCentered();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: _AuthCard(maxWidth: 520),
    );
  }
}

class _LeftMarketing extends StatelessWidget {
  final bool compact;
  const _LeftMarketing({this.compact = false});

  @override
  Widget build(BuildContext context) {
    final titleSize = compact ? 36.0 : 52.0;
    final subSize = compact ? 15.0 : 16.0;

    return Align(
      alignment: Alignment.topLeft,
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
                  style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800),
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
              ),
            ),
            const SizedBox(height: 14),
            Text(
              'La plataforma completa para administrar tu equipo, eventos y horarios en el sector de la hostelería.',
              style: TextStyle(
                fontSize: subSize,
                height: 1.4,
                color: const Color(0xFF556070),
              ),
            ),
            const SizedBox(height: 24),
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
          ],
        ),
      ),
    );
  }
}

class _AuthCard extends StatelessWidget {
  final double maxWidth;
  const _AuthCard({required this.maxWidth});

  @override
  
  Widget build(BuildContext context) {
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
              color: Color(0x14000000),
              blurRadius: 24,
              offset: Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Bienvenido',
              style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            const Text(
              'Inicia sesión o crea una cuenta para comenzar',
              style: TextStyle(color: Color(0xFF6B7280)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const LoginScreenModern()),
                  );
                },
                child: const Text('Iniciar Sesión'),
              ),
            ),

            const SizedBox(height: 12),

            SizedBox(
              width: double.infinity,
              height: 46,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF2563EB),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SignUpScreen()),
                  );
                },
                child: const Text('Crear Cuenta'),
              ),
            ),
            if (showApple) ...[
  const SizedBox(height: 12),
  SizedBox(
    width: double.infinity,
    height: 46,
    child: OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        side: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      onPressed: () {
        // por ahora, lo dejamos como placeholder o lo conectamos cuando lo implementes
      },
      child: const Text('Continuar con Apple'),
    ),
  ),
],

          ],
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: const Color(0xFF2563EB)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
            ],
          ),
        ),
      ],
    );
  }
}

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Icon(Icons.restaurant_menu, color: Colors.white),
    );
  }
}
