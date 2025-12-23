import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacePrediction {
  final String description;
  final String placeId;
  PlacePrediction({required this.description, required this.placeId});
}

class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;
  final String? city;

  PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    this.city,
  });
}

class GooglePlacesService {
  GooglePlacesService._();

  // 👉 Pon esta key con --dart-define=GOOGLE_PLACES_API_KEY=XXXX
  static const String apiKey = String.fromEnvironment('GOOGLE_PLACES_API_KEY');

  static Future<List<PlacePrediction>> autocomplete({
    required String input,
    String language = 'es',
    String components = 'country:es',
    String? sessionToken,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('Falta GOOGLE_PLACES_API_KEY (dart-define).');
    }
    if (input.trim().length < 3) return [];

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/autocomplete/json'
      '?input=${Uri.encodeComponent(input)}'
      '&language=$language'
      '&components=$components'
      '${sessionToken != null ? '&sessiontoken=$sessionToken' : ''}'
      '&key=$apiKey',
    );

    final res = await http.get(uri);
    final data = json.decode(res.body) as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception('Autocomplete status=$status');
    }

    final preds = (data['predictions'] as List? ?? []);
    return preds.map((p) {
      return PlacePrediction(
        description: (p['description'] ?? '').toString(),
        placeId: (p['place_id'] ?? '').toString(),
      );
    }).where((p) => p.placeId.isNotEmpty).toList();
  }

  static Future<PlaceDetails> details({
    required String placeId,
    String language = 'es',
    String? sessionToken,
  }) async {
    if (apiKey.isEmpty) {
      throw Exception('Falta GOOGLE_PLACES_API_KEY (dart-define).');
    }

    final uri = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
      '?place_id=${Uri.encodeComponent(placeId)}'
      '&fields=geometry/location,formatted_address,address_component'
      '&language=$language'
      '${sessionToken != null ? '&sessiontoken=$sessionToken' : ''}'
      '&key=$apiKey',
    );

    final res = await http.get(uri);
    final data = json.decode(res.body) as Map<String, dynamic>;
    final status = (data['status'] ?? '').toString();
    if (status != 'OK') {
      throw Exception('Details status=$status');
    }

    final result = data['result'] as Map<String, dynamic>;
    final loc = (result['geometry']?['location'] ?? {}) as Map<String, dynamic>;

    final lat = (loc['lat'] as num).toDouble();
    final lng = (loc['lng'] as num).toDouble();
    final formatted = (result['formatted_address'] ?? '').toString();

    String? city;
    final comps = (result['address_components'] as List? ?? []);
    for (final c in comps) {
      final types = (c['types'] as List? ?? []).cast<String>();
      if (types.contains('locality')) {
        city = (c['long_name'] ?? '').toString();
        break;
      }
    }

    return PlaceDetails(
      formattedAddress: formatted,
      lat: lat,
      lng: lng,
      city: city,
    );
  }
}
