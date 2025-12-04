import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/empresa.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/asignacion_evento.dart';
import '../../models/disponibilidad.dart';

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
  // DISPONIBILIDAD TRABAJADOR
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
}
