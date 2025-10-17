import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../core/services/functions_service.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _email2Ctrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _pass2Ctrl = TextEditingController();

  String licenseKey = '';
  String nombre = '';
  String apellidos = '';
  String dni = '';
  String localidad = '';
  String puesto = '';
  String telefono = '';
  bool tieneCoche = false;
  bool _loading = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _email2Ctrl.dispose();
    _passCtrl.dispose();
    _pass2Ctrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    setState(() => _loading = true);
    UserCredential? cred;

    try {
      // -------- 1) Validación/consumo de licencia --------
      final fx = FunctionsService();

      final valid = await fx.validateLicense(licenseKey);
      if (!valid) {
        if (!mounted) return;
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Licencia no válida')));
        setState(() => _loading = false);
        return;
      }

      final consumed = await fx.consumeLicense(licenseKey);
      if (!consumed) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No ha sido posible consumir la licencia')),
        );
        setState(() => _loading = false);
        return;
      }

      // -------- 2) Crear usuario en Auth --------
      final email = _emailCtrl.text.trim().toLowerCase();
      final pass = _passCtrl.text.trim();

      cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: pass,
      );
      final uid = cred.user!.uid;

      // (opcional) nombre visible en Auth
      await cred.user!.updateDisplayName(nombre.isNotEmpty ? nombre : email);

      // -------- 3) Guardar perfil en Firestore con ROL --------
      final isAntonio = email == 'antonio@gmail.com';
      final role = isAntonio ? 'admin' : 'worker';

      final perfil = <String, dynamic>{
        'email': email,
        'nombre': nombre,
        'apellidos': apellidos,
        'dni': dni,
        'localidad': localidad,
        'puesto': puesto.isEmpty ? 'Otro' : puesto,
        'telefono': telefono,
        'vehiculo': tieneCoche,
        'edad': 0,
        'experiencia': 0,
        'carnetConducir': false,
        'role': role,                // <- AQUÍ fijamos el rol
        'activo': false,             // el admin puede activarlo luego
        'noDisponible': <Timestamp>[],
        'licenseKey': licenseKey,    // para trazabilidad
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance.collection('users').doc(uid).set(perfil);

      // -------- 4) OK → al Splash para que enrute por rol --------
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Registro correcto')),
      );

      // Importante: ve a '/', y tu Splash redirige a /admin o /worker/home según el campo 'role'
      Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);

    } on FirebaseAuthException catch (e) {
      final msg = switch (e.code) {
        'email-already-in-use' => 'Ese correo ya está en uso.',
        'invalid-email' => 'Correo no válido.',
        'weak-password' => 'La contraseña es demasiado débil.',
        _ => 'Error de registro: ${e.code}',
      };
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
      }
      // cleanup si llegó a crear usuario
      if (cred?.user != null) {
        try { await cred!.user!.delete(); } catch (_) {}
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar: $e')),
        );
      }
      // cleanup si hay usuario actual creado
      final u = FirebaseAuth.instance.currentUser;
      if (u != null) { try { await u.delete(); } catch (_) {} }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final puestos = ['Montaje', 'Camarero', 'Seguridad', 'Conductor', 'Otro'];

    return Scaffold(
      appBar: AppBar(title: const Text('Rellena tus datos')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Estos datos se guardarán tras la supervisión del administrador.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Clave de licencia'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    onSaved: (v) => licenseKey = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    onSaved: (v) => nombre = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Apellidos'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                    onSaved: (v) => apellidos = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'DNI'),
                    onSaved: (v) => dni = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Correo'),
                    validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _email2Ctrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Confirmación del correo'),
                    validator: (v) => (v != _emailCtrl.text) ? 'El correo debe coincidir' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passCtrl,
                    decoration: const InputDecoration(labelText: 'Contraseña'),
                    obscureText: true,
                    validator: (v) => (v == null || v.length < 6) ? 'Mínimo 6 caracteres' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _pass2Ctrl,
                    decoration: const InputDecoration(labelText: 'Repite la contraseña'),
                    obscureText: true,
                    validator: (v) => (v != _passCtrl.text) ? 'Las contraseñas no coinciden' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Localidad'),
                    onSaved: (v) => localidad = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    decoration: const InputDecoration(labelText: 'Puesto de trabajo'),
                    items: puestos.map((p) => DropdownMenuItem(value: p, child: Text(p))).toList(),
                    onChanged: (v) => puesto = v ?? '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: const InputDecoration(labelText: 'Teléfono'),
                    keyboardType: TextInputType.phone,
                    onSaved: (v) => telefono = v!.trim(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    title: const Text('¿Dispone de coche para trabajar?'),
                    value: tieneCoche,
                    onChanged: (v) => setState(() => tieneCoche = v),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading
                        ? const SizedBox(
                            height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Text('Enviar'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
