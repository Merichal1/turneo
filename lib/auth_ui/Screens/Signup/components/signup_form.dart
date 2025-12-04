import 'package:flutter/material.dart';
import 'package:turneo/auth_ui/constants.dart';

import '../../../components/already_have_an_account_acheck.dart';
import '../../Login/login_screen.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../screens/worker/worker_home_screen.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({
    Key? key,
  }) : super(key: key);

  @override
  State<SignUpForm> createState() => _SignUpFormState();
}

class _SignUpFormState extends State<SignUpForm> {
  final _formKey = GlobalKey<FormState>();

  final _nombreController = TextEditingController();
  final _apellidosController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _ciudadController = TextEditingController();
  final _dniController = TextEditingController();
  final _edadController = TextEditingController();
  final _aniosExpController = TextEditingController();
  final _licenciaController = TextEditingController();

  String _puesto = 'camarero';
  bool _tieneVehiculo = false;
  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _nombreController.dispose();
    _apellidosController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _telefonoController.dispose();
    _ciudadController.dispose();
    _dniController.dispose();
    _edadController.dispose();
    _aniosExpController.dispose();
    _licenciaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final edad = int.tryParse(_edadController.text.trim()) ?? 0;
      final aniosExp = int.tryParse(_aniosExpController.text.trim()) ?? 0;

      await AuthService.instance.registerWorker(
        email: _emailController.text,
        password: _passwordController.text,
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        telefono: _telefonoController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        dni: _dniController.text.trim(),
        puesto: _puesto,
        edad: edad,
        aniosExperiencia: aniosExp,
        tieneVehiculo: _tieneVehiculo,
        licencia: _licenciaController.text.trim(),
      );

      if (!mounted) return;

      // Vamos a la home del trabajador
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const WorkerHomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          if (_error != null) ...[
            Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
            const SizedBox(height: defaultPadding / 2),
          ],
          // Nombre
          TextFormField(
            controller: _nombreController,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Nombre",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.person),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? "Campo obligatorio" : null,
          ),
          const SizedBox(height: defaultPadding / 2),
          // Apellidos
          TextFormField(
            controller: _apellidosController,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Apellidos",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.person_outline),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? "Campo obligatorio" : null,
          ),
          const SizedBox(height: defaultPadding / 2),
          // Email
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Correo electrónico",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.alternate_email),
              ),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) {
                return "El correo es obligatorio";
              }
              if (!v.contains('@')) return "Correo no válido";
              return null;
            },
          ),
          const SizedBox(height: defaultPadding / 2),
          // Teléfono
          TextFormField(
            controller: _telefonoController,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Teléfono",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.phone),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding / 2),
          // Ciudad
          TextFormField(
            controller: _ciudadController,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Ciudad",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.location_city),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding / 2),
          // DNI
          TextFormField(
            controller: _dniController,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "DNI",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.badge),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding / 2),
          // Puesto + Edad
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _puesto,
                  decoration: const InputDecoration(
                    hintText: 'Puesto',
                  ),
                  items: const [
                    DropdownMenuItem(
                        value: 'camarero', child: Text('Camarero')),
                    DropdownMenuItem(
                        value: 'cocinero', child: Text('Cocinero')),
                    DropdownMenuItem(
                        value: 'logistica', child: Text('Logística')),
                    DropdownMenuItem(
                        value: 'limpiador', child: Text('Limpiador')),
                    DropdownMenuItem(value: 'metre', child: Text('Metre')),
                    DropdownMenuItem(
                        value: 'coordinador', child: Text('Coordinador')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _puesto = v);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: _edadController,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.next,
                  cursorColor: kPrimaryColor,
                  decoration: const InputDecoration(
                    hintText: "Edad",
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: defaultPadding / 2),
          // Años experiencia
          TextFormField(
            controller: _aniosExpController,
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Años de experiencia",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.work_history),
              ),
            ),
          ),
          const SizedBox(height: defaultPadding / 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text("Dispongo de vehículo propio"),
            value: _tieneVehiculo,
            onChanged: (v) => setState(() => _tieneVehiculo = v),
          ),
          const SizedBox(height: defaultPadding / 2),
          // Licencia empresa
          TextFormField(
            controller: _licenciaController,
            textInputAction: TextInputAction.next,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Licencia de la empresa",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.key),
              ),
            ),
            validator: (v) =>
                v == null || v.trim().isEmpty ? "La licencia es obligatoria" : null,
          ),
          const SizedBox(height: defaultPadding / 2),
          // Password
          TextFormField(
            controller: _passwordController,
            textInputAction: TextInputAction.done,
            obscureText: true,
            cursorColor: kPrimaryColor,
            decoration: const InputDecoration(
              hintText: "Contraseña",
              prefixIcon: Padding(
                padding: EdgeInsets.all(defaultPadding),
                child: Icon(Icons.lock),
              ),
            ),
            validator: (v) {
              if (v == null || v.length < 6) {
                return "Mínimo 6 caracteres";
              }
              return null;
            },
          ),
          const SizedBox(height: defaultPadding / 2),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            child: _isLoading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text("Registrarte".toUpperCase()),
          ),
          const SizedBox(height: defaultPadding),
          AlreadyHaveAnAccountCheck(
            login: false,
            press: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) {
                    return const LoginScreen();
                  },
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
