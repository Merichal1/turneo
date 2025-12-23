import 'dart:convert';
import 'package:http/http.dart' as http;

class PlacesService {
  final String apiKey;
  PlacesService(this.apiKey);

  Future<List<PlacePrediction>> autocomplete(
    String input, {
    String language = 'es',
    String countryCode = 'es',
  }) async {
    final text = input.trim();
    if (text.isEmpty) return [];

    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': text,
      'key': apiKey,
      'language': language,
      'components': 'country:$countryCode',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Places Autocomplete HTTP ${res.statusCode}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final status = (body['status'] ?? '').toString();

    if (status == 'ZERO_RESULTS') return [];
    if (status != 'OK') {
      final msg = (body['error_message'] ?? 'Places Autocomplete error').toString();
      throw Exception('Places Autocomplete status=$status msg=$msg');
    }

    final preds = (body['predictions'] as List).cast<Map<String, dynamic>>();
    return preds.map((p) {
      return PlacePrediction(
        placeId: (p['place_id'] ?? '').toString(),
        description: (p['description'] ?? '').toString(),
      );
    }).where((p) => p.placeId.isNotEmpty).toList();
  }

  Future<PlaceDetails> details(
    String placeId, {
    String language = 'es',
  }) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'key': apiKey,
      'language': language,
      'fields': 'geometry,formatted_address,address_component',
    });

    final res = await http.get(uri);
    if (res.statusCode != 200) {
      throw Exception('Places Details HTTP ${res.statusCode}');
    }

    final body = json.decode(res.body) as Map<String, dynamic>;
    final status = (body['status'] ?? '').toString();

    if (status != 'OK') {
      final msg = (body['error_message'] ?? 'Places Details error').toString();
      throw Exception('Places Details status=$status msg=$msg');
    }

    final result = (body['result'] as Map<String, dynamic>);
    final formatted = (result['formatted_address'] ?? '').toString();

    final loc = result['geometry']?['location'];
    final lat = (loc?['lat'] as num).toDouble();
    final lng = (loc?['lng'] as num).toDouble();

    final comps = (result['address_components'] as List?) ?? const [];
    final city = _extractCity(comps);

    return PlaceDetails(
      formattedAddress: formatted.isEmpty ? null : formatted,
      lat: lat,
      lng: lng,
      city: city,
    );
  }

  String? _extractCity(List comps) {
    // Busca "locality" primero; si no, intenta otras opciones.
    String? findType(String type) {
      for (final c in comps) {
        final m = c as Map<String, dynamic>;
        final types = (m['types'] as List?)?.map((e) => e.toString()).toList() ?? const [];
        if (types.contains(type)) return (m['long_name'] ?? '').toString();
      }
      return null;
    }

    final locality = findType('locality');
    if (locality != null && locality.isNotEmpty) return locality;

    final postalTown = findType('postal_town');
    if (postalTown != null && postalTown.isNotEmpty) return postalTown;

    final admin2 = findType('administrative_area_level_2');
    if (admin2 != null && admin2.isNotEmpty) return admin2;

    final admin1 = findType('administrative_area_level_1');
    if (admin1 != null && admin1.isNotEmpty) return admin1;

    return null;
  }
}

class PlacePrediction {
  final String placeId;
  final String description;
  PlacePrediction({required this.placeId, required this.description});
}

class PlaceDetails {
  final String? formattedAddress;
  final double lat;
  final double lng;
  final String? city;

  PlaceDetails({
    required this.formattedAddress,
    required this.lat,
    required this.lng,
    required this.city,
  });
}

class PlaceSelection {
  final String placeId;
  final String description;
  final String addressText;
  final double lat;
  final double lng;
  final String? city;

  PlaceSelection({
    required this.placeId,
    required this.description,
    required this.addressText,
    required this.lat,
    required this.lng,
    required this.city,
  });
}
