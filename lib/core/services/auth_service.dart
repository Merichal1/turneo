import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // -------------------------
  // EMAIL/PASS
  // -------------------------
  Future<UserCredential> signIn({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  Future<UserCredential> registerWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
  }

  // -------------------------
  // SIGN OUT
  // -------------------------
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // -------------------------
  // GOOGLE SIGN-IN (SIN google_sign_in)
  // -------------------------
  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..addScope('email');

    if (kIsWeb) {
      // Web
      return _auth.signInWithPopup(provider);
    }

    // iOS/Android
    return _auth.signInWithProvider(provider);
  }

  // -------------------------
  // ADMIN por email en empresas/*/Administradores (campo Email/email)
  // -------------------------
  Future<bool> isAdminByEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return false;

    final empresas = await _db.collection('empresas').get();

    for (final emp in empresas.docs) {
      final adminsSnap = await _db
          .collection('empresas')
          .doc(emp.id)
          .collection('Administradores')
          .get();

      final match = adminsSnap.docs.any((d) {
        final stored = (d.data()['Email'] ?? d.data()['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return stored == e;
      });

      if (match) return true;
    }
    return false;
  }

  /// ✅ COMPAT: tu Splash lo usa (empresaId del admin por email)
  Future<String?> getEmpresaIdForAdminEmail(String email) async {
    final e = email.trim().toLowerCase();
    if (e.isEmpty) return null;

    final empresas = await _db.collection('empresas').get();

    for (final emp in empresas.docs) {
      final adminsSnap = await _db
          .collection('empresas')
          .doc(emp.id)
          .collection('Administradores')
          .get();

      final match = adminsSnap.docs.any((d) {
        final stored = (d.data()['Email'] ?? d.data()['email'] ?? '')
            .toString()
            .trim()
            .toLowerCase();
        return stored == e;
      });

      if (match) return emp.id;
    }
    return null;
  }

  // -------------------------
  // PERFIL WORKER: existe si está en empresas/*/trabajadores/{uid}
  // -------------------------
  Future<bool> workerProfileExistsAnywhere(String uid) async {
    final empresas = await _db.collection('empresas').get();
    for (final emp in empresas.docs) {
      final doc = await _db
          .collection('empresas')
          .doc(emp.id)
          .collection('trabajadores')
          .doc(uid)
          .get();
      if (doc.exists) return true;
    }
    return false;
  }

  Future<String?> findEmpresaIdByLicencia(String licencia) async {
    final lic = licencia.trim();
    if (lic.isEmpty) return null;

    final q = await _db
        .collection('empresas')
        .where('licencia', isEqualTo: lic)
        .limit(1)
        .get();

    if (q.docs.isEmpty) return null;
    return q.docs.first.id;
  }

  // -------------------------
  // CREAR / ACTUALIZAR PERFIL WORKER (SOLO en empresas/{empresaId}/trabajadores/{uid})
  // -------------------------
  Future<void> createOrUpdateWorkerProfile({
    required String uid,
    required String empresaId,
    required String email,
    required String nombre,
    required String apellidos,
    required String telefono,
    required String ciudad,
    required String dni,
    required String puesto,
    required int edad,
    required int aniosExperiencia,
    required bool tieneVehiculo,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .doc(uid)
        .set({
      'activo': true,
      'updatedAt': FieldValue.serverTimestamp(),
      'ciudad_lower': ciudad.trim().toLowerCase(),
      'nombre_lower': ('$nombre $apellidos').trim().toLowerCase(),
      'laboral': {
        'puesto': puesto.trim(),
        'edad': edad,
        'añosExperiencia': aniosExperiencia,
        'tieneVehiculo': tieneVehiculo,
      },
      'perfil': {
        'nombre': nombre.trim(),
        'apellidos': apellidos.trim(),
        'correo': email.trim().toLowerCase(),
        'telefono': telefono.trim(),
        'ciudad': ciudad.trim(),
        'dni': dni.trim(),
      },
      'empresaId': empresaId,
    }, SetOptions(merge: true));
  }

  /// ✅ COMPAT: tu signup antiguo llamaba a registerWorker.
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
    final empresaId = await findEmpresaIdByLicencia(licencia);
    if (empresaId == null) {
      throw Exception('Licencia no válida. No existe empresa con esa licencia.');
    }

    final cred = await registerWithEmail(email: email, password: password);
    final uid = cred.user?.uid;
    if (uid == null) throw Exception('No se pudo crear el usuario (uid null).');

    await createOrUpdateWorkerProfile(
      uid: uid,
      empresaId: empresaId,
      email: email,
      nombre: nombre,
      apellidos: apellidos,
      telefono: telefono,
      ciudad: ciudad,
      dni: dni,
      puesto: puesto,
      edad: edad,
      aniosExperiencia: aniosExperiencia,
      tieneVehiculo: tieneVehiculo,
    );

    return cred;
  }
  Future<void> handlePostLogin() async {
  final user = _auth.currentUser;
  if (user == null) return;

  final userDoc = await _db.collection('users').doc(user.uid).get();

  if (!userDoc.exists) {
    return;
  }

  final data = userDoc.data()!;
  final empresaId = data['empresaId'];

  if (empresaId == null || empresaId.toString().isEmpty) {
    return;
  }

  // usuario completo → no hacer nada, el splash/router lo manda al home
}
  // -------------------------
  // RESET PASSWORD
  // -------------------------
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) throw Exception('Email vacío');
    await _auth.sendPasswordResetEmail(email: e);
  }

  // -------------------------
  // (OPCIONAL) Guardar tipo de cuenta en /users/{uid}
  // No rompe nada aunque no lo uses aún.
  // -------------------------
  Future<void> saveAccountTypeForCurrentUser(String accountType) async {
    final u = _auth.currentUser;
    if (u == null) return;
    await _db.collection('users').doc(u.uid).set({
      'email': (u.email ?? '').trim().toLowerCase(),
      'accountType': accountType,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }


}
