import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class RoutePoint {
  final double latitude;
  final double longitude;

  const RoutePoint({required this.latitude, required this.longitude});
}

class RouteResult {
  final List<String> nodePath;
  final List<RoutePoint> polyline;
  final double totalDistanceMeters;
  final Duration estimatedWalkTime;
  final int exploredNodes;
  final int computationTimeMs;
  final String originNodeId;
  final String destinationNodeId;

  const RouteResult({
    required this.nodePath,
    required this.polyline,
    required this.totalDistanceMeters,
    required this.estimatedWalkTime,
    required this.exploredNodes,
    required this.computationTimeMs,
    required this.originNodeId,
    required this.destinationNodeId,
  });
}

enum RoutingStatus { idle, loading, ready, error }

class RoutingService extends ChangeNotifier {
  static final RoutingService _instance = RoutingService._internal();
  factory RoutingService() => _instance;
  RoutingService._internal();

  final Map<String, _GraphNode> _nodes = {};
  bool _isLoaded = false;

  RoutingStatus _status = RoutingStatus.idle;
  String _lastError = '';
  RouteResult? _currentRoute;

  bool get isLoaded => _isLoaded;
  RoutingStatus get status => _status;
  String get lastError => _lastError;
  RouteResult? get currentRoute => _currentRoute;

  Future<void> load() async {
    if (_isLoaded) return;
    try {
      final raw = await rootBundle.loadString('assets/data/routing_graph.json');
      final json = jsonDecode(raw) as Map<String, dynamic>;
      final nodes = (json['nodes'] as Map<String, dynamic>?) ?? {};

      for (final entry in nodes.entries) {
        final id = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final lat = (data['lat'] as num).toDouble();
        final lon = (data['lon'] as num).toDouble();
        final neighborsRaw = (data['neighbors'] as List<dynamic>? ?? const []);
        final neighbors = <_GraphEdge>[];

        for (final n in neighborsRaw) {
          final m = n as Map<String, dynamic>;
          neighbors.add(
            _GraphEdge(
              toId: m['id'].toString(),
              distanceMeters: (m['distance'] as num?)?.toDouble() ?? 0,
            ),
          );
        }

        _nodes[id] = _GraphNode(
          id: id,
          lat: lat,
          lon: lon,
          neighbors: neighbors,
        );
      }

      _isLoaded = true;
      notifyListeners();
      debugPrint('✅ Grafo cargado: ${_nodes.length} nodos');
    } catch (e) {
      _lastError = 'Error al cargar el grafo: $e';
      _status = RoutingStatus.error;
      notifyListeners();
      debugPrint('❌ $_lastError');
    }
  }

  Future<RouteResult?> buildRoute({
    required double originLat,
    required double originLng,
    required double destinationLat,
    required double destinationLng,
  }) async {
    if (!_isLoaded) {
      await load();
      if (!_isLoaded) return null;
    }

    _status = RoutingStatus.loading;
    _lastError = '';
    notifyListeners();

    final stopwatch = Stopwatch()..start();

    final originId = _nearestNodeId(originLat, originLng);
    final destinationId = _nearestNodeId(destinationLat, destinationLng);

    if (originId == null || destinationId == null) {
      _status = RoutingStatus.error;
      _lastError = 'No fue posible ubicar nodos cercanos para origen y destino.';
      _currentRoute = null;
      notifyListeners();
      return null;
    }

    final search = _aStar(originId, destinationId);
    if (search == null || search.path.isEmpty) {
      _status = RoutingStatus.error;
      _lastError = 'No existe una ruta peatonal conectada entre origen y destino.';
      _currentRoute = null;
      notifyListeners();
      return null;
    }

    final polyline = <RoutePoint>[];
    for (final nodeId in search.path) {
      final node = _nodes[nodeId];
      if (node != null) {
        polyline.add(RoutePoint(latitude: node.lat, longitude: node.lon));
      }
    }

    final totalDistance = _computePathDistance(search.path);
    final walkSeconds = (totalDistance / 1.35).round();
    stopwatch.stop();

    _currentRoute = RouteResult(
      nodePath: search.path,
      polyline: polyline,
      totalDistanceMeters: totalDistance,
      estimatedWalkTime: Duration(seconds: walkSeconds),
      exploredNodes: search.exploredNodes,
      computationTimeMs: stopwatch.elapsedMilliseconds,
      originNodeId: originId,
      destinationNodeId: destinationId,
    );
    _status = RoutingStatus.ready;
    notifyListeners();
    return _currentRoute;
  }

  String? _nearestNodeId(double lat, double lon) {
    if (_nodes.isEmpty) return null;
    String? bestId;
    double bestDistance = double.infinity;

    for (final node in _nodes.values) {
      final d = _haversineMeters(lat, lon, node.lat, node.lon);
      if (d < bestDistance) {
        bestDistance = d;
        bestId = node.id;
      }
    }
    return bestId;
  }

  _SearchResult? _aStar(String startId, String goalId) {
    if (!_nodes.containsKey(startId) || !_nodes.containsKey(goalId)) return null;

    final open = <_OpenNode>[ _OpenNode(id: startId, fScore: _heuristic(startId, goalId)) ];
    final cameFrom = <String, String>{};
    final gScore = <String, double>{startId: 0.0};
    final closed = <String>{};

    int explored = 0;

    while (open.isNotEmpty) {
      final current = _popLowestF(open);
      if (closed.contains(current.id)) continue;
      explored++;

      if (current.id == goalId) {
        final path = _reconstructPath(cameFrom, current.id);
        if (!_isPathConnected(path)) return null;
        return _SearchResult(path: path, exploredNodes: explored);
      }

      closed.add(current.id);
      final currentNode = _nodes[current.id]!;

      for (final edge in currentNode.neighbors) {
        if (!_nodes.containsKey(edge.toId) || closed.contains(edge.toId)) continue;

        final edgeDistance = edge.distanceMeters > 0
            ? edge.distanceMeters
            : _heuristic(current.id, edge.toId);

        final tentativeG = (gScore[current.id] ?? double.infinity) + edgeDistance;
        final neighborG = gScore[edge.toId] ?? double.infinity;

        if (tentativeG < neighborG) {
          cameFrom[edge.toId] = current.id;
          gScore[edge.toId] = tentativeG;
          final f = tentativeG + _heuristic(edge.toId, goalId);
          open.add(_OpenNode(id: edge.toId, fScore: f));
        }
      }
    }

    return null;
  }

  _OpenNode _popLowestF(List<_OpenNode> open) {
    int bestIndex = 0;
    for (int i = 1; i < open.length; i++) {
      if (open[i].fScore < open[bestIndex].fScore) {
        bestIndex = i;
      }
    }
    final value = open[bestIndex];
    open.removeAt(bestIndex);
    return value;
  }

  List<String> _reconstructPath(Map<String, String> cameFrom, String current) {
    final path = <String>[current];
    while (cameFrom.containsKey(current)) {
      current = cameFrom[current]!;
      path.add(current);
    }
    return path.reversed.toList();
  }

  bool _isPathConnected(List<String> path) {
    if (path.length <= 1) return true;
    for (int i = 0; i < path.length - 1; i++) {
      final from = _nodes[path[i]];
      if (from == null) return false;
      final hasEdge = from.neighbors.any((e) => e.toId == path[i + 1]);
      if (!hasEdge) return false;
    }
    return true;
  }

  double _computePathDistance(List<String> path) {
    if (path.length <= 1) return 0;
    double total = 0;

    for (int i = 0; i < path.length - 1; i++) {
      final from = _nodes[path[i]];
      final to = _nodes[path[i + 1]];
      if (from == null || to == null) continue;

      final edge = from.neighbors.where((e) => e.toId == to.id).toList();
      if (edge.isNotEmpty && edge.first.distanceMeters > 0) {
        total += edge.first.distanceMeters;
      } else {
        total += _haversineMeters(from.lat, from.lon, to.lat, to.lon);
      }
    }

    return total;
  }

  double _heuristic(String fromId, String toId) {
    final from = _nodes[fromId]!;
    final to = _nodes[toId]!;
    return _haversineMeters(from.lat, from.lon, to.lat, to.lon);
  }

  double _haversineMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = _toRad(lat2 - lat1);
    final dLon = _toRad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_toRad(lat1)) *
            cos(_toRad(lat2)) *
            sin(dLon / 2) *
            sin(dLon / 2);
    return earthRadius * 2 * asin(sqrt(a));
  }

  double _toRad(double deg) => deg * pi / 180.0;
}

class _GraphNode {
  final String id;
  final double lat;
  final double lon;
  final List<_GraphEdge> neighbors;

  const _GraphNode({
    required this.id,
    required this.lat,
    required this.lon,
    required this.neighbors,
  });
}

class _GraphEdge {
  final String toId;
  final double distanceMeters;

  const _GraphEdge({required this.toId, required this.distanceMeters});
}

class _OpenNode {
  final String id;
  final double fScore;

  const _OpenNode({required this.id, required this.fScore});
}

class _SearchResult {
  final List<String> path;
  final int exploredNodes;

  const _SearchResult({required this.path, required this.exploredNodes});
}