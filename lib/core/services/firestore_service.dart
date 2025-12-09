import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/empresa.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/asignacion_evento.dart';
import '../../models/disponibilidad.dart';
import '../../models/disponibilidad_evento.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirestoreService {
  FirestoreService._();

  static final FirestoreService instance = FirestoreService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================
  // RUTAS BÁSICAS
  // ==========================

  CollectionReference<Map<String, dynamic>> get empresasRef =>
      _db.collection('empresas');

  DocumentReference<Map<String, dynamic>> empresaDoc(String empresaId) =>
      empresasRef.doc(empresaId);

  CollectionReference<Map<String, dynamic>> eventosRef(String empresaId) =>
      empresaDoc(empresaId).collection('eventos');

  DocumentReference<Map<String, dynamic>> eventoDoc(
    String empresaId,
    String eventoId,
  ) =>
      eventosRef(empresaId).doc(eventoId);

  CollectionReference<Map<String, dynamic>> asignacionesRef(
    String empresaId,
    String eventoId,
  ) =>
      eventoDoc(empresaId, eventoId).collection('asignaciones');

  CollectionReference<Map<String, dynamic>> trabajadoresRef(
    String empresaId,
  ) =>
      empresaDoc(empresaId).collection('trabajadores');

  DocumentReference<Map<String, dynamic>> trabajadorDoc(
    String empresaId,
    String trabajadorId,
  ) =>
      trabajadoresRef(empresaId).doc(trabajadorId);

  CollectionReference<Map<String, dynamic>> disponibilidadRef(
    String empresaId,
    String trabajadorId,
  ) =>
      trabajadorDoc(empresaId, trabajadorId).collection('disponibilidad');

  CollectionReference<Map<String, dynamic>> notificacionesRef(
    String empresaId,
  ) =>
      empresaDoc(empresaId).collection('notificaciones');

  CollectionReference<Map<String, dynamic>> mensajesRef(
    String empresaId,
  ) =>
      empresaDoc(empresaId).collection('mensajes');

  CollectionReference<Map<String, dynamic>> itemsMensajeRef(
    String empresaId,
    String hiloId,
  ) =>
      mensajesRef(empresaId).doc(hiloId).collection('items');

  CollectionReference<Map<String, dynamic>> pagosRef(
    String empresaId,
  ) =>
      empresaDoc(empresaId).collection('pagos');

  // ==========================
  // EMPRESAS
  // ==========================

  Future<Empresa?> getEmpresa(String empresaId) async {
    final doc = await empresaDoc(empresaId).get();
    if (!doc.exists) return null;
    return Empresa.fromFirestore(doc);
  }

  Stream<Empresa?> listenEmpresa(String empresaId) {
    return empresaDoc(empresaId).snapshots().map((doc) {
      if (!doc.exists) return null;
      return Empresa.fromFirestore(doc);
    });
  }

  Future<void> upsertEmpresa(Empresa empresa) async {
    await empresaDoc(empresa.id).set(empresa.toMap(), SetOptions(merge: true));
  }

  // ==========================
  // EVENTOS
  // ==========================

  Stream<List<Evento>> listenEventos(String empresaId, {String? estado}) {
    Query<Map<String, dynamic>> q = eventosRef(empresaId);

    if (estado != null) {
      q = q.where('estado', isEqualTo: estado);
    }

    return q.orderBy('fechaInicio', descending: false).snapshots().map(
      (snap) {
        return snap.docs.map((d) => Evento.fromFirestore(d)).toList();
      },
    );
  }

  Future<String> crearEvento(String empresaId, Evento evento) async {
    final ref = await eventosRef(empresaId).add(evento.toMap());
    return ref.id;
  }

  Future<void> actualizarEvento(String empresaId, Evento evento) async {
    await eventoDoc(empresaId, evento.id).set(
      evento.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> borrarEvento(String empresaId, String eventoId) async {
    await eventoDoc(empresaId, eventoId).delete();
  }

    // ==========================
  // TRABAJADORES
  // ==========================

  Stream<List<Trabajador>> listenTrabajadores(
    String empresaId, {
    bool? soloActivos,
  }) {
    Query<Map<String, dynamic>> q = trabajadoresRef(empresaId);

    if (soloActivos == true) {
      q = q.where('activo', isEqualTo: true);
    }

    return q.orderBy('nombre_lower').snapshots().map(
      (snap) {
        return snap.docs.map((d) => Trabajador.fromFirestore(d)).toList();
      },
    );
  }

  Future<String> crearTrabajador(String empresaId, Trabajador t) async {
    final ref = await trabajadoresRef(empresaId).add(t.toMap());
    return ref.id;
  }

  Future<void> actualizarTrabajador(String empresaId, Trabajador t) async {
    await trabajadorDoc(empresaId, t.id).set(
      t.toMap(),
      SetOptions(merge: true),
    );
  }

  Future<void> borrarTrabajador(String empresaId, String trabajadorId) async {
    await trabajadorDoc(empresaId, trabajadorId).delete();
  }

  /// 🔹 NUEVO: obtener el ID de trabajador (documento) a partir del UID de auth
  Future<String?> getTrabajadorIdPorUid(
    String empresaId,
    String authUid,
  ) async {
    final snap = await trabajadoresRef(empresaId)
        .where('authUid', isEqualTo: authUid)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id;
  }

  // ==========================
  // ASIGNACIONES DE EVENTO
  // ==========================

  Stream<List<AsignacionEvento>> listenAsignacionesEvento(
    String empresaId,
    String eventoId,
  ) {
    return asignacionesRef(empresaId, eventoId)
        .orderBy('actualizadoEn', descending: true)
        .snapshots()
        .map(
      (snap) {
        return snap.docs.map((d) => AsignacionEvento.fromFirestore(d)).toList();
      },
    );
  }

  Future<String> crearAsignacion(
    String empresaId,
    String eventoId,
    AsignacionEvento asignacion,
  ) async {
    final ref = await asignacionesRef(empresaId, eventoId).add(
      asignacion.toMap(),
    );
    return ref.id;
  }

  Future<void> actualizarAsignacion(
    String empresaId,
    String eventoId,
    AsignacionEvento asignacion,
  ) async {
    await asignacionesRef(empresaId, eventoId)
        .doc(asignacion.id)
        .set(asignacion.toMap(), SetOptions(merge: true));
  }

  Future<void> borrarAsignacion(
    String empresaId,
    String eventoId,
    String asignacionId,
  ) async {
    await asignacionesRef(empresaId, eventoId).doc(asignacionId).delete();
  }

  // ==========================
  // DISPONIBILIDAD TRABAJADOR (CALENDARIO PROPIO)
  // ==========================

  Stream<List<Disponibilidad>> listenDisponibilidadTrabajador(
    String empresaId,
    String trabajadorId,
  ) {
    return disponibilidadRef(empresaId, trabajadorId)
        .orderBy('actualizadoEn', descending: true)
        .snapshots()
        .map(
      (snap) {
        return snap.docs.map((d) => Disponibilidad.fromFirestore(d)).toList();
      },
    );
  }

  Future<void> setDisponibilidadDia({
    required String empresaId,
    required String trabajadorId,
    required String fechaId, // "2025-12-04"
    required bool disponible,
    String? nota,
    DateTime? actualizadoEn,
  }) async {
    await disponibilidadRef(empresaId, trabajadorId).doc(fechaId).set(
      {
        'disponible': disponible,
        'nota': nota,
        'actualizadoEn':
            Timestamp.fromDate(actualizadoEn ?? DateTime.now()),
      },
      SetOptions(merge: true),
    );
  }

  // ==========================
  // DISPONIBILIDAD POR EVENTO
  // ==========================

  /// Escucha las solicitudes de disponibilidad de un evento concreto
  Stream<List<DisponibilidadEvento>> listenDisponibilidadEvento(
    String empresaId,
    String eventoId,
  ) {
    return _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .orderBy('creadoEn', descending: false)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map(
                (d) => DisponibilidadEvento.fromFirestore(d),
              )
              .toList(),
        );
  }

  /// Crea solicitudes de disponibilidad para un evento a varios trabajadores
// FirestoreService.dart

Future<void> crearSolicitudesDisponibilidadParaEvento({
  required String empresaId,
  required String eventoId,
  required List<Trabajador> trabajadores,
}) async {
  final batch = _db.batch();

  // Mismo timestamp para todo el envío
  final now = DateTime.now();

  final dispoColl = _db
      .collection('empresas')
      .doc(empresaId)
      .collection('eventos')
      .doc(eventoId)
      .collection('disponibilidad');

  for (final t in trabajadores) {
    final docRef = dispoColl.doc(t.id);

    batch.set(
      docRef,
      {
        'eventoId': eventoId,
        'trabajadorId': t.id,
        'trabajadorNombre':
            '${t.nombre ?? ''} ${t.apellidos ?? ''}'.trim(),
        'trabajadorRol': t.puesto ?? '',
        // lo usaremos para el email:
        'trabajadorEmail': t.correo ?? '',
        'estado': 'pendiente', // pendiente | aceptado | rechazado
        'asignado': false,
        'creadoEn': Timestamp.fromDate(now),
        'respondidoEn': null,
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();
}

  /// Actualiza el estado de una solicitud (aceptado / rechazado / pendiente)
  Future<void> actualizarEstadoDisponibilidad({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required String nuevoEstado, // 'aceptado' | 'rechazado' | 'pendiente'
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .doc(disponibilidadId)
        .update({
      'estado': nuevoEstado,
      'respondidoEn': Timestamp.fromDate(DateTime.now()),
    });
  }

  /// Marca a un trabajador como asignado/no asignado a un evento
  Future<void> marcarTrabajadorAsignado({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required bool asignado,
  }) async {
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .doc(disponibilidadId)
        .update({
      'asignado': asignado,
    });
  }

  /// 🔍 Todas las solicitudes de disponibilidad (de todos los eventos)
  /// para un trabajador concreto (usado en la app del trabajador)
  Stream<List<DisponibilidadEvento>> listenSolicitudesDisponibilidadTrabajador(
    String trabajadorId,
  ) {
    return _db
        .collectionGroup('disponibilidad')
        .where('trabajadorId', isEqualTo: trabajadorId)
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map(
          (snap) => snap.docs
              .map((d) => DisponibilidadEvento.fromFirestore(d))
              .toList(),
        );
  }
    /// Busca una empresa por su código de licencia
  Future<String?> buscarEmpresaPorCodigoLicencia(String codigo) async {
    final snap = await _db
        .collection('empresas')
        .where('codigoLicencia', isEqualTo: codigo)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    return snap.docs.first.id; // empresaId
  }

  /// Crea automáticamente el trabajador dentro de la empresa
  Future<void> crearTrabajadorDesdeRegistro({
    required String codigoLicencia,
    required User user, // usuario de FirebaseAuth
    required String nombre,
    required String apellidos,
    required String ciudad,
    required String telefono,
    String? puesto,
    int? aniosExperiencia,
    bool tieneVehiculo = false,
  }) async {
    // 1) Buscar empresa por código
    final empresaId = await buscarEmpresaPorCodigoLicencia(codigoLicencia);
    if (empresaId == null) {
      throw Exception('Código de empresa no válido');
    }

    final ahora = DateTime.now();

    // 2) Crear documento en empresas/{empresaId}/trabajadores/{uid}
    await _db
        .collection('empresas')
        .doc(empresaId)
        .collection('trabajadores')
        .doc(user.uid) // usamos el UID como id de trabajador
        .set({
      'authUid': user.uid,
      'empresaId': empresaId,
      'activo': true,
      'creadoEn': Timestamp.fromDate(ahora),

      // campos para búsquedas/ordenaciones
      'ciudad_lower': ciudad.toLowerCase(),
      'nombre_lower': '${nombre.toLowerCase()} ${apellidos.toLowerCase()}',

      'perfil': {
        'nombre': nombre,
        'apellidos': apellidos,
        'ciudad': ciudad,
        'correo': user.email,
        'telefono': telefono,
      },
      'laboral': {
        'puesto': puesto ?? '',
        'añosExperiencia': aniosExperiencia ?? 0,
        'tieneVehiculo': tieneVehiculo,
      },
    });
  }

}
