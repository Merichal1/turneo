import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthService {
  AuthService._();
  static final AuthService instance = AuthService._();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // =========================
  // APPLE SIGN IN helpers
  // =========================
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }

  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  // =========================
  // FACEBOOK SIGN IN
  // =========================
Future<UserCredential> signInWithFacebook() async {
  // ✅ Web: OAuth con popup de Firebase
  if (kIsWeb) {
    final provider = FacebookAuthProvider()..addScope('email');
    return _auth.signInWithPopup(provider);
  }

  // ✅ iOS/Android: plugin nativo
  final result = await FacebookAuth.instance.login(permissions: ['email']);

  if (result.status != LoginStatus.success) {
    throw Exception('Facebook login cancelado o falló: ${result.status}');
  }

  final accessToken = result.accessToken;
  if (accessToken == null) throw Exception('No accessToken de Facebook');

  final token = accessToken.tokenString; // ✅ FIX
  final credential = FacebookAuthProvider.credential(token);

  return _auth.signInWithCredential(credential);
}

  // =========================
  // APPLE SIGN IN
  // =========================
  Future<UserCredential> signInWithApple() async {
    // ✅ Web: OAuth con popup de Firebase
    if (kIsWeb) {
      final provider = AppleAuthProvider()
        ..addScope('email')
        ..addScope('name');
      return _auth.signInWithPopup(provider);
    }

    // ✅ iOS/Android: flujo nativo con nonce
    // (En Android solo funcionará si tu app está bien configurada en Firebase + Apple Dev)
    final rawNonce = _generateNonce();
    final nonce = _sha256OfString(rawNonce);

    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: nonce,
    );

    final oauthCred = OAuthProvider('apple.com').credential(
      idToken: appleCredential.identityToken,
      rawNonce: rawNonce,
    );

    return _auth.signInWithCredential(oauthCred);
  }

  // =========================
  // EMAIL/PASS
  // =========================
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

  // =========================
  // SIGN OUT
  // =========================
  Future<void> signOut() async {
    // Cierra sesión en Firebase
    await _auth.signOut();

    // (Opcional pero recomendable) limpia sesión del plugin Facebook en móvil
    if (!kIsWeb) {
      try {
        await FacebookAuth.instance.logOut();
      } catch (_) {}
    }
  }

  // =========================
  // GOOGLE SIGN-IN (SIN google_sign_in)
  // =========================
  Future<UserCredential> signInWithGoogle() async {
    final provider = GoogleAuthProvider()..addScope('email');

    if (kIsWeb) {
      return _auth.signInWithPopup(provider);
    }

    // iOS/Android (Firebase Auth provider flow)
    return _auth.signInWithProvider(provider);
  }

  // =========================
  // ADMIN por email en empresas/*/Administradores
  // =========================
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

  // =========================
  // PERFIL WORKER
  // =========================
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
    if (!userDoc.exists) return;

    final data = userDoc.data()!;
    final empresaId = data['empresaId'];
    if (empresaId == null || empresaId.toString().isEmpty) return;

    // usuario completo → no hacer nada, el splash/router lo manda al home
  }

  // =========================
  // RESET PASSWORD
  // =========================
  Future<void> sendPasswordResetEmail(String email) async {
    final e = email.trim();
    if (e.isEmpty) throw Exception('Email vacío');
    await _auth.sendPasswordResetEmail(email: e);
  }

  // =========================
  // Guardar tipo de cuenta en /users/{uid} (opcional)
  // =========================
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
