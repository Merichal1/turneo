import 'package:cloud_firestore/cloud_firestore.dart';

class Trabajador {
  final String id;
  final bool activo;

  // Perfil
  final String nombre;
  final String apellidos;
  final String correo;
  final String telefono;
  final String dni;
  final String ciudad;

  // Laboral
  final String puesto;
  final int edad;
  final int aniosExperiencia;
  final bool tieneVehiculo;

  final String nombreLower;
  final String ciudadLower;
  final DateTime? creadoEn;

  Trabajador({
    required this.id,
    required this.activo,
    required this.nombre,
    required this.apellidos,
    required this.correo,
    required this.telefono,
    required this.dni,
    required this.ciudad,
    required this.puesto,
    required this.edad,
    required this.aniosExperiencia,
    required this.tieneVehiculo,
    required this.nombreLower,
    required this.ciudadLower,
    this.creadoEn,
  });

  String get nombreCompleto => '$nombre $apellidos';

  factory Trabajador.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? <String, dynamic>{};

    final perfil = data['perfil'] as Map<String, dynamic>? ?? {};
    final laboral = data['laboral'] as Map<String, dynamic>? ?? {};
    final tsCreado = data['creadoEn'] as Timestamp?;

    return Trabajador(
      id: doc.id,
      activo: data['activo'] as bool? ?? true,
      nombre: perfil['nombre'] as String? ?? '',
      apellidos: perfil['apellidos'] as String? ?? '',
      correo: perfil['correo'] as String? ?? '',
      telefono: perfil['telefono'] as String? ?? '',
      dni: perfil['dni'] as String? ?? '',
      ciudad: perfil['ciudad'] as String? ?? '',
      puesto: laboral['puesto'] as String? ?? '',
      edad: (laboral['edad'] as num?)?.toInt() ?? 0,
      aniosExperiencia:
          (laboral['añosExperiencia'] as num?)?.toInt() ?? 0,
      tieneVehiculo: laboral['tieneVehiculo'] as bool? ?? false,
      nombreLower: data['nombre_lower'] as String? ?? '',
      ciudadLower: data['ciudad_lower'] as String? ?? '',
      creadoEn: tsCreado?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'activo': activo,
      'nombre_lower': nombreLower,
      'ciudad_lower': ciudadLower,
      'perfil': {
        'nombre': nombre,
        'apellidos': apellidos,
        'correo': correo,
        'telefono': telefono,
        'dni': dni,
        'ciudad': ciudad,
      },
      'laboral': {
        'puesto': puesto,
        'edad': edad,
        'añosExperiencia': aniosExperiencia,
        'tieneVehiculo': tieneVehiculo,
      },
      'creadoEn':
          creadoEn != null ? Timestamp.fromDate(creadoEn!) : FieldValue.serverTimestamp(),
    };
  }
}
