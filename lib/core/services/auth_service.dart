import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================
  // LOGIN / LOGOUT
  // ==========================

  /// Login genérico (lo usa tu LoginScreen)
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    return cred;
  }

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  // ==========================
  // REGISTRO DE TRABAJADOR
  // ==========================

  /// Registra un trabajador:
  /// 1) Busca la empresa por licencia
  /// 2) Crea el usuario en Firebase Auth
  /// 3) Crea el documento en empresas/{empresaId}/trabajadores/{uid}
  Future<void> registerWorker({
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
    final licenciaClean = licencia.trim().toLowerCase();

    // 1) Buscar empresa por licencia
    final empresasSnap = await _db
        .collection('empresas')
        .where('licencia', isEqualTo: licenciaClean)
        .limit(1)
        .get();

    if (empresasSnap.docs.isEmpty) {
      throw Exception('Licencia no válida. Consulta con tu empresa.');
    }

    final empresaDoc = empresasSnap.docs.first;
    final empresaId = empresaDoc.id;

    // 2) Crear usuario en Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;
    final now = DateTime.now();

    // 3) Crear documento del trabajador en la empresa
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .doc(uid)
        .set({
      'activo': true,
      'ciudad_lower': ciudad.toLowerCase(),
      'creadoEn': Timestamp.fromDate(now),
      'nombre_lower': '${nombre.toLowerCase()} ${apellidos.toLowerCase()}',
      'perfil': {
        'nombre': nombre,
        'apellidos': apellidos,
        'correo': email.trim(),
        'telefono': telefono.trim(),
        'ciudad': ciudad.trim(),
        'dni': dni.trim(),
      },
      'laboral': {
        'puesto': puesto,
        'edad': edad,
        'añosExperiencia': aniosExperiencia,
        'tieneVehiculo': tieneVehiculo,
      },
    });
  }
}
