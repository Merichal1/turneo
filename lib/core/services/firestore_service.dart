import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/disponibilidad_evento.dart';

class FirestoreService {
  FirestoreService._();
  static final FirestoreService instance = FirestoreService._();
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ==========================
  // REFERENCIAS BASE
  // ==========================
  
  CollectionReference<Map<String, dynamic>> get empresasRef => _db.collection('empresas');

  DocumentReference<Map<String, dynamic>> empresaDoc(String empresaId) => empresasRef.doc(empresaId);

  CollectionReference<Map<String, dynamic>> notificacionesRef(String empresaId) =>
      empresaDoc(empresaId).collection('notificaciones');

  // ==========================
  // EVENTOS
  // ==========================

  Stream<List<Evento>> listenEventos(String empresaId) {
    return empresaDoc(empresaId)
        .collection('eventos')
        .orderBy('fechaInicio', descending: false)
        .snapshots()
        .map((snap) => snap.docs.map((d) => Evento.fromFirestore(d)).toList());
  }

  // NUEVO: Escucha notificaciones recientes de la empresa
  // NUEVO: Método optimizado en FirestoreService
Stream<List<Map<String, dynamic>>> listenNotificacionesRecientes(String empresaId) {
  return empresaDoc(empresaId)
      .collection('notificaciones')
      .orderBy('creadoEn', descending: true)
      .limit(8)
      .snapshots()
      .map((snap) => snap.docs.map((doc) => {
        'id': doc.id,
        ...doc.data(),
      }).toList());
}

  // ... (Resto del código existente se mantiene igual)
  Future<void> crearEvento(String empresaId, Evento evento) async {
    await empresaDoc(empresaId).collection('eventos').add(evento.toMap());
  }

  Future<void> actualizarEvento(String empresaId, Evento evento) async {
    await empresaDoc(empresaId)
        .collection('eventos')
        .doc(evento.id)
        .set(evento.toMap(), SetOptions(merge: true));
  }

  Future<void> borrarEvento(String empresaId, String eventoId) async {
    await empresaDoc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .delete();
  }

  Stream<List<Trabajador>> listenTrabajadores(String empresaId) {
    return empresaDoc(empresaId)
        .collection('trabajadores')
        .orderBy('nombre_lower')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Trabajador.fromFirestore(d)).toList());
  }

  Future<void> crearSolicitudesDisponibilidadParaEvento({
    required String empresaId,
    required String eventoId,
    required List<Trabajador> trabajadores,
  }) async {
    final batch = _db.batch();
    final now = DateTime.now();
    final dispoColl = empresaDoc(empresaId).collection('eventos').doc(eventoId).collection('disponibilidad');

    for (final t in trabajadores) {
      batch.set(dispoColl.doc(t.id), {
        'eventoId': eventoId,
        'trabajadorId': t.id,
        'trabajadorNombre': '${t.nombre} ${t.apellidos}'.trim(),
        'trabajadorRol': t.puesto ?? '',
        'estado': 'pendiente', 
        'asignado': false,
        'creadoEn': Timestamp.fromDate(now),
      }, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Stream<List<DisponibilidadEvento>> listenDisponibilidadEvento(String empresaId, String eventoId) {
    return empresaDoc(empresaId).collection('eventos').doc(eventoId).collection('disponibilidad')
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DisponibilidadEvento.fromFirestore(d)).toList());
  }

  Future<void> marcarTrabajadorAsignado({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required bool asignado,
  }) async {
    await empresaDoc(empresaId).collection('eventos').doc(eventoId).collection('disponibilidad')
        .doc(disponibilidadId).update({'asignado': asignado});
  }

  Stream<List<DisponibilidadEvento>> listenSolicitudesDisponibilidadTrabajador(String trabajadorId) {
    return _db.collectionGroup('disponibilidad')
        .where('trabajadorId', isEqualTo: trabajadorId)
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DisponibilidadEvento.fromFirestore(d)).toList());
  }

  Future<void> actualizarEstadoDisponibilidad({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required String nuevoEstado,
  }) async {
    await empresaDoc(empresaId).collection('eventos').doc(eventoId).collection('disponibilidad')
        .doc(disponibilidadId).update({
      'estado': nuevoEstado,
      'respondidoEn': FieldValue.serverTimestamp(),
    });
  }

  /// ✅ Guardar/quitar NO DISPONIBLE (normalizando a "solo día")
  Future<void> setDiaNoDisponible(
    String empresaId,
    String trabajadorDocId,
    DateTime fecha,
    bool esIndisponible,
  ) async {
    final day = DateTime(fecha.year, fecha.month, fecha.day);
    final fechaId =
        "${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}";

    final ref = empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('indisponibilidad')
        .doc(fechaId);

    if (esIndisponible) {
      await ref.set({'fecha': Timestamp.fromDate(day)});
    } else {
      await ref.delete();
    }
  }

  /// ✅ Comprueba NO DISPONIBLE aunque el docId no coincida (por campo fecha)
  Future<bool> verificarIndisponibilidad(
    String empresaId,
    String trabajadorDocId,
    DateTime fecha,
  ) async {
    final dayStart = DateTime(fecha.year, fecha.month, fecha.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final col = empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('indisponibilidad');

    // 1) rápido por ID si usas YYYY-MM-DD
    final fechaId =
        "${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}";
    final byId = await col.doc(fechaId).get();
    if (byId.exists) return true;

    // 2) fallback por campo fecha
    final q = await col
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('fecha', isLessThan: Timestamp.fromDate(dayEnd))
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

    /// ✅ Devuelve el docId REAL del trabajador dentro de /trabajadores
  /// Si tu docId ya es el uid -> perfecto
  /// Si no -> intenta por campos uid/userId/authUid/email
  Future<String> resolveTrabajadorDocId(
    String empresaId, {
    required String uid,
    String? email,
  }) async {
    final col = empresaDoc(empresaId).collection('trabajadores');

    // 1) docId == uid (ideal)
    final byId = await col.doc(uid).get();
    if (byId.exists) return uid;

    // 2) uid field
    final q1 = await col.where('uid', isEqualTo: uid).limit(1).get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;

    // 3) userId field
    final q2 = await col.where('userId', isEqualTo: uid).limit(1).get();
    if (q2.docs.isNotEmpty) return q2.docs.first.id;

    // 4) authUid field
    final q3 = await col.where('authUid', isEqualTo: uid).limit(1).get();
    if (q3.docs.isNotEmpty) return q3.docs.first.id;

    // 5) email field
    if (email != null && email.isNotEmpty) {
      final q4 = await col.where('email', isEqualTo: email).limit(1).get();
      if (q4.docs.isNotEmpty) return q4.docs.first.id;
    }

    // fallback
    return uid;
  }

  /// ✅ Stream de días NO disponibles del trabajador
  Stream<List<DateTime>> listenIndisponibilidadTrabajador(
    String empresaId,
    String trabajadorDocId,
  ) {
    return empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('indisponibilidad')
        .snapshots()
        .map((snap) {
      return snap.docs.map((doc) {
        final data = doc.data();
        final raw = data['fecha'];

        if (raw is Timestamp) {
          final d = raw.toDate();
          return DateTime(d.year, d.month, d.day);
        }

        // fallback por doc.id "YYYY-MM-DD"
        final parts = doc.id.split('-');
        if (parts.length == 3) {
          final y = int.tryParse(parts[0]) ?? 1970;
          final m = int.tryParse(parts[1]) ?? 1;
          final day = int.tryParse(parts[2]) ?? 1;
          return DateTime(y, m, day);
        }

        return DateTime.now();
      }).toList();
    });
  }

  
}