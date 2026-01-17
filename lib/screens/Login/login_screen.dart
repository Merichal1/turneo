import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../screens/admin/admin_shell_screen.dart';
import '../../../screens/worker/worker_home_screen.dart';
import '../../../screens/auth/complete_profile_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;


class LoginScreenModern extends StatefulWidget {
  const LoginScreenModern({super.key});

  @override
  State<LoginScreenModern> createState() => _LoginScreenModernState();
}

class _LoginScreenModernState extends State<LoginScreenModern> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _pass = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _goAfterAuth(String email) async {
    final isAdmin = await AuthService.instance.isAdminByEmail(email);

    if (!mounted) return;

    if (isAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminShellScreen()),
        (_) => false,
      );
    } else {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (_) => false,
      );
    }
  }
  Future<void> _postAuthNavigate(User user) async {
  final email = (user.email ?? '').trim();

  final isAdmin = await AuthService.instance.isAdminByEmail(email);
  if (!mounted) return;

  if (isAdmin) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const AdminShellScreen()),
      (_) => false,
    );
    return;
  }

  final exists = await AuthService.instance.workerProfileExistsAnywhere(user.uid);
  if (!mounted) return;

  if (!exists) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => CompleteProfileScreen(email: email)),
    );
    return;
  }

  Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
    (_) => false,
  );
}


  Future<void> _submitEmailPass() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AuthService.instance.signIn(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      final user = cred.user;
      if (user == null) throw Exception('No user');

      final email = (user.email ?? _email.text).trim();

      await _goAfterAuth(email);
    } catch (_) {
      setState(() => _error = 'Email o contraseña incorrectos.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _submitGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AuthService.instance.signInWithGoogle();
      final user = cred.user;
      if (user == null) throw Exception('No user');

      final email = (user.email ?? '').trim();

      // ✅ Si es admin, NO obligamos a completar perfil
      final isAdmin = await AuthService.instance.isAdminByEmail(email);
      if (!mounted) return;

      if (isAdmin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AdminShellScreen()),
          (_) => false,
        );
        return;
      }

      // ✅ Si NO es admin, obligamos perfil si no existe
      final exists = await AuthService.instance.workerProfileExistsAnywhere(user.uid);
      if (!mounted) return;

      if (!exists) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => CompleteProfileScreen(email: email)),
        );
        return;
      }

      // ✅ Si ya tiene perfil -> worker
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (_) => false,
      );
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar con Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showApple = !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: _Card(
                title: 'Iniciar Sesión',
                subtitle: 'Accede a tu cuenta de Turneo',
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        _ErrorText(_error!),
                        const SizedBox(height: 12),
                      ],
                      _Field(
                        controller: _email,
                        label: 'Email',
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obligatorio';
                          if (!v.contains('@')) return 'Email no válido';
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _pass,
                        label: 'Contraseña',
                        obscureText: true,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 16),

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
                          onPressed: _loading ? null : _submitEmailPass,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Entrar'),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: OutlinedButton(
                          onPressed: _loading ? null : _submitGoogle,
                          child: const Text('Continuar con Google'),
                        ),
                      ),
                      if (showApple) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 46,
                          child: OutlinedButton(
                            onPressed: _loading ? null : () {
                              // TODO: _submitApple()
                            },
                            child: const Text('Continuar con Apple'),
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),

                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Volver'),
                      ),
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

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _Card({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(subtitle, style: const TextStyle(color: Color(0xFF6B7280))),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }
}

class _Field extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool obscureText;
  final TextInputType? keyboardType;
  final String? Function(String?)? validator;

  const _Field({
    required this.controller,
    required this.label,
    this.obscureText = false,
    this.keyboardType,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _ErrorText extends StatelessWidget {
  final String text;
  const _ErrorText(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(color: Color(0xFF991B1B)),
      ),
    );
  }
}
