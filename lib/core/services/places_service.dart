import 'dart:convert';
import 'package:http/http.dart' as http;

class PlaceSuggestion {
  final String description;
  final String placeId;
  PlaceSuggestion({required this.description, required this.placeId});
}

class PlaceDetails {
  final String formattedAddress;
  final double lat;
  final double lng;
  PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
  });
}

class PlacesService {
  final String apiKey;
  PlacesService(this.apiKey);

  Future<List<PlaceSuggestion>> autocomplete({
    required String input,
    required String sessionToken,
    String language = 'es',
    String? countryCode, // 'es' para España
  }) async {
    if (apiKey.trim().isEmpty) return [];
    if (input.trim().isEmpty) return [];

    final params = <String, String>{
      'input': input,
      'key': apiKey,
      'sessiontoken': sessionToken,
      'language': language,
    };

    if (countryCode != null && countryCode.isNotEmpty) {
      params['components'] = 'country:$countryCode';
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/autocomplete/json',
      params,
    );

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    final status = (data['status'] as String?) ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      throw Exception(
        'Places autocomplete error: $status ${data['error_message'] ?? ''}',
      );
    }

    final preds = (data['predictions'] as List? ?? const []);
    return preds.map((p) {
      return PlaceSuggestion(
        description: (p['description'] ?? '') as String,
        placeId: (p['place_id'] ?? '') as String,
      );
    }).toList();
  }

  Future<PlaceDetails> details({
    required String placeId,
    required String sessionToken,
    String language = 'es',
  }) async {
    if (apiKey.trim().isEmpty) {
      throw Exception('GOOGLE_PLACES_API_KEY no configurada');
    }

    final uri = Uri.https(
      'maps.googleapis.com',
      '/maps/api/place/details/json',
      {
        'place_id': placeId,
        'key': apiKey,
        'sessiontoken': sessionToken,
        'language': language,
        'fields': 'formatted_address,geometry',
      },
    );

    final res = await http.get(uri);
    final data = jsonDecode(res.body);

    final status = (data['status'] as String?) ?? '';
    if (status != 'OK') {
      throw Exception(
        'Places details error: $status ${data['error_message'] ?? ''}',
      );
    }

    final result = data['result'] ?? {};
    final loc = result['geometry']?['location'] ?? {};
    return PlaceDetails(
      formattedAddress: (result['formatted_address'] ?? '') as String,
      lat: (loc['lat'] as num).toDouble(),
      lng: (loc['lng'] as num).toDouble(),
    );
  }
}
