import 'dart:async';
import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';
import '../core/services/places_service.dart';

class PlaceSelection {
  final String placeId;
  final String addressText;
  final double? lat;
  final double? lng;
  final String? city;

  const PlaceSelection({
    required this.placeId,
    required this.addressText,
    required this.lat,
    required this.lng,
    required this.city,
  });
}

class PlaceAutocompleteField extends StatefulWidget {
  final TextEditingController controller;
  final ValueChanged<PlaceSelection> onPlaceSelected;

  final String labelText;
  final String hintText;

  const PlaceAutocompleteField({
    super.key,
    required this.controller,
    required this.onPlaceSelected,
    this.labelText = 'Dirección (Google)',
    this.hintText = 'Escribe y elige una sugerencia…',
  });

  @override
  State<PlaceAutocompleteField> createState() => _PlaceAutocompleteFieldState();
}

class _PlaceAutocompleteFieldState extends State<PlaceAutocompleteField> {
  final PlacesService _svc = PlacesService();
  final FocusNode _focus = FocusNode();

  Timer? _debounce;
  bool _loading = false;
  String? _error;
  List<PlacePrediction> _preds = [];

  String _sessionToken = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onTextChanged);
    _focus.addListener(() {
      if (!_focus.hasFocus && mounted) setState(() => _preds = []);
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
      final items = await _svc.autocomplete(input: q, sessionToken: _sessionToken);
      if (!mounted) return;
      setState(() => _preds = items);
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

  Future<void> _pick(PlacePrediction p) async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final det = await _svc.details(placeId: p.placeId, sessionToken: _sessionToken);

      final addr = (det.formattedAddress ?? p.description).trim();

      widget.controller.text = addr;

      if (!mounted) return;
      setState(() => _preds = []);
      _focus.unfocus();

      // nuevo token para la siguiente sesión
      _sessionToken = const Uuid().v4();

      widget.onPlaceSelected(PlaceSelection(
        placeId: p.placeId,
        addressText: addr,
        lat: det.lat,
        lng: det.lng,
        city: det.city,
      ));
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
                    child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : const Icon(Icons.place_outlined),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(_error!, style: const TextStyle(color: Colors.red, fontSize: 12)),
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
                BoxShadow(blurRadius: 10, offset: const Offset(0, 6), color: Colors.black.withOpacity(0.06)),
              ],
            ),
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _preds.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade200),
              itemBuilder: (context, i) {
                final p = _preds[i];
                return ListTile(
                  dense: true,
                  leading: const Icon(Icons.location_on_outlined),
                  title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  onTap: () => _pick(p),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}
