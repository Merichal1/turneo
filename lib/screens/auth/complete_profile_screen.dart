import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';
import '../worker/worker_home_screen.dart';
import '../admin/admin_shell_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String email;
  const CompleteProfileScreen({super.key, required this.email});

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nombre = TextEditingController();
  final _apellidos = TextEditingController();
  final _telefono = TextEditingController();
  final _ciudad = TextEditingController();
  final _dni = TextEditingController();
  final _licencia = TextEditingController();

  String _puesto = 'camarero';
  final _edad = TextEditingController();
  final _exp = TextEditingController();
  bool _tieneVehiculo = false;

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nombre.dispose();
    _apellidos.dispose();
    _telefono.dispose();
    _ciudad.dispose();
    _dni.dispose();
    _licencia.dispose();
    _edad.dispose();
    _exp.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('No hay sesión.');

      final empresaId = await AuthService.instance.findEmpresaIdByLicencia(_licencia.text);
      if (empresaId == null) {
        throw Exception('Licencia no válida.');
      }

      await AuthService.instance.createOrUpdateWorkerProfile(
        uid: user.uid,
        empresaId: empresaId,
        email: widget.email,
        nombre: _nombre.text,
        apellidos: _apellidos.text,
        telefono: _telefono.text,
        ciudad: _ciudad.text,
        dni: _dni.text,
        puesto: _puesto,
        edad: int.tryParse(_edad.text.trim()) ?? 0,
        aniosExperiencia: int.tryParse(_exp.text.trim()) ?? 0,
        tieneVehiculo: _tieneVehiculo,
      );

      // Tras guardar perfil, decide admin/worker (por email admin)
      final isAdmin = await AuthService.instance.isAdminByEmail(widget.email);

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
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F8FC),
      appBar: AppBar(title: const Text('Completa tu perfil')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(22),
                boxShadow: const [
                  BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 10)),
                ],
              ),
              child: Form(
                key: _formKey,
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    if (_error != null) ...[
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_error!, style: const TextStyle(color: Color(0xFF991B1B))),
                      ),
                      const SizedBox(height: 12),
                    ],
                    TextFormField(
                      controller: _nombre,
                      decoration: const InputDecoration(labelText: 'Nombre'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _apellidos,
                      decoration: const InputDecoration(labelText: 'Apellidos'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _telefono,
                      decoration: const InputDecoration(labelText: 'Teléfono'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _ciudad,
                      decoration: const InputDecoration(labelText: 'Ciudad'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _dni,
                      decoration: const InputDecoration(labelText: 'DNI'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    TextFormField(
                      controller: _licencia,
                      decoration: const InputDecoration(labelText: 'Licencia de empresa'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Obligatorio' : null,
                    ),
                    const SizedBox(height: 10),
                    DropdownButtonFormField<String>(
                      value: _puesto,
                      decoration: const InputDecoration(labelText: 'Puesto'),
                      items: const [
                        DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                        DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                        DropdownMenuItem(value: 'logistica', child: Text('Logística')),
                        DropdownMenuItem(value: 'limpiador', child: Text('Limpiador')),
                        DropdownMenuItem(value: 'metre', child: Text('metre')),

                      ],
                      onChanged: (v) => setState(() => _puesto = v ?? 'camarero'),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _edad,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Edad'),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextFormField(
                            controller: _exp,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(labelText: 'Años exp.'),
                          ),
                        ),
                      ],
                    ),
                    SwitchListTile(
                      title: const Text('¿Vehículo propio?'),
                      value: _tieneVehiculo,
                      onChanged: (v) => setState(() => _tieneVehiculo = v),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 46,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        onPressed: _loading ? null : _save,
                        child: _loading
                            ? const CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                            : const Text('Guardar y continuar'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
