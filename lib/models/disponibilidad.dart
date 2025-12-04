import 'package:cloud_firestore/cloud_firestore.dart';

class Disponibilidad {
  final String id; // normalmente será el aaaa-mm-dd
  final bool disponible;
  final String? nota;
  final DateTime? actualizadoEn;

  Disponibilidad({
    required this.id,
    required this.disponible,
    this.nota,
    this.actualizadoEn,
  });

  factory Disponibilidad.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final Timestamp? tsActualizado = data['actualizadoEn'];

    return Disponibilidad(
      id: doc.id,
      disponible: data['disponible'] ?? true,
      nota: data['nota'],
      actualizadoEn: tsActualizado?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'disponible': disponible,
      'nota': nota,
      'actualizadoEn':
          actualizadoEn != null ? Timestamp.fromDate(actualizadoEn!) : null,
    };
  }
}
