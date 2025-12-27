import 'package:cloud_functions/cloud_functions.dart';

class PlacesService {
  final FirebaseFunctions _functions;

  PlacesService({FirebaseFunctions? functions})
      : _functions =
            functions ?? FirebaseFunctions.instanceFor(region: 'us-central1');

  Future<List<PlacePrediction>> autocomplete({
    required String input,
    required String sessionToken,
  }) async {
    final callable = _functions.httpsCallable('placesAutocomplete');
    final res = await callable.call({
      'input': input,
      'sessionToken': sessionToken,
    });

    final data = res.data as Map;
    final list = (data['predictions'] as List? ?? []);

    return list
        .map((e) => PlacePrediction(
              placeId: (e['placeId'] ?? '').toString(),
              description: (e['description'] ?? '').toString(),
            ))
        .where((p) => p.placeId.isNotEmpty && p.description.isNotEmpty)
        .toList();
  }

  Future<PlaceDetails> details({
    required String placeId,
    required String sessionToken,
  }) async {
    final callable = _functions.httpsCallable('placesDetails'); // ✅ plural
    final res = await callable.call({
      'placeId': placeId,
      'sessionToken': sessionToken,
    });

    final d = res.data as Map;
    return PlaceDetails(
      formattedAddress: d['formattedAddress']?.toString(),
      lat: (d['lat'] is num) ? (d['lat'] as num).toDouble() : null,
      lng: (d['lng'] is num) ? (d['lng'] as num).toDouble() : null,
      city: d['city']?.toString(),
    );
  }

  Future<GeocodeResult> geocodeAddress({required String address}) async {
    final callable = _functions.httpsCallable('geocodeAddress');
    final res = await callable.call({'address': address});

    final d = res.data as Map;
    return GeocodeResult(
      formattedAddress: d['formattedAddress']?.toString(),
      lat: (d['lat'] as num).toDouble(),
      lng: (d['lng'] as num).toDouble(),
    );
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  PlacePrediction({required this.placeId, required this.description});
}

class PlaceDetails {
  final String? formattedAddress;
  final double? lat;
  final double? lng;
  final String? city;

  PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.city,
  });
}

class GeocodeResult {
  final String? formattedAddress;
  final double lat;
  final double lng;

  GeocodeResult({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}
