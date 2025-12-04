import 'package:cloud_firestore/cloud_firestore.dart';

class Trabajador {
  final String id;
  final bool activo;

  // perfil
  final String nombre;
  final String apellidos;
  final String dni;
  final String correo;
  final String telefono;
  final String ciudad;

  // laboral
  final String puesto;
  final int aniosExperiencia;
  final bool tieneVehiculo;
  final int edad;

  final String nombreLower;
  final String ciudadLower;

  Trabajador({
    required this.id,
    required this.activo,
    required this.nombre,
    required this.apellidos,
    required this.dni,
    required this.correo,
    required this.telefono,
    required this.ciudad,
    required this.puesto,
    required this.aniosExperiencia,
    required this.tieneVehiculo,
    required this.edad,
    required this.nombreLower,
    required this.ciudadLower,
  });

  factory Trabajador.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};
    final perfil = Map<String, dynamic>.from(data['perfil'] ?? {});
    final laboral = Map<String, dynamic>.from(data['laboral'] ?? {});

    return Trabajador(
      id: doc.id,
      activo: data['activo'] ?? true,
      nombre: perfil['nombre'] ?? '',
      apellidos: perfil['apellidos'] ?? '',
      dni: perfil['dni'] ?? '',
      correo: perfil['correo'] ?? '',
      telefono: perfil['telefono'] ?? '',
      ciudad: perfil['ciudad'] ?? '',
      puesto: laboral['puesto'] ?? '',
      aniosExperiencia: (laboral['aniosExperiencia'] ?? 0) as int,
      tieneVehiculo: laboral['tieneVehiculo'] ?? false,
      edad: (laboral['edad'] ?? 0) as int,
      nombreLower: data['nombre_lower'] ?? '',
      ciudadLower: data['ciudad_lower'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activo': activo,
      'perfil': {
        'nombre': nombre,
        'apellidos': apellidos,
        'dni': dni,
        'correo': correo,
        'telefono': telefono,
        'ciudad': ciudad,
      },
      'laboral': {
        'puesto': puesto,
        'aniosExperiencia': aniosExperiencia,
        'tieneVehiculo': tieneVehiculo,
        'edad': edad,
      },
      'nombre_lower': nombreLower,
      'ciudad_lower': ciudadLower,
    };
  }

  Trabajador copyWith({
    String? id,
    bool? activo,
    String? nombre,
    String? apellidos,
    String? dni,
    String? correo,
    String? telefono,
    String? ciudad,
    String? puesto,
    int? aniosExperiencia,
    bool? tieneVehiculo,
    int? edad,
    String? nombreLower,
    String? ciudadLower,
  }) {
    return Trabajador(
      id: id ?? this.id,
      activo: activo ?? this.activo,
      nombre: nombre ?? this.nombre,
      apellidos: apellidos ?? this.apellidos,
      dni: dni ?? this.dni,
      correo: correo ?? this.correo,
      telefono: telefono ?? this.telefono,
      ciudad: ciudad ?? this.ciudad,
      puesto: puesto ?? this.puesto,
      aniosExperiencia: aniosExperiencia ?? this.aniosExperiencia,
      tieneVehiculo: tieneVehiculo ?? this.tieneVehiculo,
      edad: edad ?? this.edad,
      nombreLower: nombreLower ?? this.nombreLower,
      ciudadLower: ciudadLower ?? this.ciudadLower,
    );
  }
}
