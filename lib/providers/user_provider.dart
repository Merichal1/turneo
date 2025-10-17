import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firestore_service.dart';
import '../models/user_model.dart';

/// Provider que gestiona la lista de usuarios y su sincronización con Firestore.
/// Permite aplicar filtros, crear y actualizar usuarios.
class UserProvider with ChangeNotifier {
  UserProvider({
    required FirebaseFirestore db,
    required String companyId,
  }) : _fs = FirestoreService(db, companyId: companyId) {
    _subscribe();
  }

  final FirestoreService _fs;

  List<UserModel> _users = [];
  StreamSubscription<List<UserModel>>? _sub;

  // Filtros actuales
  String _name = '';
  String _city = '';
  String _jobRole = '';

  /// Lista actual de usuarios
  List<UserModel> get users => _users;

  /// Filtros expuestos
  String get nameFilter => _name;
  String get cityFilter => _city;
  String get jobRoleFilter => _jobRole;

  /// Cambiar filtro de nombre
  set nameFilter(String v) {
    _name = v;
    _resubscribe();
  }

  /// Cambiar filtro de ciudad
  set cityFilter(String v) {
    _city = v;
    _resubscribe();
  }

  /// Cambiar filtro de puesto
  set jobRoleFilter(String v) {
    _jobRole = v;
    _resubscribe();
  }

  /// Inicia la suscripción al stream de usuarios
  void _subscribe() {
    _sub?.cancel();
    _sub = _fs
        .streamUsers(name: _name, city: _city, jobRole: _jobRole)
        .listen((list) {
      _users = list;
      notifyListeners();
    }, onError: (e, st) {
      debugPrint('Error al escuchar usuarios: $e');
    });
  }

  /// Reinicia la suscripción (p.ej. al cambiar filtros)
  void _resubscribe() {
    _subscribe();
  }

  /// Crea o actualiza un usuario
  Future<void> upsert(UserModel u) async {
    try {
      await _fs.upsertUser(u);
    } catch (e) {
      debugPrint('Error al guardar usuario: $e');
      rethrow;
    }
  }

  /// Cambia el estado activo/inactivo de un usuario
  Future<void> toggleActive(UserModel u, bool isActive) async {
    final updated = u.copyWith(isActive: isActive);
    await upsert(updated);
  }

  /// Limpia la suscripción al cerrar el provider
  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
