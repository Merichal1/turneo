import 'package:flutter/foundation.dart' show kIsWeb, defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/services/auth_service.dart';
import '../../../screens/admin/admin_shell_screen.dart';
import '../../../screens/worker/worker_home_screen.dart';
import '../../../screens/auth/complete_profile_screen.dart';

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

  bool _rememberMe = false;
  bool _hidePass = true;

  bool get _showApple => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    _loadRememberedEmail();
  }

  @override
  void dispose() {
    _email.dispose();
    _pass.dispose();
    super.dispose();
  }

  Future<void> _loadRememberedEmail() async {
    final sp = await SharedPreferences.getInstance();
    final saved = sp.getString('remember_email') ?? '';
    if (saved.isNotEmpty) {
      setState(() {
        _email.text = saved;
        _rememberMe = true;
      });
    }
  }

  Future<void> _saveRememberedEmailIfNeeded() async {
    final sp = await SharedPreferences.getInstance();
    if (_rememberMe) {
      await sp.setString('remember_email', _email.text.trim());
    } else {
      await sp.remove('remember_email');
    }
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

      await _saveRememberedEmailIfNeeded();
      await _postAuthNavigate(user.email ?? _email.text.trim(), user.uid);
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

      await _postAuthNavigate((user.email ?? '').trim(), user.uid);
    } catch (_) {
      setState(() => _error = 'No se pudo iniciar con Google.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _forgotPassword() async {
    final email = _email.text.trim();
    if (email.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Escribe tu email primero.')),
      );
      return;
    }

    try {
      await AuthService.instance.sendPasswordResetEmail(email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Te hemos enviado un email para restablecer la contraseña.')),
      );
    } catch (_) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No se pudo enviar el email de recuperación.')),
      );
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
                            Text('Iniciar Sesión', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
                            SizedBox(height: 8),
                            Text('Accede a tu cuenta para continuar', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w600)),
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

                      const Text('Contraseña', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 10),
                      TextFormField(
                        controller: _pass,
                        obscureText: _hidePass,
                        validator: (v) => (v == null || v.isEmpty) ? 'Obligatorio' : null,
                        decoration: _inputDecoration(
                          hint: '',
                          prefix: const Icon(Icons.lock_outline),
                          suffix: IconButton(
                            icon: Icon(_hidePass ? Icons.visibility_off_outlined : Icons.visibility_outlined),
                            onPressed: () => setState(() => _hidePass = !_hidePass),
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

Wrap(
  crossAxisAlignment: WrapCrossAlignment.center,
  spacing: 8,
  runSpacing: 6,
  children: [
    Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          value: _rememberMe,
          onChanged: (v) => setState(() => _rememberMe = v ?? false),
        ),
        const Text(
          'Recordarme',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
    Align(
      alignment: Alignment.centerRight,
      child: TextButton(
        onPressed: _forgotPassword,
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          minimumSize: Size.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        child: const FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            '¿Olvidaste tu contraseña?',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Color(0xFF2563EB),
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    ),
  ],
),
                      const SizedBox(height: 6),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _loading ? null : _submitEmailPass,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Text('Iniciar Sesión', style: TextStyle(fontWeight: FontWeight.w900)),
                        ),
                      ),

                      const SizedBox(height: 18),

                      Row(
                        children: const [
                          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                          Padding(
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Text('O continuar con', style: TextStyle(color: Colors.black54, fontWeight: FontWeight.w800)),
                          ),
                          Expanded(child: Divider(color: Color(0xFFE5E7EB))),
                        ],
                      ),

                      const SizedBox(height: 14),

                      SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(color: Color(0xFFE5E7EB)),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          onPressed: _loading ? null : _submitGoogle,
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