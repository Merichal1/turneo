import 'package:cloud_firestore/cloud_firestore.dart';

class Empresa {
  final String id;
  final String nombreComercial;
  final String correo;
  final String telefono;
  final String ciudad;
  final String? logo;
  final String estado;
  final List<String> propietarios;
  final List<String> administradores;
  final String zonaHoraria;

  Empresa({
    required this.id,
    required this.nombreComercial,
    required this.correo,
    required this.telefono,
    required this.ciudad,
    this.logo,
    required this.estado,
    required this.propietarios,
    required this.administradores,
    required this.zonaHoraria,
  });

  factory Empresa.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    return Empresa(
      id: doc.id,
      nombreComercial: data['nombreComercial'] ?? '',
      correo: data['correo'] ?? '',
      telefono: data['telefono'] ?? '',
      ciudad: data['ciudad'] ?? '',
      logo: data['logo'],
      estado: data['estado'] ?? 'activa',
      propietarios: List<String>.from(data['propietarios'] ?? const []),
      administradores: List<String>.from(data['administradores'] ?? const []),
      zonaHoraria: data['zonaHoraria'] ?? 'Europe/Madrid',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'nombreComercial': nombreComercial,
      'correo': correo,
      'telefono': telefono,
      'ciudad': ciudad,
      'logo': logo,
      'estado': estado,
      'propietarios': propietarios,
      'administradores': administradores,
      'zonaHoraria': zonaHoraria,
    };
  }

  Empresa copyWith({
    String? id,
    String? nombreComercial,
    String? correo,
    String? telefono,
    String? ciudad,
    String? logo,
    String? estado,
    List<String>? propietarios,
    List<String>? administradores,
    String? zonaHoraria,
  }) {
    return Empresa(
      id: id ?? this.id,
      nombreComercial: nombreComercial ?? this.nombreComercial,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      ciudad: ciudad ?? this.ciudad,
      logo: logo ?? this.logo,
      estado: estado ?? this.estado,
      propietarios: propietarios ?? this.propietarios,
      administradores: administradores ?? this.administradores,
      zonaHoraria: zonaHoraria ?? this.zonaHoraria,
    );
  }
}
