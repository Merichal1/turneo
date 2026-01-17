import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../admin/admin_shell_screen.dart';
import '../worker/worker_home_screen.dart';
import '../auth/complete_profile_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _fullName = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _pass2 = TextEditingController();

  bool _loading = false;
  String? _error;

  bool _acceptTerms = false;
  bool _hidePass = true;
  bool _hidePass2 = true;

  String _accountType = 'Trabajador';

  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _pass.dispose();
    _pass2.dispose();
    super.dispose();
  }

  Future<void> _postAuthNavigate(String email, String uid) async {
    final cleanEmail = email.trim();

    final isAdmin = await AuthService.instance.isAdminByEmail(cleanEmail);
    if (!mounted) return;

    if (isAdmin) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const AdminShellScreen()),
        (_) => false,
      );
      return;
    }

    final exists = await AuthService.instance.workerProfileExistsAnywhere(uid);
    if (!mounted) return;

    if (!exists) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => CompleteProfileScreen(email: cleanEmail)),
      );
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
      (_) => false,
    );
  }

  Future<void> _signupEmail() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_acceptTerms) {
      setState(() => _error = 'Debes aceptar los términos y la política de privacidad.');
      return;
    }

    if (_pass.text != _pass2.text) {
      setState(() => _error = 'Las contraseñas no coinciden.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AuthService.instance.registerWithEmail(
        email: _email.text.trim(),
        password: _pass.text.trim(),
      );

      // Guardar tipo de cuenta (opcional, no rompe nada)
      await AuthService.instance.saveAccountTypeForCurrentUser(_accountType);

      final user = cred.user;
      if (user == null) throw Exception('No user');

      await _postAuthNavigate(user.email ?? _email.text.trim(), user.uid);
    } catch (e) {
      setState(() => _error = 'No se pudo crear la cuenta.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _signupGoogle() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = await AuthService.instance.signInWithGoogle();
      final user = cred.user;
      if (user == null) throw Exception('No user');

      await AuthService.instance.saveAccountTypeForCurrentUser(_accountType);

      await _postAuthNavigate((user.email ?? '').trim(), user.uid);
    } catch (_) {
      setState(() => _error = 'No se pudo continuar con Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _inputDecoration({
    required String hint,
    required Widget prefix,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: prefix,
      suffixIcon: suffix,
      filled: true,
      fillColor: const Color(0xFFF7F8FA),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: const BorderSide(color: Color(0xFF2563EB), width: 1.6),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(color: Color(0x14000000), blurRadius: 28, offset: Offset(0, 14)),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.arrow_back),
                            SizedBox(width: 10),
                            Text('Volver', style: TextStyle(fontWeight: FontWeight.w800)),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),

                      Center(
                        child: Column(
                          children: const [
                            _Logo(),
                            SizedBox(height: 12),
                            Text('Crear Cuenta', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            SizedBox(height: 8),
                            Text('Regístrate para comenzar a gestionar tu equipo', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 18),

                      if (_error != null) ...[
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFFEE2E2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B), fontWeight: FontWeight.w700)),
                        ),
                        const SizedBox(height: 12),
                      ],

                      // Botones sociales
                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _loading ? null : _signupGoogle,
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('G', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                              SizedBox(width: 12),
                              Text('Continuar con Google', style: TextStyle(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: (_loading || !_showApple)
                              ? null
                              : () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Apple Sign-In: próximamente')),
                                  );
                                },
                          child: const Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.apple),
                              SizedBox(width: 12),
                              Text('Continuar con Apple', style: TextStyle(fontWeight: FontWeight.w900)),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: const [
                          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('O registrarse con email', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        ],
                      ),

                      const SizedBox(height: 18),

                      const Text('Nombre Completo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _fullName,
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                        decoration: _inputDecoration(
                          hint: 'Tu nombre',
                          prefix: const Icon(Icons.person_outline),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text('Correo Electrónico', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Obligatorio';
                          if (!v.contains('@')) return 'Email no válido';
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: 'tu@email.com',
                          prefix: const Icon(Icons.mail_outline),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text('Tipo de Cuenta', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFFF7F8FA),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0xFFE5E7EB)),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _accountType,
                            isExpanded: true,
                            items: const [
                              DropdownMenuItem(value: 'Trabajador', child: Text('Trabajador')),
                              DropdownMenuItem(value: 'Administrador', child: Text('Administrador')),
                            ],
                            onChanged: (v) => setState(() => _accountType = v ?? 'Trabajador'),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text('Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hidePass,
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obligatorio';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                        decoration: _inputDecoration(
                          hint: '',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(_hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _hidePass = !_hidePass),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      const Text('Confirmar Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pass2,
                        obscureText: _hidePass2,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        decoration: _inputDecoration(
                          hint: '',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(_hidePass2 ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _hidePass2 = !_hidePass2),
                          ),
                        ),
                      ),

                      const SizedBox(height: 14),

                      Row(
                        children: [
                          Checkbox(
                            value: _acceptTerms,
                            onChanged: (v) => setState(() => _acceptTerms = v ?? false),
                          ),
                          Expanded(
                            child: Wrap(
                              children: const [
                                Text('Acepto los ', style: TextStyle(fontWeight: FontWeight.w800)),
                                Text('términos y condiciones', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900)),
                                Text(' y la ', style: TextStyle(fontWeight: FontWeight.w800)),
                                Text('política de privacidad', style: TextStyle(color: Color(0xFF2563EB), fontWeight: FontWeight.w900)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 10),

                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          ),
                          onPressed: _loading ? null : _signupEmail,
                          child: _loading
                              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                              : const Text('Crear Cuenta', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16)),
                        ),
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

class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 74,
      height: 74,
      decoration: BoxDecoration(
        color: const Color(0xFF2563EB),
        borderRadius: BorderRadius.circular(22),
      ),
      child: const Icon(Icons.restaurant_menu, color: Colors.white, size: 34),
    );
  }
}
