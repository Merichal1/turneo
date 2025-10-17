import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Roles soportados
enum AppRole { admin, worker, unknown }

class AuthProvider with ChangeNotifier {
  AuthProvider(this._auth);

  final FirebaseAuth _auth;

  User? _firebaseUser;
  String? _companyId; // de custom claims
  AppRole _role = AppRole.unknown;

  StreamSubscription<User?>? _authSub;

  User? get user => _firebaseUser;
  String? get companyId => _companyId;
  AppRole get role => _role;

  bool get isSignedIn => _firebaseUser != null;
  bool get isAdmin => _role == AppRole.admin;
  bool get isWorker => _role == AppRole.worker;

  /// Debe llamarse al iniciar la app (por ejemplo, en main al crear el provider)
  void start() {
    _authSub?.cancel();
    _authSub = _auth.authStateChanges().listen((u) async {
      _firebaseUser = u;
      if (u != null) {
        await _loadClaims();
      } else {
        _companyId = null;
        _role = AppRole.unknown;
      }
      notifyListeners();
    });
  }

  Future<void> disposeStream() async {
    await _authSub?.cancel();
  }

  Future<void> _loadClaims() async {
    try {
      final token = await _firebaseUser!.getIdTokenResult(true);
      final claims = token.claims ?? {};
      final cId = claims['companyId'] as String?;
      final roleStr = claims['role'] as String?;

      _companyId = cId;
      _role = switch (roleStr) {
        'admin' => AppRole.admin,
        'worker' => AppRole.worker,
        _ => AppRole.unknown,
      };

      // Fallback de desarrollo si aún no tienes claims en backend:
      // ⚠️ NO usar en producción.
      _companyId ??= kDebugMode ? 'acme' : null;
      if (_role == AppRole.unknown && kDebugMode) {
        _role = AppRole.admin; // para poder entrar al panel en dev
      }
    } catch (_) {
      _companyId = null;
      _role = AppRole.unknown;
    }
  }

  // ---- Auth API ----

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final cred = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    _firebaseUser = cred.user;
    await _loadClaims();
    notifyListeners();
    return cred;
  }

  Future<UserCredential> registerWithEmail(String email, String password) async {
    final cred = await _auth.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    _firebaseUser = cred.user;
    await _loadClaims(); // en producción, backend asigna claims tras signup
    notifyListeners();
    return cred;
  }

  Future<void> signOut() async {
    await _auth.signOut();
    _firebaseUser = null;
    _companyId = null;
    _role = AppRole.unknown;
    notifyListeners();
  }

  /// Forzar refresco de claims desde el backend (útil tras asignar licencia)
  Future<void> refreshClaims() async {
    if (_firebaseUser == null) return;
    await _firebaseUser!.getIdToken(true);
    await _loadClaims();
    notifyListeners();
  }
}
