// lib/core/services/functions_service.dart
import 'package:cloud_functions/cloud_functions.dart';

class FunctionsService {
  final FirebaseFunctions _fx = FirebaseFunctions.instance;

  Future<bool> validateLicense(String licenseKey) async {
    final callable = _fx.httpsCallable('validateLicense');
    final res = await callable.call({'licenseKey': licenseKey});
    return res.data == true;
  }

  Future<bool> consumeLicense(String licenseKey) async {
    final callable = _fx.httpsCallable('consumeLicense');
    final res = await callable.call({'licenseKey': licenseKey});
    final data = res.data;
    if (data is Map && data['ok'] == true) return true;
    return false;
  }

  // ⬇️ NUEVO: auto-assign
  Future<Map<String, dynamic>> autoAssignWorkers(String eventId) async {
    final callable = _fx.httpsCallable('autoAssignWorkers');
    final res = await callable.call({'eventId': eventId});
    // res.data => { assigned: number, workers: [...] }
    return Map<String, dynamic>.from(res.data as Map);
  }

  // opcional: recordatorios
  Future<bool> scheduleReminder(String eventId, int hoursBefore) async {
    final callable = _fx.httpsCallable('scheduleReminder');
    final res = await callable.call({
      'eventId': eventId,
      'hoursBefore': hoursBefore,
    });
    final data = res.data;
    if (data is Map && data['success'] == true) return true;
    if (data == true) return true; // por si devolviste boolean en otra versión
    return false;
  }
}
