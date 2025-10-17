import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../core/services/firestore_service.dart';
import '../models/event_model.dart';

class EventProvider with ChangeNotifier {
  EventProvider({
    required FirebaseFirestore db,
    required String companyId,
  }) : _fs = FirestoreService(db, companyId: companyId) {
    _subscribe();
  }

  final FirestoreService _fs;

  List<EventModel> _events = [];
  StreamSubscription<List<EventModel>>? _sub;

  DateTime? _from, _to;

  List<EventModel> get events => _events;
  DateTime? get from => _from;
  DateTime? get to => _to;

  set from(DateTime? v) {
    _from = v;
    _resubscribe();
  }

  set to(DateTime? v) {
    _to = v;
    _resubscribe();
  }

  void _subscribe() {
    _sub?.cancel();
    _sub = _fs.streamEvents(from: _from, to: _to).listen((list) {
      _events = list;
      notifyListeners();
    });
  }

  void _resubscribe() => _subscribe();

  Future<String> create(EventModel e) => _fs.createEvent(e);

  Future<void> update(EventModel e) => _fs.updateEvent(e);

  Future<void> delete(String eventId) => _fs.deleteEvent(eventId);

  /// Helpers de negocio
  Future<void> markPaid(String eventId, String uid, bool paid) async {
    // Carga actual, modifica pago[uid] y guarda (simplificado)
    final current = _events.firstWhere((e) => e.id == eventId);
    final newPago = Map<String, bool>.from(current.pago);
    newPago[uid] = paid;
    await _fs.updateEvent(current.copyWith(pago: newPago));
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }
}
