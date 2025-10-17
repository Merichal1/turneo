import 'package:cloud_firestore/cloud_firestore.dart';

class ImportacionModel {
  final String id;
  final String nombreArchivo;
  final int registros;
  final bool ok;
  final DateTime createdAt;

  ImportacionModel({
    required this.id,
    required this.nombreArchivo,
    required this.registros,
    required this.ok,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'nombreArchivo': nombreArchivo,
        'registros': registros,
        'ok': ok,
        'createdAt': Timestamp.fromDate(createdAt),
      };

  factory ImportacionModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return ImportacionModel(
      id: doc.id,
      nombreArchivo: d['nombreArchivo'] ?? '',
      registros: (d['registros'] ?? 0) as int,
      ok: d['ok'] ?? false,
      createdAt: (d['createdAt'] as Timestamp).toDate(),
    );
  }
}
