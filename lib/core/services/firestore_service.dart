import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/user_model.dart';
import '../../models/event_model.dart';

class FirestoreService {
  FirestoreService(this._db, {required this.companyId});
  final FirebaseFirestore _db;
  final String companyId;

  // ✅ CollectionReference (tiene .doc())
  CollectionReference<Map<String, dynamic>> get _usersCol =>
      _db.collection('companies/$companyId/users');

  CollectionReference<Map<String, dynamic>> get _eventsCol =>
      _db.collection('companies/$companyId/events');

  CollectionReference<Map<String, dynamic>> get _paymentsCol =>
      _db.collection('companies/$companyId/payments');

  CollectionReference<Map<String, dynamic>> get _notifsCol =>
      _db.collection('companies/$companyId/notifications');

  // ---------- USERS ----------
  Stream<List<UserModel>> streamUsers({String? name, String? city, String? jobRole}) {
    Query<Map<String, dynamic>> q = _usersCol; // ← aquí usamos Query
    if (name != null && name.isNotEmpty) {
      q = q.orderBy('displayName').startAt([name]).endAt(['$name\uf8ff']);
    } else {
      q = q.orderBy('displayName');
    }
    if (city != null && city.isNotEmpty) q = q.where('city', isEqualTo: city);
    if (jobRole != null && jobRole.isNotEmpty) q = q.where('jobRole', isEqualTo: jobRole);

    return q.snapshots().map((s) =>
        s.docs.map((d) => UserModel.fromMap(d.id, d.data())).toList());
  }

  Future<void> upsertUser(UserModel u) async {
    await _usersCol.doc(u.id).set(u.toMap(), SetOptions(merge: true)); // ✅ .doc()
  }

  // ---------- EVENTS ----------
  Stream<List<EventModel>> streamEvents({DateTime? from, DateTime? to}) {
    Query<Map<String, dynamic>> q = _eventsCol; // ← Query para filtros
    if (from != null) {
      q = q.where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from));
    }
    if (to != null) {
      q = q.where('date', isLessThanOrEqualTo: Timestamp.fromDate(to));
    }
    q = q.orderBy('date');

    return q.snapshots().map((s) =>
        s.docs.map((d) => EventModel.fromMap(d.id, d.data())).toList());
  }

  Future<String> createEvent(EventModel e) async {
    final ref = _eventsCol.doc();          // ✅ CollectionReference -> .doc()
    await ref.set(e.toMap());
    return ref.id;
  }

  Future<void> updateEvent(EventModel e) async {
    await _eventsCol.doc(e.id).set(e.toMap(), SetOptions(merge: true)); // ✅
  }

  Future<void> deleteEvent(String eventId) async {
    await _eventsCol.doc(eventId).delete(); // ✅
  }

  // ---------- PAYMENTS ----------
  Future<String> addPayment({
    required String eventId,
    required String uid,
    required double amount,
    required bool paid,
  }) async {
    final ref = _paymentsCol.doc(); // ✅
    await ref.set({
      'eventId': eventId,
      'uid': uid,
      'amount': amount,
      'paid': paid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return ref.id;
  }

  // ---------- NOTIFICATIONS ----------
  Future<String> addNotification({
    required String title,
    required String body,
    String to = 'all',
    String? eventId,
  }) async {
    final ref = _notifsCol.doc(); // ✅
    await ref.set({
      'title': title,
      'body': body,
      'to': to,
      'eventRef': eventId != null ? _eventsCol.doc(eventId).path : null,
      'createdAt': FieldValue.serverTimestamp(),
      'delivery': {'push': true, 'email': false, 'sms': false},
    });
    return ref.id;
  }

    // ---------- COMPANY ----------
  /// Crea o actualiza la información de la empresa (companies/{companyId})
  Future<void> upsertCompany({required String name}) async {
    final ref = _db.doc('companies/$companyId');
    await ref.set({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

}
