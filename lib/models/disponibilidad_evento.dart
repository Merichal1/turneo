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

    return DisponibilidadEvento(
      id: doc.id,
      eventoId: data['eventoId'] as String? ?? '',
      trabajadorId: data['trabajadorId'] as String? ?? '',
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
      if (respondidoEn != null)
        'respondidoEn': Timestamp.fromDate(respondidoEn!),
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
