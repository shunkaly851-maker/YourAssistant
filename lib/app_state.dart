import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'models.dart';
import 'graph.dart';
import 'database.dart';

class AppState extends ChangeNotifier {
  List<PlaceReport> reports = [];
  List<LatLng> currentRoute = [];
  LatLng? startPoint;
  LatLng? endPoint;
  List<String> selectedTags = [];
  DisabilityType currentDisability = DisabilityType.wheelchair;
  bool isLoading = false;
  List<PlaceReport> obstaclesOnRoute = [];
  String? routeWarning;

  double get currentRouteLength {
    if (currentRoute.isEmpty) return 0;
    double distance = 0;
    for (int i = 0; i < currentRoute.length - 1; i++) {
      distance += _distanceBetween(currentRoute[i], currentRoute[i + 1]);
    }
    return distance;
  }

  AppState() {
    loadReportsFromDatabase();
  }

  List<PlaceReport> get filteredReports {
    if (selectedTags.isEmpty) return reports;
    return reports.where((report) {
      return [...report.positiveTags, ...report.negativeTags].any((tag) => selectedTags.contains(tag));
    }).toList();
  }

  void addTagToFilter(String tag) {
    if (!selectedTags.contains(tag)) {
      selectedTags.add(tag);
      _recalculateRoute();
      notifyListeners();
    }
  }

  void removeTagFromFilter(String tag) {
    selectedTags.remove(tag);
    _recalculateRoute();
    notifyListeners();
  }

  bool isTagSelected(String tag) => selectedTags.contains(tag);

  void setDisabilityType(DisabilityType type) {
    currentDisability = type;
    _recalculateRoute();
    notifyListeners();
  }

  void setRoutePoint(LatLng point) {
    if (startPoint == null) {
      startPoint = point;
      routeWarning = null;
    } else if (endPoint == null) {
      endPoint = point;
      _calculateRoute();
    } else {
      startPoint = point;
      endPoint = null;
      currentRoute.clear();
      obstaclesOnRoute.clear();
      routeWarning = null;
    }
    notifyListeners();
  }

  Future<void> _calculateRoute() async {
    if (startPoint == null || endPoint == null) return;

    isLoading = true;
    routeWarning = null;
    notifyListeners();

    try {
      final routingService = RoutingService();
      routingService.setDisabilityType(currentDisability);

      // Получаем маршрут по дорогам
      currentRoute = await routingService.getRoute(startPoint!, endPoint!);
      
      // Проверяем препятствия, важные для этого типа инвалидности
      obstaclesOnRoute = routingService.findObstaclesOnRoute(currentRoute, reports);
      
      if (obstaclesOnRoute.isNotEmpty) {
        // Формируем текст предупреждения в зависимости от типа инвалидности
        String warningText = _getWarningText();
        routeWarning = warningText;
      }
      
    } catch (e) {
      print('Ошибка: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  String _getWarningText() {
    switch (currentDisability) {
      case DisabilityType.wheelchair:
        return '⚠️ На маршруте есть препятствия для колясочников! (лестницы, узкие проходы, отсутствие пандусов)';
      case DisabilityType.blind:
        return '⚠️ На маршруте есть препятствия для незрячих! (отсутствие тактильной плитки, плохое освещение)';
      case DisabilityType.deaf:
        return '⚠️ На маршруте есть препятствия для глухих! (отсутствие субтитров, шум)';
      case DisabilityType.mobility:
        return '⚠️ На маршруте есть препятствия для людей с ограниченной подвижностью!';
      case DisabilityType.intellectual:
        return '⚠️ На маршруте есть факторы, затрудняющие ориентирование!';
      case DisabilityType.none:
        return '⚠️ На маршруте есть препятствия!';
    }
  }

  void _recalculateRoute() {
    if (startPoint != null && endPoint != null) {
      _calculateRoute();
    }
  }

  double _distanceBetween(LatLng p1, LatLng p2) {
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

  Future<void> addReport(PlaceReport report) async {
    reports.add(report);
    await DatabaseService().saveReports([report]);
    _recalculateRoute();
    notifyListeners();
  }

  Future<void> addReview(String placeId, Review review) async {
    final updatedReports = reports.map((report) {
      if (report.id == placeId) {
        final updatedReviews = [...report.reviews, review];
        final averageRating = _calculateAverageRating(updatedReviews);
        return report.copyWith(
          reviews: updatedReviews,
          rating: averageRating,
        );
      }
      return report;
    }).toList();
    
    reports = updatedReports;
    await DatabaseService().saveReports(updatedReports);
    notifyListeners();
  }

  int _calculateAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.map((r) => r.rating).reduce((a, b) => a + b);
    return (total / reviews.length).round();
  }

  Future<void> loadReportsFromDatabase() async {
    isLoading = true;
    notifyListeners();
    
    try {
      final loadedReports = await DatabaseService().loadReports();
      reports = loadedReports;
    } catch (e) {
      debugPrint('Ошибка загрузки из БД: $e');
    } finally {
      isLoading = false;
      notifyListeners();
    }
  }

  Future<void> clearAllReports() async {
    await DatabaseService().deleteAllReports();
    reports = [];
    notifyListeners();
  }
}