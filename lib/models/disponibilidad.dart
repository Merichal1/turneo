import 'package:cloud_firestore/cloud_firestore.dart';

class DisponibilidadEvento {
  final String id;
  final String eventoId;
  final String trabajadorId;
  final String trabajadorNombre;
  final String trabajadorRol;
  final String estado; // pendiente | aceptado | rechazado
  final bool asignado;
  final DateTime creadoEn;
  final DateTime? respondidoEn;

  DisponibilidadEvento({
    required this.id,
    required this.eventoId,
    required this.trabajadorId,
    required this.trabajadorNombre,
    required this.trabajadorRol,
    required this.estado,
    required this.asignado,
    required this.creadoEn,
    required this.respondidoEn,
  });

  factory DisponibilidadEvento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};

    // ✅ Si por lo que sea no viene eventoId/trabajadorId (docs antiguos),
    // lo inferimos del path y/o del docId.
    final inferredEventoId = doc.reference.parent.parent?.id ?? '';
    final inferredTrabajadorId = doc.id;

    return DisponibilidadEvento(
      id: doc.id,
      eventoId: (data['eventoId'] as String?)?.trim().isNotEmpty == true
          ? (data['eventoId'] as String)
          : inferredEventoId,
      trabajadorId: (data['trabajadorId'] as String?)?.trim().isNotEmpty == true
          ? (data['trabajadorId'] as String)
          : inferredTrabajadorId,
      trabajadorNombre: data['trabajadorNombre'] as String? ?? '',
      trabajadorRol: data['trabajadorRol'] as String? ?? '',
      estado: data['estado'] as String? ?? 'pendiente',
      asignado: data['asignado'] as bool? ?? false,
      creadoEn: (data['creadoEn'] as Timestamp?)?.toDate() ?? DateTime.now(),
      respondidoEn: (data['respondidoEn'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'eventoId': eventoId,
      'trabajadorId': trabajadorId,
      'trabajadorNombre': trabajadorNombre,
      'trabajadorRol': trabajadorRol,
      'estado': estado,
      'asignado': asignado,
      'creadoEn': Timestamp.fromDate(creadoEn),
      if (respondidoEn != null) 'respondidoEn': Timestamp.fromDate(respondidoEn!),
    };
  }

  DisponibilidadEvento copyWith({
    String? estado,
    bool? asignado,
    DateTime? respondidoEn,
  }) {
    return DisponibilidadEvento(
      id: id,
      eventoId: eventoId,
      trabajadorId: trabajadorId,
      trabajadorNombre: trabajadorNombre,
      trabajadorRol: trabajadorRol,
      estado: estado ?? this.estado,
      asignado: asignado ?? this.asignado,
      creadoEn: creadoEn,
      respondidoEn: respondidoEn ?? this.respondidoEn,
    );
  }
}
