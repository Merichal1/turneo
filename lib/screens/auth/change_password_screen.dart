import 'package:flutter/material.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});
  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  String email = '';

  Future<void> _reset() async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();
    // TODO: FirebaseAuth.sendPasswordResetEmail(email: email);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Te hemos enviado un correo para restablecer la contraseña')),
    );
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar contraseña')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(children: [
            TextFormField(
              decoration: const InputDecoration(labelText: 'Correo'),
              keyboardType: TextInputType.emailAddress,
              validator: (v) => (v == null || v.isEmpty) ? 'Requerido' : null,
              onSaved: (v) => email = v!.trim(),
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _reset, child: const Text('Enviar enlace')),
          ]),
        ),
      ),
    );
  }
}
