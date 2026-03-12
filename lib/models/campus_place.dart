import 'dart:math';
import 'package:flutter/material.dart';

enum PlaceCategory {
  cafeteria, bloque, bano, porteria, parqueadero, jardin, deporte;

  String get displayName {
    switch (this) {
      case PlaceCategory.cafeteria:   return 'Cafeterías';
      case PlaceCategory.bloque:      return 'Bloques';
      case PlaceCategory.bano:        return 'Baños';
      case PlaceCategory.porteria:    return 'Porterías';
      case PlaceCategory.parqueadero: return 'Parqueaderos';
      case PlaceCategory.jardin:      return 'Jardines';
      case PlaceCategory.deporte:     return 'Deportes';
    }
  }

  IconData get icon {
    switch (this) {
      case PlaceCategory.cafeteria:   return Icons.restaurant_rounded;
      case PlaceCategory.bloque:      return Icons.apartment_rounded;
      case PlaceCategory.bano:        return Icons.wc_rounded;
      case PlaceCategory.porteria:    return Icons.door_front_door_rounded;
      case PlaceCategory.parqueadero: return Icons.directions_car_rounded;
      case PlaceCategory.jardin:      return Icons.park_rounded;
      case PlaceCategory.deporte:     return Icons.sports_soccer_rounded;
    }
  }
}

class CampusPlace {
  final String name;
  final String description;
  final double latitude;
  final double longitude;
  final PlaceCategory category;
  final List<List<double>>? polygon;
  late final String searchableText;

  CampusPlace({
    required this.name,
    required this.description,
    required this.latitude,
    required this.longitude,
    required this.category,
    this.polygon,
  }) {
    searchableText = '$name $description'.toLowerCase();
  }

  double distanceFrom(double lat, double lng) {
    const R = 6371000.0;
    final dLat = _rad(lat - latitude);
    final dLon = _rad(lng - longitude);
    final a = sin(dLat/2)*sin(dLat/2) +
        cos(_rad(latitude))*cos(_rad(lat))*sin(dLon/2)*sin(dLon/2);
    return R * 2 * asin(sqrt(a));
  }

  double _rad(double deg) => deg * pi / 180;

  static PlaceCategory categorize(String name, String description) {
    final n = name.toLowerCase().trim();
    final d = description.toLowerCase();

    // Parqueaderos
    if (n.contains('parqueadero') || n.contains('paraqueadero')) return PlaceCategory.parqueadero;
    // Porterías
    if (n.startsWith('portería') || n.startsWith('porteria')) return PlaceCategory.porteria;
    // Baños explícitos en nombre
    if (n.startsWith('baños -') || n.startsWith('baño -')) return PlaceCategory.bano;
    // Cafeterías
    if (n == 'bloque 36' || n.contains('cafetería') || n.contains('cafeteria')) return PlaceCategory.cafeteria;
    if (d.contains('juan valdez') || d.contains('frisby') || d.contains('bigos') ||
        d.contains('dunkin') || d.contains('tejadito') || d.contains('recanto')) return PlaceCategory.cafeteria;
    // Deportes — canchas, gimnasio, piscina, placa polideportiva, coliseo
    if (n.contains('cancha') || n.contains('gimnasio') || n.contains('piscina') ||
        n.contains('polideportiv') || n.contains('coliseo')) return PlaceCategory.deporte;
    // Jardines / espacios verdes
    if (n.contains('parque') || n.contains('jardín') || n.contains('jardin') ||
        n.contains('plazoleta') || n.contains('domo') || n.contains('quiosco') ||
        n.contains('ceiba') || n.contains('pimientos') || n.contains('guayabos')) return PlaceCategory.jardin;
    // Todo lo demás → bloque
    return PlaceCategory.bloque;
  }

  @override
  String toString() => name;
}