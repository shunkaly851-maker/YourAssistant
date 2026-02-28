import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import 'models.dart';

class RoutingService {
  static const double OBSTACLE_RADIUS = 100.0; // радиус обнаружения препятствия (метры)
  
  DisabilityType currentDisability = DisabilityType.wheelchair;

  void setDisabilityType(DisabilityType type) {
    currentDisability = type;
  }

  // Проверяет, есть ли препятствия, важные для данного типа инвалидности
  List<PlaceReport> findObstaclesOnRoute(List<LatLng> route, List<PlaceReport> reports) {
    final obstacles = <PlaceReport>[];
    final Set<String> added = {};
    
    // Получаем список важных тегов для текущего типа инвалидности
    final importantTags = importantNegativeTagsForDisability[currentDisability] ?? [];
    
    print('🔍 Важные теги для ${currentDisability.toString()}: $importantTags');
    
    for (final report in reports) {
      if (report.negativeTags.isEmpty) continue;
      
      // Проверяем, есть ли у препятствия хотя бы один важный тег
      bool hasImportantTag = false;
      for (final tag in report.negativeTags) {
        if (importantTags.contains(tag)) {
          hasImportantTag = true;
          break;
        }
      }
      
      // Если нет важных тегов - игнорируем это препятствие для данного типа инвалидности
      if (!hasImportantTag) {
        print('⏭️ Игнорируем "${report.title}" - теги неважны для этого типа');
        continue;
      }
      
      // Проверяем расстояние до маршрута
      for (final point in route) {
        final dist = _calculateDistance(point, report.location);
        if (dist < OBSTACLE_RADIUS && !added.contains(report.id)) {
          obstacles.add(report);
          added.add(report.id);
          print('⚠️ ВАЖНОЕ препятствие для этого типа: "${report.title}"');
          break;
        }
      }
    }
    
    return obstacles;
  }

  // Получение маршрута от OSRM (по дорогам!)
  Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final url = 'http://router.project-osrm.org/route/v1/foot/'
          '${start.longitude},${start.latitude};${end.longitude},${end.latitude}'
          '?overview=full&geometries=geojson';
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['routes'] != null && data['routes'].isNotEmpty) {
          final geometry = data['routes'][0]['geometry'];
          if (geometry['coordinates'] != null) {
            final coords = geometry['coordinates'] as List;
            return coords.map((c) => LatLng(c[1], c[0])).toList();
          }
        }
      }
      return [start, end]; // fallback
      
    } catch (e) {
      print('Ошибка OSRM: $e');
      return [start, end];
    }
  }

  double _calculateDistance(LatLng p1, LatLng p2) {
    const R = 6371000;
    final lat1 = p1.latitude * pi / 180;
    final lat2 = p2.latitude * pi / 180;
    final dLat = (p2.latitude - p1.latitude) * pi / 180;
    final dLon = (p2.longitude - p1.longitude) * pi / 180;

    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(lat1) * cos(lat2) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }
}