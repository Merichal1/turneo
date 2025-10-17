// lib/core/utils/dev_seed.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/firestore_service.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';

Future<void> seedDevData({
  required String companyId, // p.ej. 'acme'
  String companyName = 'Mi Empresa',
}) async {
  final db = FirebaseFirestore.instance;
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) {
    throw 'No hay usuario autenticado. Inicia sesión antes de sembrar.';
  }

  final fs = FirestoreService(db, companyId: companyId);

  // 1) Empresa
  await fs.upsertCompany(name: companyName);

  // 2) Admin (el usuario actual)
  final admin = UserModel(
    id: uid,
    displayName: 'Admin',
    email: FirebaseAuth.instance.currentUser!.email ?? 'admin@$companyId.com',
    jobRole: 'admin',
    city: 'Sevilla',
    hasCar: true,
    isActive: true,
    experienceYears: 10,
    age: 30,
  );
  await fs.upsertUser(admin);

  // 3) Workers demo
  final worker1 = UserModel(
    id: 'worker1@demo.com',
    displayName: 'Worker Uno',
    email: 'worker1@demo.com',
    jobRole: 'Camarero',
    city: 'Sevilla',
    hasCar: true,
    isActive: true,
    experienceYears: 2,
    age: 24,
  );
  final worker2 = UserModel(
    id: 'worker2@demo.com',
    displayName: 'Worker Dos',
    email: 'worker2@demo.com',
    jobRole: 'Cocinero',
    city: 'Cádiz',
    hasCar: false,
    isActive: true,
    experienceYears: 4,
    age: 28,
  );
  await fs.upsertUser(worker1);
  await fs.upsertUser(worker2);

  // 4) Eventos demo
  final eventA = EventModel(
    id: 'auto',
    name: 'Boda María & Juan',
    date: DateTime.now().add(const Duration(days: 7)),
    type: 'Boda',
    status: EventStatus.activo,
    address: 'Hacienda El Rosal',
    requiredRoles: {'Camarero': 3, 'Cocinero': 1},
    assignedWorkers: [worker1.id],
    pago: {worker1.id: false},
  );
  final eventB = EventModel(
    id: 'auto',
    name: 'Congreso Salud',
    date: DateTime.now().add(const Duration(days: 15)),
    type: 'Congreso',
    status: EventStatus.activo,
    address: 'Fibes',
    requiredRoles: {'Camarero': 2},
  );

  final eventAId = await fs.createEvent(eventA);
  final eventBId = await fs.createEvent(eventB);

  // 5) Payment demo
  await fs.addPayment(
    eventId: eventAId,
    uid: worker1.id,
    amount: 120.0,
    paid: false,
  );

  // 6) Notificación demo
  await fs.addNotification(
    title: 'Nueva disponibilidad',
    body: '¿Disponible para ${eventB.name}?',
    to: 'worker',
    eventId: eventBId,
  );
}
