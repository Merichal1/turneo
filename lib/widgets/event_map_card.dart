import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../config/app_config.dart';
import '../models/evento.dart';
import '../core/services/places_service.dart';

class EventMapCard extends StatefulWidget {
  final Evento evento;
  const EventMapCard({super.key, required this.evento});

  @override
  State<EventMapCard> createState() => _EventMapCardState();
}

class _EventMapCardState extends State<EventMapCard> {
  LatLng? _pos;
  bool _loading = false;
  String? _error;

  String get _address {
    final parts = <String>[];
    if (widget.evento.direccion.trim().isNotEmpty) parts.add(widget.evento.direccion.trim());
    if (widget.evento.ciudad.trim().isNotEmpty) parts.add(widget.evento.ciudad.trim());
    return parts.join(', ');
  }

  @override
  void initState() {
    super.initState();

    // 1) si ya hay coords
    if (widget.evento.lat != null && widget.evento.lng != null) {
      _pos = LatLng(widget.evento.lat!, widget.evento.lng!);
      return;
    }

    // 2) si no hay coords, geocode y cache
    _tryGeocodeAndCache();
  }

  Future<void> _tryGeocodeAndCache() async {
    final addr = _address;
    if (addr.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final geo = await PlacesService().geocodeAddress(address: addr);
      final pos = LatLng(geo.lat, geo.lng);

      // cache Firestore para no recalcular
      if (widget.evento.id.isNotEmpty) {
        await FirebaseFirestore.instance
            .collection('empresas')
            .doc(AppConfig.empresaId)
            .collection('eventos')
            .doc(widget.evento.id)
            .set({
          'ubicacion': {'lat': geo.lat, 'lng': geo.lng},
        }, SetOptions(merge: true));
      }

      if (!mounted) return;
      setState(() => _pos = pos);
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = "No pude obtener coordenadas automáticamente.");
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _openInGoogleMaps() async {
    final addr = _address;

    final Uri uri;
    if (_pos != null) {
      uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${_pos!.latitude},${_pos!.longitude}",
      );
    } else if (addr.isNotEmpty) {
      uri = Uri.parse(
        "https://www.google.com/maps/search/?api=1&query=${Uri.encodeComponent(addr)}",
      );
    } else {
      return;
    }

    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final addr = _address;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            blurRadius: 18,
            offset: const Offset(0, 8),
            color: Colors.black.withOpacity(0.04),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Ubicación", style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            addr.isEmpty ? "—" : addr,
            style: const TextStyle(color: Color(0xFF6B7280)),
          ),
          const SizedBox(height: 12),

          if (_loading)
            const SizedBox(
              height: 160,
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_pos == null)
            SizedBox(
              height: 160,
              child: Center(
                child: Text(
                  _error ?? "Sin coordenadas todavía.",
                  style: const TextStyle(color: Colors.grey),
                  textAlign: TextAlign.center,
                ),
              ),
            )
          else
            SizedBox(
              height: 190,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: GoogleMap(
                  initialCameraPosition: CameraPosition(target: _pos!, zoom: 15),
                  markers: {
                    Marker(markerId: const MarkerId("evento"), position: _pos!),
                  },
                  zoomControlsEnabled: false,
                  myLocationButtonEnabled: false,
                ),
              ),
            ),

          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: _openInGoogleMaps,
              icon: const Icon(Icons.map_outlined),
              label: const Text("Abrir en Google Maps"),
            ),
          ),
        ],
      ),
    );
  }
}
