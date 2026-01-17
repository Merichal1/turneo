import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../worker/worker_home_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _email = TextEditingController();
  final _pass = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _dni = TextEditingController();
  final _edad = TextEditingController();
  final _aniosExp = TextEditingController();
  final _licencia = TextEditingController();

  String _puesto = 'camarero';
  bool _tieneVehiculo = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _email.dispose();
    _pass.dispose();
    _telefono.dispose();
    _ciudad.dispose();
    _dni.dispose();
    _edad.dispose();
    _aniosExp.dispose();
    _licencia.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final edad = int.tryParse(_edad.text.trim()) ?? 0;
      final anios = int.tryParse(_aniosExp.text.trim()) ?? 0;

      // ✅ Registro worker (tu AuthService lo guarda en:
      // empresas/{empresaId}/trabajadores/{uid} y también /users/{uid}
      await AuthService.instance.registerWorker(
        email: _email.text.trim(),
        password: _pass.text.trim(),
        nombre: _nombre.text.trim(),
        apellidos: _apellidos.text.trim(),
        telefono: _telefono.text.trim(),
        ciudad: _ciudad.text.trim(),
        dni: _dni.text.trim(),
        puesto: _puesto,
        edad: edad,
        aniosExperiencia: anios,
        tieneVehiculo: _tieneVehiculo,
        licencia: _licencia.text.trim(),
      );

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (_) => false,
      );
    } catch (e) {
      setState(() {
        _error = e.toString().replaceAll('Exception:', '').trim();
        if (_error!.isEmpty) _error = 'No se pudo crear la cuenta.';
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
              padding: const EdgeInsets.all(24),
              child: _Card(
                title: 'Crear Cuenta',
                subtitle: 'Regístrate en Turneo',
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_error != null) ...[
                        _ErrorText(_error!),
                        const SizedBox(height: 12),
                      ],

                      // Datos personales
                      _Field(
                        controller: _nombre,
                        label: 'Nombre',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _apellidos,
                        label: 'Apellidos',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                      ),
                      const SizedBox(height: 12),
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
                        validator: (v) {
                          if (v == null || v.isEmpty) return 'Obligatorio';
                          if (v.length < 6) return 'Mínimo 6 caracteres';
                          return null;
                        },
                      ),

                      const SizedBox(height: 16),
                      const Divider(height: 24),

                      // Empresa/licencia
                      _Field(
                        controller: _licencia,
                        label: 'Licencia Empresa',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'La licencia es obligatoria' : null,
                      ),

                      const SizedBox(height: 12),
                      _Field(
                        controller: _telefono,
                        label: 'Teléfono',
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _ciudad,
                        label: 'Ciudad',
                      ),
                      const SizedBox(height: 12),
                      _Field(
                        controller: _dni,
                        label: 'DNI',
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              value: _puesto,
                              decoration: InputDecoration(
                                labelText: 'Puesto',
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: const [
                                DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                                DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                                DropdownMenuItem(value: 'logistica', child: Text('Logística')),
                                DropdownMenuItem(value: 'limpiador', child: Text('Limpiador')),
                              ],
                              onChanged: (v) {
                                if (v == null) return;
                                setState(() => _puesto = v);
                              },
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _Field(
                              controller: _edad,
                              label: 'Edad',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _Field(
                              controller: _aniosExp,
                              label: 'Años experiencia',
                              keyboardType: TextInputType.number,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Vehículo propio', style: TextStyle(fontSize: 14)),
                              value: _tieneVehiculo,
                              onChanged: (v) => setState(() => _tieneVehiculo = v),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        height: 46,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: _loading ? null : _submit,
                          child: _loading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                  ),
                                )
                              : const Text('Crear cuenta'),
                        ),
                      ),

                      const SizedBox(height: 12),
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

  const _Card({
    required this.title,
    required this.subtitle,
    required this.child,
  });

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
      child: Text(text, style: const TextStyle(color: Color(0xFF991B1B))),
    );
  }
}
