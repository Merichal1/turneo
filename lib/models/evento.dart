import 'package:cloud_firestore/cloud_firestore.dart';

class Evento {
  final String id;
  final String nombre;
  final String tipo;
  final DateTime fechaInicio;
  final DateTime fechaFin;
  final String estado;

  final Map<String, int> rolesRequeridos;
  final int cantidadRequeridaTrabajadores;

  final String ciudad;
  final String direccion;

  // Para mapa
  final double? lat;
  final double? lng;

  final String creadoPor;
  final DateTime? creadoEn;

  Evento({
    required this.id,
    required this.nombre,
    required this.tipo,
    required this.fechaInicio,
    required this.fechaFin,
    required this.estado,
    required this.rolesRequeridos,
    required this.cantidadRequeridaTrabajadores,
    required this.ciudad,
    required this.direccion,
    required this.creadoPor,
    this.creadoEn,
    this.lat,
    this.lng,
  });

  factory Evento.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};

    final tsInicio = data['fechaInicio'] as Timestamp?;
    final tsFin = data['fechaFin'] as Timestamp?;
    final tsCreadoEn = data['creadoEn'] as Timestamp?;

    // roles
    final rolesDynamic = data['rolesRequeridos'];
    final roles = <String, int>{};
    if (rolesDynamic is Map) {
      rolesDynamic.forEach((k, v) {
        if (v is num) roles[k.toString()] = v.toInt();
      });
    }

    // cantidad
    final rawCantidad = data['cantidadRequeridaTrabajadores'];
    int cantidad = rawCantidad is num ? rawCantidad.toInt() : 0;
    if (cantidad == 0 && roles.isNotEmpty) {
      cantidad = roles.values.fold<int>(0, (s, v) => s + v);
    }

    // ubicación
    String ciudad = '';
    String direccion = '';
    double? lat;
    double? lng;

    final ubicacion = data['ubicacion'];
    if (ubicacion is Map) {
      final ciudadRaw = ubicacion['Ciudad'] ?? ubicacion['ciudad'];
      final direccionRaw = ubicacion['Dirección'] ?? ubicacion['direccion'];

      if (ciudadRaw is String) ciudad = ciudadRaw;
      if (direccionRaw is String) direccion = direccionRaw;

      final latRaw = ubicacion['lat'];
      final lngRaw = ubicacion['lng'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();
    }

    // compat (por si guardaste "location")
    final location = data['location'];
    if ((lat == null || lng == null) && location is Map) {
      final latRaw = location['lat'];
      final lngRaw = location['lng'];
      if (latRaw is num) lat = latRaw.toDouble();
      if (lngRaw is num) lng = lngRaw.toDouble();
    }

    return Evento(
      id: doc.id,
      nombre: data['nombre'] as String? ?? '',
      tipo: data['tipo'] as String? ?? '',
      fechaInicio: tsInicio?.toDate() ?? DateTime.now(),
      fechaFin: tsFin?.toDate() ?? DateTime.now(),
      estado: data['estado'] as String? ?? 'activo',
      rolesRequeridos: roles,
      cantidadRequeridaTrabajadores: cantidad,
      ciudad: ciudad,
      direccion: direccion,
      lat: lat,
      lng: lng,
      creadoPor: data['creadoPor'] as String? ?? '',
      creadoEn: tsCreadoEn?.toDate(),
    );
  }

  get ubicacionNombre => null;

  Map<String, dynamic> toMap() {
    final total = rolesRequeridos.values.fold<int>(0, (s, v) => s + v);

    return {
      'nombre': nombre,
      'tipo': tipo,
      'fechaInicio': Timestamp.fromDate(fechaInicio),
      'fechaFin': Timestamp.fromDate(fechaFin),
      'estado': estado,
      'rolesRequeridos': rolesRequeridos,
      'cantidadRequeridaTrabajadores': total,
      'ubicacion': {
        'Ciudad': ciudad,
        'Dirección': direccion,
        'lat': lat,
        'lng': lng,
      },
      'creadoPor': creadoPor,
      'creadoEn': creadoEn != null ? Timestamp.fromDate(creadoEn!) : null,
    };
  }
}
