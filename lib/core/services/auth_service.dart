import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  /// Busca la empresa a partir de una licencia.
  /// Supone que en `empresas` hay un campo `licencia` único.
  Future<String> _getEmpresaIdFromLicencia(String licencia) async {
    final snap = await _db
        .collection('empresas')
        .where('licencia', isEqualTo: licencia.trim())
        .limit(1)
        .get();

    if (snap.docs.isEmpty) {
      throw Exception('Licencia no válida.');
    }

    return snap.docs.first.id;
  }

  /// Registro de trabajador:
  /// 1. Valida la licencia y obtiene empresaId
  /// 2. Crea usuario en Firebase Auth
  /// 3. Crea doc en `empresas/{empresaId}/trabajadores/{uid}`
  Future<UserCredential> registerWorker({
    required String email,
    required String password,
    required String nombre,
    required String apellidos,
    required String telefono,
    required String ciudad,
    required String dni,
    required String puesto,
    required int edad,
    required int aniosExperiencia,
    required bool tieneVehiculo,
    required String licencia,
  }) async {
    // 1) Obtenemos la empresa a partir de la licencia
    final empresaId = await _getEmpresaIdFromLicencia(licencia);

    // 2) Alta en Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final uid = cred.user!.uid;

    // 3) Documento del trabajador dentro de la empresa
    final nombreLower = '$nombre $apellidos'.toLowerCase();
    final ciudadLower = ciudad.toLowerCase();

    final data = <String, dynamic>{
      'activo': true,
      'empresaId': empresaId,
      'nombre_lower': nombreLower,
      'ciudad_lower': ciudadLower,
      'perfil': {
        'nombre': nombre,
        'apellidos': apellidos,
        'correo': email,
        'telefono': telefono,
        'dni': dni,
        'ciudad': ciudad,
      },
      'laboral': {
        'puesto': puesto,
        'edad': edad,
        'añosExperiencia': aniosExperiencia,
        'tieneVehiculo': tieneVehiculo,
      },
      'creadoEn': FieldValue.serverTimestamp(),
    };

    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .doc(uid)
        .set(data);

    return cred;
  }
}
