import 'package:flutter/material.dart';
import 'package:turneo/auth_ui/constants.dart';
import '../../../components/already_have_an_account_acheck.dart';
import '../../Login/login_screen.dart';
import '../../../../core/services/auth_service.dart';
import '../../../../screens/worker/worker_home_screen.dart';
import '../../../../screens/admin/admin_home_screen.dart';

class SignUpForm extends StatefulWidget {
  const SignUpForm({Key? key}) : super(key: key);

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
  String _rol = 'worker'; 
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

      // Usamos el método unificado que creamos en AuthService
      await AuthService.instance.registerUser(
        email: _emailController.text,
        password: _passwordController.text,
        nombre: _nombreController.text.trim(),
        apellidos: _apellidosController.text.trim(),
        telefono: _telefonoController.text.trim(),
        ciudad: _ciudadController.text.trim(),
        dni: _dniController.text.trim(),
        puesto: _rol == 'admin' ? 'administrador' : _puesto,
        edad: edad,
        aniosExperiencia: aniosExp,
        tieneVehiculo: _tieneVehiculo,
        licencia: _licenciaController.text.trim(),
        role: _rol, 
      );

      if (!mounted) return;

      // Navegación según el rol seleccionado
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => _rol == 'admin' 
              ? const AdminHomeScreen() 
              : const WorkerHomeScreen(),
        ),
        (route) => false,
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: SingleChildScrollView( // Añadido para evitar error de overflow al abrir teclado
        child: Column(
          children: [
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              const SizedBox(height: defaultPadding / 2),
            ],
            // SELECCIÓN DE ROL
            DropdownButtonFormField<String>(
              value: _rol,
              decoration: const InputDecoration(
                labelText: "Tipo de Usuario",
                prefixIcon: Icon(Icons.manage_accounts),
              ),
              items: const [
                DropdownMenuItem(value: 'worker', child: Text('Trabajador')),
                DropdownMenuItem(value: 'admin', child: Text('Administrador')),
              ],
              onChanged: (v) => setState(() => _rol = v!),
            ),
            const SizedBox(height: defaultPadding),
            TextFormField(
              controller: _nombreController,
              decoration: const InputDecoration(hintText: "Nombre", prefixIcon: Icon(Icons.person)),
              validator: (v) => v == null || v.isEmpty ? "Obligatorio" : null,
            ),
            const SizedBox(height: defaultPadding / 2),
            TextFormField(
              controller: _apellidosController,
              decoration: const InputDecoration(hintText: "Apellidos", prefixIcon: Icon(Icons.person_outline)),
              validator: (v) => v == null || v.isEmpty ? "Obligatorio" : null,
            ),
            const SizedBox(height: defaultPadding / 2),
            TextFormField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(hintText: "Email", prefixIcon: Icon(Icons.email)),
              validator: (v) => v != null && v.contains('@') ? null : "Email no válido",
            ),
            const SizedBox(height: defaultPadding / 2),
            
            // CAMPOS EXTRA: Solo visibles si es trabajador
            if (_rol == 'worker') ...[
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _puesto,
                      decoration: const InputDecoration(labelText: "Puesto"),
                      items: const [
                        DropdownMenuItem(value: 'camarero', child: Text('Camarero')),
                        DropdownMenuItem(value: 'cocinero', child: Text('Cocinero')),
                        DropdownMenuItem(value: 'logistica', child: Text('Logística')),
                        DropdownMenuItem(value: 'limpiador', child: Text('Limpiador')),
                      ],
                      onChanged: (v) => setState(() => _puesto = v!),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _edadController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Edad"),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: defaultPadding / 2),
              SwitchListTile(
                title: const Text("¿Vehículo propio?", style: TextStyle(fontSize: 14)),
                value: _tieneVehiculo,
                onChanged: (v) => setState(() => _tieneVehiculo = v),
              ),
            ],
            
            const SizedBox(height: defaultPadding / 2),
            TextFormField(
              controller: _licenciaController,
              decoration: const InputDecoration(hintText: "Licencia Empresa", prefixIcon: Icon(Icons.key)),
              validator: (v) => v == null || v.isEmpty ? "La licencia es obligatoria" : null,
            ),
            const SizedBox(height: defaultPadding / 2),
            TextFormField(
              controller: _passwordController,
              obscureText: true,
              decoration: const InputDecoration(hintText: "Contraseña", prefixIcon: Icon(Icons.lock)),
              validator: (v) => v != null && v.length >= 6 ? null : "Mínimo 6 caracteres",
            ),
            const SizedBox(height: defaultPadding),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _submit,
                child: Text(_isLoading ? "PROCESANDO..." : "REGISTRARSE"),
              ),
            ),
            const SizedBox(height: defaultPadding),
            AlreadyHaveAnAccountCheck(
              login: false,
              press: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const LoginScreen())),
            ),
          ],
        ),
      ),
    );
  }
}