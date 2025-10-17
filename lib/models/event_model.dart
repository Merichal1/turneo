import 'package:cloud_firestore/cloud_firestore.dart';

/// Estados posibles del evento
enum EventStatus { activo, cancelado, finalizado }

class EventModel {
  final String id;
  final String name;
  final DateTime date;
  final String type; // General, Concierto, Congreso...
  final EventStatus status;
  final String address;
  final double? lat;
  final double? lng;
  final Map<String, int> requiredRoles; // puesto -> cantidad
  final List<String> assignedWorkers; // uids
  final Map<String, bool> pago; // uid -> pagado

  const EventModel({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    required this.status,
    this.address = '',
    this.lat,
    this.lng,
    this.requiredRoles = const {},
    this.assignedWorkers = const [],
    this.pago = const {},
  });

  // === SERIALIZACIÓN ===
  Map<String, dynamic> toMap() => {
        'name': name,
        'date': Timestamp.fromDate(date),
        'type': type,
        'status': status.name,
        'location': {'address': address, 'lat': lat, 'lng': lng},
        'required': requiredRoles,
        'assignedWorkers': assignedWorkers,
        'pago': pago,
      };

  /// Constructor desde Map (Firestore → modelo)
  factory EventModel.fromMap(String id, Map<String, dynamic> m) {
    final loc = (m['location'] as Map?) ?? const {};
    final req = (m['required'] as Map?) ?? const {};

    // Estado seguro
    final statusStr = (m['status'] as String?)?.toLowerCase() ?? 'activo';
    final safeStatus = EventStatus.values.firstWhere(
      (e) => e.name == statusStr,
      orElse: () => EventStatus.activo,
    );

    // Fecha segura
    final rawDate = m['date'];
    final safeDate = (rawDate is Timestamp)
        ? rawDate.toDate()
        : (rawDate is DateTime)
            ? rawDate
            : DateTime.now();

    return EventModel(
      id: id,
      name: (m['name'] ?? '') as String,
      date: safeDate,
      type: (m['type'] ?? 'General') as String,
      status: safeStatus,
      address: (loc['address'] ?? '') as String,
      lat: (loc['lat'] as num?)?.toDouble(),
      lng: (loc['lng'] as num?)?.toDouble(),
      requiredRoles: Map<String, int>.from(req),
      assignedWorkers:
          (m['assignedWorkers'] as List?)?.cast<String>() ?? const [],
      pago: Map<String, dynamic>.from(m['pago'] ?? const {})
          .map((k, v) => MapEntry(k, v == true)),
    );
  }

  /// Carga desde snapshot Firestore
  factory EventModel.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      EventModel.fromMap(doc.id, doc.data() ?? const {});

  /// ✅ Nuevo método: crear una copia modificando solo ciertos campos
  EventModel copyWith({
    String? id,
    String? name,
    DateTime? date,
    String? type,
    EventStatus? status,
    String? address,
    double? lat,
    double? lng,
    Map<String, int>? requiredRoles,
    List<String>? assignedWorkers,
    Map<String, bool>? pago,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      status: status ?? this.status,
      address: address ?? this.address,
      lat: lat ?? this.lat,
      lng: lng ?? this.lng,
      requiredRoles: requiredRoles ?? this.requiredRoles,
      assignedWorkers: assignedWorkers ?? this.assignedWorkers,
      pago: pago ?? this.pago,
    );
  }
}
