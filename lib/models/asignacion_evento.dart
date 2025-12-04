import 'package:cloud_firestore/cloud_firestore.dart';

class AsignacionEvento {
  final String id;
  final String idTrabajador;
  final String nombreTrabajador;
  final String rol;
  final String estado;      // invitado, aceptado, rechazado, asignado, completado
  final String estadoPago;  // pendiente, pagado
  final Map<String, dynamic> criterios;
  final DateTime? respondidoEn;
  final DateTime? actualizadoEn;

  AsignacionEvento({
    required this.id,
    required this.idTrabajador,
    required this.nombreTrabajador,
    required this.rol,
    required this.estado,
    required this.estadoPago,
    required this.criterios,
    this.respondidoEn,
    this.actualizadoEn,
  });

  factory AsignacionEvento.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final Timestamp? tsRespondido = data['respondidoEn'];
    final Timestamp? tsActualizado = data['actualizadoEn'];

    return AsignacionEvento(
      id: doc.id,
      idTrabajador: data['idTrabajador'] ?? '',
      nombreTrabajador: data['nombreTrabajador'] ?? '',
      rol: data['rol'] ?? '',
      estado: data['estado'] ?? 'invitado',
      estadoPago: data['estadoPago'] ?? 'pendiente',
      criterios: Map<String, dynamic>.from(data['criterios'] ?? {}),
      respondidoEn: tsRespondido?.toDate(),
      actualizadoEn: tsActualizado?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'idTrabajador': idTrabajador,
      'nombreTrabajador': nombreTrabajador,
      'rol': rol,
      'estado': estado,
      'estadoPago': estadoPago,
      'criterios': criterios,
      'respondidoEn':
          respondidoEn != null ? Timestamp.fromDate(respondidoEn!) : null,
      'actualizadoEn':
          actualizadoEn != null ? Timestamp.fromDate(actualizadoEn!) : null,
    };
  }
}
