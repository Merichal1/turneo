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

  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) async {
    return await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<void> signOut() => _auth.signOut();

  User? get currentUser => _auth.currentUser;

  // ==========================
  // REGISTRO DINÁMICO (ADMIN O TRABAJADOR)
  // ==========================

  Future<void> registerUser({
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
    required String role, // 'admin' o 'worker'
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

    // 2) Crear usuario en Firebase Auth
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );

    final uid = cred.user!.uid;
    final now = DateTime.now();

    // 3) Crear un documento en una colección global 'users' 
    // Esto evita que los datos se "machaquen" y facilita el login
    await _db.collection('users').doc(uid).set({
      'uid': uid,
      'email': email.trim(),
      'role': role,
      'empresaId': empresaId,
      'nombreCompleto': '$nombre $apellidos',
    });

    // 4) Guardar en la colección específica según el rol
    if (role == 'admin') {
      await _db.collection('empresas').doc(empresaId).collection('administradores').doc(uid).set({
        'nombre': nombre,
        'apellidos': apellidos,
        'email': email.trim(),
        'creadoEn': Timestamp.fromDate(now),
        'rol': 'admin',
      });
    } else {
      await _db.collection('empresas').doc(empresaId).collection('trabajadores').doc(uid).set({
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
        'rol': 'worker',
      });
    }
  }

  /// Método de ayuda para obtener el rol del usuario actual al loguear
  Future<String?> getUserRole(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return doc.data()?['role'] as String?;
    }
    return null;
  }
}