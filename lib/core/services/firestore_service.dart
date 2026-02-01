import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/evento.dart';
import '../../models/trabajador.dart';
import '../../models/disponibilidad_evento.dart';

class SolicitudesResultado {
  final int creadas;
  final int descartadasPorIndisponible;
  final int descartadasPorConflicto;

  const SolicitudesResultado({
    required this.creadas,
    required this.descartadasPorIndisponible,
    required this.descartadasPorConflicto,
  });
}

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
  // HELPERS (fechas / solapes)
  // ==========================

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  String _dayId(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  List<DateTime> _daysBetweenInclusive(DateTime start, DateTime end) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    final days = <DateTime>[];
    var cur = s;
    while (!cur.isAfter(e)) {
      days.add(cur);
      cur = cur.add(const Duration(days: 1));
    }
    return days;
  }

  bool _solapa(DateTime aIni, DateTime aFin, DateTime bIni, DateTime bFin) {
    // solapa si aIni < bFin && aFin > bIni
    return aIni.isBefore(bFin) && aFin.isAfter(bIni);
  }

  Iterable<List<T>> _chunks<T>(List<T> items, int size) sync* {
    for (var i = 0; i < items.length; i += size) {
      yield items.sublist(i, (i + size > items.length) ? items.length : i + size);
    }
  }

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

  Future<void> crearEvento(String empresaId, Evento evento) async {
    await empresaDoc(empresaId).collection('eventos').add(evento.toMap());
  }

  Future<void> actualizarEvento(String empresaId, Evento evento) async {
    await empresaDoc(empresaId)
        .collection('eventos')
        .doc(evento.id)
        .set(evento.toMap(), SetOptions(merge: true));
  }

Future<void> borrarEvento(
  String empresaId,
  String eventoId, {
  void Function(String msg)? onStatus,
  void Function(int done, int total)? onProgress,
}) async {
  onStatus?.call("Preparando borrado del evento...");
  final rango = await _getEventoRango(empresaId, eventoId);

  final eventoRef = empresaDoc(empresaId).collection('eventos').doc(eventoId);
  final dispoCol = eventoRef.collection('disponibilidad');

  onStatus?.call("Leyendo asignaciones...");
  final dispoSnap = await dispoCol.get();

  // Solo contamos asignados (para progreso real)
  final asignadosDocs = dispoSnap.docs
      .where((d) => (d.data()['asignado'] == true))
      .toList();

  final total = asignadosDocs.length;
  int done = 0;

  if (total > 0) {
    onStatus?.call("Liberando ocupaciones de $total trabajadores...");
  } else {
    onStatus?.call("No hay ocupaciones que liberar.");
  }

  for (final d in asignadosDocs) {
    final data = d.data();

    final trabajadorDocId = await _resolveTrabajadorDocIdFromDisponibilidad(
      empresaId: empresaId,
      dispoData: data,
      fallbackId: d.id,
    );

    await eliminarOcupacionEventoParaTrabajador(
      empresaId: empresaId,
      trabajadorDocId: trabajadorDocId,
      eventoId: eventoId,
      inicioEvento: rango.inicio,
      finEvento: rango.fin,
    );

    done++;
    onProgress?.call(done, total);
  }

  onStatus?.call("Borrando solicitudes del evento...");
  // borrar subcolección disponibilidad en chunks
  for (final chunk in _chunks(dispoSnap.docs, 400)) {
    final batch = _db.batch();
    for (final doc in chunk) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  onStatus?.call("Borrando evento...");
  await eventoRef.delete();

  onStatus?.call("✅ Evento borrado. Ocupaciones liberadas: ya pueden reasignarse.");
}



  // ==========================
  // TRABAJADORES
  // ==========================

  Stream<List<Trabajador>> listenTrabajadores(String empresaId) {
    return empresaDoc(empresaId)
        .collection('trabajadores')
        .orderBy('nombre_lower')
        .snapshots()
        .map((snap) => snap.docs.map((d) => Trabajador.fromFirestore(d)).toList());
  }

  // ==========================
  // NOTIFICACIONES
  // ==========================

  Stream<List<Map<String, dynamic>>> listenNotificacionesRecientes(String empresaId) {
    return empresaDoc(empresaId)
        .collection('notificaciones')
        .orderBy('creadoEn', descending: true)
        .limit(8)
        .snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // ==========================
  // RESOLVER DOCID REAL /trabajadores/{docId}
  // (esto arregla el 90% de "me deja asignar")
  // ==========================

  Future<String> resolveTrabajadorDocId(
    String empresaId, {
    required String uid,
    String? email,
  }) async {
    final col = empresaDoc(empresaId).collection('trabajadores');

    final byId = await col.doc(uid).get();
    if (byId.exists) return uid;

    final q1 = await col.where('uid', isEqualTo: uid).limit(1).get();
    if (q1.docs.isNotEmpty) return q1.docs.first.id;

    final q2 = await col.where('userId', isEqualTo: uid).limit(1).get();
    if (q2.docs.isNotEmpty) return q2.docs.first.id;

    final q3 = await col.where('authUid', isEqualTo: uid).limit(1).get();
    if (q3.docs.isNotEmpty) return q3.docs.first.id;

    if (email != null && email.isNotEmpty) {
      final q4 = await col.where('email', isEqualTo: email).limit(1).get();
      if (q4.docs.isNotEmpty) return q4.docs.first.id;
    }

    // fallback (si el dato viene sucio)
    return uid;
  }

  Future<String> _resolveTrabajadorDocIdFromDisponibilidad({
    required String empresaId,
    required Map<String, dynamic> dispoData,
    required String fallbackId,
  }) async {
    final saved = (dispoData['trabajadorDocId'] ?? '').toString().trim();
    if (saved.isNotEmpty) return saved;

    final uid = (dispoData['trabajadorId'] ?? fallbackId).toString();
    final email =
        (dispoData['trabajadorEmail'] ?? dispoData['email'] ?? '').toString().trim();

    return resolveTrabajadorDocId(
      empresaId,
      uid: uid,
      email: email.isEmpty ? null : email,
    );
  }

  // ==========================
  // EVENTO RANGO
  // ==========================

  Future<_EventoRango> _getEventoRango(String empresaId, String eventoId) async {
    final doc = await empresaDoc(empresaId).collection('eventos').doc(eventoId).get();
    final data = doc.data();
    if (data == null) throw Exception("Evento no encontrado: $eventoId");

    final tsIni = data['fechaInicio'] as Timestamp?;
    final tsFin = data['fechaFin'] as Timestamp?;

    if (tsIni == null) throw Exception("Evento sin fechaInicio: $eventoId");

    final ini = tsIni.toDate();
    final fin = (tsFin ?? tsIni).toDate();

    return _EventoRango(inicio: ini, fin: fin);
  }

  // ==========================
  // INDISPONIBILIDAD
  // ==========================

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

    final fechaId =
        "${dayStart.year}-${dayStart.month.toString().padLeft(2, '0')}-${dayStart.day.toString().padLeft(2, '0')}";

    final byId = await col.doc(fechaId).get();
    if (byId.exists) return true;

    final q = await col
        .where('fecha', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('fecha', isLessThan: Timestamp.fromDate(dayEnd))
        .limit(1)
        .get();

    return q.docs.isNotEmpty;
  }

  Future<bool> verificarIndisponibilidadEnRango({
    required String empresaId,
    required String trabajadorDocId,
    required DateTime inicio,
    required DateTime fin,
  }) async {
    final dias = _daysBetweenInclusive(inicio, fin);
    for (final d in dias) {
      final noDisp = await verificarIndisponibilidad(empresaId, trabajadorDocId, d);
      if (noDisp) return true;
    }
    return false;
  }

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

  // ==========================
  // OCUPACION EVENTOS (conflicto)
  // ==========================

  Future<bool> verificarConflictoHorarioAsignado({
    required String empresaId,
    required String trabajadorDocId, // 👈 docId REAL
    required DateTime inicioEvento,
    required DateTime finEvento,
    String? excluirEventoId,
  }) async {
    final dias = _daysBetweenInclusive(inicioEvento, finEvento);
    final diaIds = dias.map(_dayId).toList();

    final ref = empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('ocupacion_eventos');

    for (final chunk in _chunks(diaIds, 10)) {
      final qs = await ref
          .where('activo', isEqualTo: true)
          .where('diaId', whereIn: chunk)
          .get();

      for (final doc in qs.docs) {
        final data = doc.data();

        final String evId = (data['eventoId'] ?? '').toString();
        if (excluirEventoId != null && evId == excluirEventoId) continue;

        final tsIni = data['inicio'] as Timestamp?;
        final tsFin = data['fin'] as Timestamp?;
        if (tsIni == null || tsFin == null) continue;

        final ini = tsIni.toDate();
        final fin = tsFin.toDate();

        if (_solapa(ini, fin, inicioEvento, finEvento)) return true;
      }
    }

    return false;
  }

  Future<void> crearOcupacionEventoParaTrabajador({
    required String empresaId,
    required String trabajadorDocId,
    required String eventoId,
    required DateTime inicioEvento,
    required DateTime finEvento,
  }) async {
    final dias = _daysBetweenInclusive(inicioEvento, finEvento);

    final ref = empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('ocupacion_eventos');

    final batch = _db.batch();
    for (final d in dias) {
      final docId = "$eventoId-${_dayId(d)}";
      batch.set(
        ref.doc(docId),
        {
          'eventoId': eventoId,
          'diaId': _dayId(d),
          'inicio': Timestamp.fromDate(inicioEvento),
          'fin': Timestamp.fromDate(finEvento),
          'activo': true,
          'actualizadoEn': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  Future<void> eliminarOcupacionEventoParaTrabajador({
    required String empresaId,
    required String trabajadorDocId,
    required String eventoId,
    required DateTime inicioEvento,
    required DateTime finEvento,
  }) async {
    final dias = _daysBetweenInclusive(inicioEvento, finEvento);

    final ref = empresaDoc(empresaId)
        .collection('trabajadores')
        .doc(trabajadorDocId)
        .collection('ocupacion_eventos');

    final batch = _db.batch();
    for (final d in dias) {
      final docId = "$eventoId-${_dayId(d)}";
      batch.delete(ref.doc(docId));
    }
    await batch.commit();
  }

  // ==========================
  // DISPONIBILIDAD EVENTO
  // ==========================

  /// ✅ Enviar solicitudes SOLO si:
  /// - NO indisponible (en cualquier día del rango)
  /// - NO ocupado por otro evento solapado
  Future<SolicitudesResultado> crearSolicitudesDisponibilidadParaEvento({
  required String empresaId,
  required String eventoId,
  required List<Trabajador> trabajadores,
}) async {
  final rango = await _getEventoRango(empresaId, eventoId);

  int descartadasNoDisp = 0;
  int descartadasConf = 0;

  final libres = <Trabajador>[];

  for (final t in trabajadores) {
    final trabajadorDocId = t.id; // en tu admin: docId real

    final noDisp = await verificarIndisponibilidadEnRango(
      empresaId: empresaId,
      trabajadorDocId: trabajadorDocId,
      inicio: rango.inicio,
      fin: rango.fin,
    );
    if (noDisp) {
      descartadasNoDisp++;
      continue;
    }

    final conflicto = await verificarConflictoHorarioAsignado(
      empresaId: empresaId,
      trabajadorDocId: trabajadorDocId,
      inicioEvento: rango.inicio,
      finEvento: rango.fin,
      excluirEventoId: eventoId,
    );
    if (conflicto) {
      descartadasConf++;
      continue;
    }

    libres.add(t);
  }

  if (libres.isEmpty) {
    return SolicitudesResultado(
      creadas: 0,
      descartadasPorIndisponible: descartadasNoDisp,
      descartadasPorConflicto: descartadasConf,
    );
  }

  final batch = _db.batch();
  final now = DateTime.now();

  final dispoColl = empresaDoc(empresaId)
      .collection('eventos')
      .doc(eventoId)
      .collection('disponibilidad');

  for (final t in libres) {
    batch.set(
      dispoColl.doc(t.id),
      {
        'eventoId': eventoId,
        'trabajadorId': t.id,
        'trabajadorDocId': t.id,
        'trabajadorNombre': '${t.nombre} ${t.apellidos}'.trim(),
        'trabajadorRol': t.puesto ?? '',
        'estado': 'pendiente',
        'asignado': false,
        'creadoEn': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  await batch.commit();

  return SolicitudesResultado(
    creadas: libres.length,
    descartadasPorIndisponible: descartadasNoDisp,
    descartadasPorConflicto: descartadasConf,
  );
}

  Stream<List<DisponibilidadEvento>> listenDisponibilidadEvento(String empresaId, String eventoId) {
    return empresaDoc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DisponibilidadEvento.fromFirestore(d)).toList());
  }

  /// ✅ Asignación manual:
  /// - NO asigna si indisponible
  /// - NO asigna si conflicto
  /// - crea/borrar ocupación
  Future<void> marcarTrabajadorAsignado({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required bool asignado,
  }) async {
    final rango = await _getEventoRango(empresaId, eventoId);

    final dispoRef = empresaDoc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .doc(disponibilidadId);

    final dispoSnap = await dispoRef.get();
    final data = dispoSnap.data() ?? <String, dynamic>{};

    final trabajadorDocId = await _resolveTrabajadorDocIdFromDisponibilidad(
      empresaId: empresaId,
      dispoData: data,
      fallbackId: disponibilidadId,
    );

    if (asignado) {
      final noDisp = await verificarIndisponibilidadEnRango(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        inicio: rango.inicio,
        fin: rango.fin,
      );
      if (noDisp) {
        throw Exception("El trabajador está marcado como NO disponible en esas fechas.");
      }

      final conflicto = await verificarConflictoHorarioAsignado(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        inicioEvento: rango.inicio,
        finEvento: rango.fin,
        excluirEventoId: eventoId,
      );
      if (conflicto) {
        throw Exception("El trabajador ya está asignado a otro evento en ese horario.");
      }

      await dispoRef.update({
        'asignado': true,
        'estado': 'asignado',
        'trabajadorDocId': trabajadorDocId,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      await crearOcupacionEventoParaTrabajador(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        eventoId: eventoId,
        inicioEvento: rango.inicio,
        finEvento: rango.fin,
      );
    } else {
      await dispoRef.update({
        'asignado': false,
        'actualizadoEn': FieldValue.serverTimestamp(),
      });

      await eliminarOcupacionEventoParaTrabajador(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        eventoId: eventoId,
        inicioEvento: rango.inicio,
        finEvento: rango.fin,
      );
    }
  }

  Stream<List<DisponibilidadEvento>> listenSolicitudesDisponibilidadTrabajador(String trabajadorId) {
    return _db
        .collectionGroup('disponibilidad')
        .where('trabajadorId', isEqualTo: trabajadorId)
        .orderBy('creadoEn', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map((d) => DisponibilidadEvento.fromFirestore(d)).toList());
  }

  /// ✅ Auto-asignación:
  /// - respeta cupos
  /// - solo aceptados
  /// - NO asigna si indisponible o conflicto
  /// - crea ocupación para los asignados nuevos
  Future<Map<String, int>> autoAsignarEvento({
    required String empresaId,
    required String eventoId,
    required Map<String, int> rolesRequeridos,
  }) async {
    final rango = await _getEventoRango(empresaId, eventoId);

    final dispoRef = empresaDoc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad');

    final snapshot = await dispoRef.get();
    final docs = snapshot.docs;

    final batch = _db.batch();
    final Map<String, int> asignadosPorRol = {};
    final Set<String> asignadosDocIds = {};

    for (final entry in rolesRequeridos.entries) {
      final rol = entry.key;
      final requeridos = entry.value;

      final yaAsignados = docs.where((d) {
        final data = d.data();
        return (data['trabajadorRol'] ?? '') == rol && (data['asignado'] == true);
      }).length;

      var faltan = requeridos - yaAsignados;
      if (faltan <= 0) continue;

      final candidatos = docs.where((d) {
        final data = d.data();
        final rolOk = (data['trabajadorRol'] ?? '') == rol;
        final estadoOk = (data['estado'] ?? '') == 'aceptado';
        final asignadoOk = data['asignado'] != true;
        return rolOk && estadoOk && asignadoOk;
      }).toList()
        ..sort((a, b) {
          final ta = a.data()['respondidoEn'];
          final tb = b.data()['respondidoEn'];
          final tsa = (ta is Timestamp) ? ta : Timestamp(0, 0);
          final tsb = (tb is Timestamp) ? tb : Timestamp(0, 0);
          return tsa.compareTo(tsb);
        });

      int asignadosEsteRol = 0;

      for (final doc in candidatos) {
        if (faltan <= 0) break;

        final data = doc.data();

        final trabajadorDocId = await _resolveTrabajadorDocIdFromDisponibilidad(
          empresaId: empresaId,
          dispoData: data,
          fallbackId: doc.id,
        );

        final noDisp = await verificarIndisponibilidadEnRango(
          empresaId: empresaId,
          trabajadorDocId: trabajadorDocId,
          inicio: rango.inicio,
          fin: rango.fin,
        );
        if (noDisp) continue;

        final conflicto = await verificarConflictoHorarioAsignado(
          empresaId: empresaId,
          trabajadorDocId: trabajadorDocId,
          inicioEvento: rango.inicio,
          finEvento: rango.fin,
          excluirEventoId: eventoId,
        );
        if (conflicto) continue;

        batch.update(doc.reference, {
          'asignado': true,
          'estado': 'asignado',
          'trabajadorDocId': trabajadorDocId,
          'actualizadoEn': FieldValue.serverTimestamp(),
        });

        asignadosDocIds.add(trabajadorDocId);
        asignadosEsteRol++;
        faltan--;
      }

      if (asignadosEsteRol > 0) {
        asignadosPorRol[rol] = asignadosEsteRol;
      }
    }

    await batch.commit();

    for (final trabajadorDocId in asignadosDocIds) {
      await crearOcupacionEventoParaTrabajador(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        eventoId: eventoId,
        inicioEvento: rango.inicio,
        finEvento: rango.fin,
      );
    }

    return asignadosPorRol;
  }

  Future<void> actualizarEstadoDisponibilidad({
    required String empresaId,
    required String eventoId,
    required String disponibilidadId,
    required String nuevoEstado,
  }) async {
    await empresaDoc(empresaId)
        .collection('eventos')
        .doc(eventoId)
        .collection('disponibilidad')
        .doc(disponibilidadId)
        .update({
      'estado': nuevoEstado,
      'respondidoEn': FieldValue.serverTimestamp(),
    });
  }
  
  Future<void> repararOcupacionDesdeAsignados({
  required String empresaId,
  bool soloEventosActivos = true,
}) async {
  final eventosQ = empresaDoc(empresaId).collection('eventos');
  final eventosSnap = await eventosQ.get();

  for (final evDoc in eventosSnap.docs) {
    final ev = evDoc.data();
    final estado = (ev['estado'] ?? '').toString();

    if (soloEventosActivos && estado == 'cancelado') continue;

    final tsIni = ev['fechaInicio'] as Timestamp?;
    final tsFin = ev['fechaFin'] as Timestamp?;
    if (tsIni == null) continue;

    final inicio = tsIni.toDate();
    final fin = (tsFin ?? tsIni).toDate();

    final dispoSnap = await evDoc.reference.collection('disponibilidad').get();

    for (final d in dispoSnap.docs) {
      final data = d.data();
      final asignado = data['asignado'] == true;
      if (!asignado) continue;

      final trabajadorDocId = await _resolveTrabajadorDocIdFromDisponibilidad(
        empresaId: empresaId,
        dispoData: data,
        fallbackId: d.id,
      );

      await crearOcupacionEventoParaTrabajador(
        empresaId: empresaId,
        trabajadorDocId: trabajadorDocId,
        eventoId: evDoc.id,
        inicioEvento: inicio,
        finEvento: fin,
      );
    }
  }
}

}
class _EventoRango {
  final DateTime inicio;
  final DateTime fin;
  _EventoRango({required this.inicio, required this.fin});
}

