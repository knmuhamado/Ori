import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';
import '../models/campus_place.dart';

class GeoJsonService extends ChangeNotifier {
  static final GeoJsonService _instance = GeoJsonService._internal();
  factory GeoJsonService() => _instance;
  GeoJsonService._internal();

  List<CampusPlace> _all = [];
  List<CampusPlace> _filtered = [];
  bool _isLoaded = false;
  List<List<double>>? _campusPerimeter;

  List<CampusPlace> get places => _filtered;
  List<CampusPlace> get allPlaces => _all;
  bool get isLoaded => _isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/campus_eafit.geojson');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final features = json['features'] as List<dynamic>;

      final List<CampusPlace> loaded = [];
      final Set<String> seen = {};
      final Set<String> seenBanos = {};

      // Encontrar perímetro principal (el de más puntos)
      int maxPoints = 0;
      for (final f in features) {
        final name = (f['properties']['name'] ?? '') as String;
        if (name == 'Perímetro del campus') {
          final coords = _parseCoords(f['geometry']['coordinates'][0] as List);
          if (coords.length > maxPoints) {
            maxPoints = coords.length;
            _campusPerimeter = coords;
          }
        }
      }

      for (final f in features) {
        final props = f['properties'] as Map<String, dynamic>;
        final name = (props['name'] ?? '').toString().trim();
        final desc = (props['description'] ?? '').toString().trim();

        if (!_isRelevant(name)) continue;

        final coords = _parseCoords(f['geometry']['coordinates'][0] as List);
        double sumLat = 0, sumLng = 0;
        for (final c in coords) { sumLng += c[0]; sumLat += c[1]; }
        final lat = sumLat / coords.length;
        final lng = sumLng / coords.length;

        // Deduplicar por nombre+descripcion (primeros 30 chars)
        final descKey = desc.length > 30 ? desc.substring(0, 30) : desc;
        final key = '$name|$descKey';
        if (seen.contains(key)) continue;
        seen.add(key);

        final category = CampusPlace.categorize(name, desc);
        loaded.add(CampusPlace(
          name: name,
          description: desc.isEmpty ? name : desc,
          latitude: lat,
          longitude: lng,
          category: category,
          polygon: coords,
        ));

        // Generar baño si el lugar lo menciona
        final dl = desc.toLowerCase();
        if (dl.contains('baño') || dl.contains('baños')) {
          final bKey = 'bano|$name';
          if (!seenBanos.contains(bKey)) {
            seenBanos.add(bKey);
            loaded.add(CampusPlace(
              name: 'Baños - $name',
              description: 'Baños públicos en $name',
              latitude: lat,
              longitude: lng,
              category: PlaceCategory.bano,
              polygon: coords,
            ));
          }
        }
      }

      _all = loaded;
      _filtered = List.from(_all);
      _isLoaded = true;
      notifyListeners();

      final stats = <PlaceCategory, int>{};
      for (final p in _all) stats[p.category] = (stats[p.category] ?? 0) + 1;
      debugPrint('✅ GeoJSON: ${_all.length} lugares');
      stats.forEach((c, n) => debugPrint('   ${c.displayName}: $n'));
    } catch (e) {
      debugPrint('❌ GeoJSON error: $e');
    }
  }

  List<List<double>> _parseCoords(List raw) {
    return raw.map<List<double>>((c) =>
      [(c[0] as num).toDouble(), (c[1] as num).toDouble()]
    ).toList();
  }

  bool _isRelevant(String name) {
    final n = name.toLowerCase();
    if (n == 'perímetro del campus') return false;
    if (n.contains('acceso a casas')) return false;
    if (RegExp(r'^casa \d+$').hasMatch(n)) return false;
    if (n == 'casa graduados' || n == 'casa urbam' || n == 'casas 1 y 2') return false;
    return true;
  }

  bool isInsideCampus(double lat, double lng) {
    if (_campusPerimeter == null) {
      return lat >= 6.196 && lat <= 6.204 && lng >= -75.582 && lng <= -75.575;
    }
    return _pip(lat, lng, _campusPerimeter!);
  }

  CampusPlace? getPlaceContaining(double lat, double lng) {
    for (final p in _all) {
      if (p.polygon != null && _pip(lat, lng, p.polygon!)) return p;
    }
    return null;
  }

  bool _pip(double lat, double lng, List<List<double>> poly) {
    bool inside = false;
    int j = poly.length - 1;
    for (int i = 0; i < poly.length; i++) {
      final xi = poly[i][0], yi = poly[i][1];
      final xj = poly[j][0], yj = poly[j][1];
      if (((yi > lat) != (yj > lat)) && (lng < (xj-xi)*(lat-yi)/(yj-yi)+xi)) {
        inside = !inside;
      }
      j = i;
    }
    return inside;
  }

  void filterByCategory(PlaceCategory? category) {
    var result = List<CampusPlace>.from(_all);
    if (category != null) result = result.where((p) => p.category == category).toList();
    result.sort((a, b) => a.name.compareTo(b.name));
    _filtered = result;
    notifyListeners();
  }

  List<CampusPlace> getNearby(double lat, double lng, {int limit = 3}) {
    if (_all.isEmpty) return [];
    final sorted = List<CampusPlace>.from(_all)
      ..sort((a, b) => a.distanceFrom(lat, lng).compareTo(b.distanceFrom(lat, lng)));
    return sorted.take(limit).toList();
  }
}