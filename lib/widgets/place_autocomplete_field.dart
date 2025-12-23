import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../core/services/places_service.dart';

class PlaceAutocompleteField extends StatefulWidget {
  final String apiKey;
  final TextEditingController controller;

  final String labelText;
  final String hintText;

  final ValueChanged<PlaceSelection> onPlaceSelected;

  const PlaceAutocompleteField({
    super.key,
    required this.apiKey,
    required this.controller,
    required this.onPlaceSelected,
    this.labelText = 'Dirección (Google)',
    this.hintText = 'Escribe y elige una sugerencia…',
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  late final PlacesService _svc;

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<PlacePredictionLite> _preds = [];

  final FocusNode _focus = FocusNode();
  String _sessionToken = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _svc = PlacesService(widget.apiKey);

    widget.controller.addListener(_onTextChanged);
    _focus.addListener(() {
      if (!_focus.hasFocus) {
        if (!mounted) return;
        setState(() => _preds = []);
      }
    });
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    _debounce?.cancel();
    _focus.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final text = widget.controller.text;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), () => _search(text));
  }

  Future<void> _search(String text) async {
    if (!mounted) return;

    if (widget.apiKey.isEmpty) {
      setState(() {
        _error = 'Falta GOOGLE_PLACES_API_KEY (dart-define).';
        _preds = [];
      });
      return;
    }

    final q = text.trim();
    if (q.length < 3) {
      setState(() {
        _error = null;
        _preds = [];
      });
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ TU SERVICIO EXIGE sessionToken
      final items = await _svc.autocomplete(
        input: q,
        sessionToken: _sessionToken,
      );

      // ✅ No asumimos tipos: convertimos a nuestro modelo lite
      final mapped = <PlacePredictionLite>[];
      for (final it in items) {
        final placeId = _readString(it, ['placeId', 'place_id', 'id']);
        final desc = _readString(it, ['description', 'desc', 'text']);
        if (placeId != null && desc != null) {
          mapped.add(PlacePredictionLite(placeId: placeId, description: desc));
        }
      }

      if (!mounted) return;
      setState(() => _preds = mapped);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'No pude buscar sugerencias.';
        _preds = [];
      });
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _pick(PlacePredictionLite p) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // ✅ TU SERVICIO EXIGE sessionToken
      final det = await _svc.details(
        placeId: p.placeId,
        sessionToken: _sessionToken,
      );

      final addr =
          (_readString(det, ['formattedAddress', 'formatted_address', 'address']) ??
                  p.description)
              .trim();

      final lat = _readDouble(det, ['lat']) ??
          _readNestedDouble(det, [
            ['geometry', 'location', 'lat'],
            ['location', 'lat'],
          ]);

      final lng = _readDouble(det, ['lng']) ??
          _readNestedDouble(det, [
            ['geometry', 'location', 'lng'],
            ['location', 'lng'],
          ]);

      final city = _readString(det, ['city', 'locality']);

      final sel = PlaceSelection(
        placeId: p.placeId,
        description: p.description,
        addressText: addr,
        lat: lat,
        lng: lng,
        city: city,
      );

      widget.controller.text = addr;

      if (!mounted) return;
      setState(() => _preds = []);
      _focus.unfocus();

      // ✅ nuevo token para la próxima “sesión” (recomendación Places)
      _sessionToken = const Uuid().v4();

      widget.onPlaceSelected(sel);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = 'No pude obtener coordenadas de esa selección.');
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TextField(
          controller: widget.controller,
          focusNode: _focus,
          decoration: InputDecoration(
            labelText: widget.labelText,
            hintText: widget.hintText,
            border: const OutlineInputBorder(),
            suffixIcon: _loading
                ? const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                : const Icon(Icons.place_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          ),
        ],
        if (_preds.isNotEmpty) ...[
          const SizedBox(height: 6),
          Container(
            constraints: const BoxConstraints(maxHeight: 220),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  blurRadius: 10,
                  offset: const Offset(0, 6),
                  color: Colors.black.withOpacity(0.06),
                ),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _preds.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final p = _preds[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(
                    p.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: () => _pick(p),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  // =========================
  // Helpers para leer dinámico
  // =========================

  String? _readString(dynamic obj, List<String> keys) {
    if (obj == null) return null;

    // Map
    if (obj is Map) {
      for (final k in keys) {
        final v = obj[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return null;
    }

    // Objeto con propiedades
    for (final k in keys) {
      try {
        final v = (obj as dynamic).__getattr__(k);
        if (v is String && v.trim().isNotEmpty) return v;
      } catch (_) {
        try {
          final v = (obj as dynamic).toJson?.call();
          if (v is Map) {
            final vv = v[k];
            if (vv is String && vv.trim().isNotEmpty) return vv;
          }
        } catch (_) {}
      }
    }

    // Intento directo común (description / placeId)
    for (final k in keys) {
      try {
        final v = (obj as dynamic);
        final val = _dynamicGet(v, k);
        if (val is String && val.trim().isNotEmpty) return val;
      } catch (_) {}
    }
    return null;
  }

  double? _readDouble(dynamic obj, List<String> keys) {
    if (obj == null) return null;

    if (obj is Map) {
      for (final k in keys) {
        final v = obj[k];
        if (v is num) return v.toDouble();
      }
      return null;
    }

    for (final k in keys) {
      try {
        final val = _dynamicGet(obj as dynamic, k);
        if (val is num) return val.toDouble();
      } catch (_) {}
    }
    return null;
  }

  double? _readNestedDouble(dynamic obj, List<List<String>> paths) {
    if (obj == null) return null;

    for (final path in paths) {
      dynamic cur = obj;
      bool ok = true;

      for (final key in path) {
        if (cur is Map) {
          cur = cur[key];
        } else {
          try {
            cur = _dynamicGet(cur as dynamic, key);
          } catch (_) {
            ok = false;
            break;
          }
        }
        if (cur == null) {
          ok = false;
          break;
        }
      }

      if (ok && cur is num) return cur.toDouble();
    }

    return null;
  }

  dynamic _dynamicGet(dynamic obj, String key) {
    // acceso típico a getters en objetos “model”
    try {
      // ignore: avoid_dynamic_calls
      return obj.toJson != null ? obj.toJson()[key] : obj;
    } catch (_) {}

    // ignore: avoid_dynamic_calls
    return (obj as dynamic).$key;
  }
}

@immutable
class PlacePredictionLite {
  final String placeId;
  final String description;

  const PlacePredictionLite({
    required this.placeId,
    required this.description,
  });
}

@immutable
class PlaceSelection {
  final String placeId;
  final String description;
  final String addressText;
  final double? lat;
  final double? lng;
  final String? city;

  const PlaceSelection({
    required this.placeId,
    required this.description,
    required this.addressText,
    this.lat,
    this.lng,
    this.city,
  });
}
