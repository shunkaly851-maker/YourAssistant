import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'dart:math';
import 'package:path/path.dart' as path;
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:latlong2/latlong.dart'; 
import 'models.dart'; 

class DatabaseService {
  static final DatabaseService _instance = DatabaseService._internal();
  factory DatabaseService() => _instance;
  DatabaseService._internal();

  static Database? _database;
  static bool _initialized = false;

  // Инициализация фабрики базы данных (для десктопа)
  static void _initializeDatabaseFactory() {
    if (!_initialized) {
      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        // Для десктопных платформ используем ffi
        sqfliteFfiInit();
        databaseFactory = databaseFactoryFfi;
      }
      // Для мобильных платформ (Android/iOS) инициализация не требуется
      _initialized = true;
    }
  }

  Future<Database> get database async {
    if (_database != null && _database!.isOpen) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  // Публичный метод для инициализации БД при старте
  Future<void> initDatabase() async {
    _initializeDatabaseFactory();
    await database;
  }

  Future<Database> _initDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String pathStr = path.join(dbPath, 'rostov_access.db');
    
    return await openDatabase(
      pathStr,
      version: 2, // Увеличиваем версию для обновления схемы
      onCreate: _createTables,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _createTables(Database db, int version) async {
    await db.execute('''
      CREATE TABLE place_reports (
        id TEXT PRIMARY KEY,
        latitude REAL NOT NULL,
        longitude REAL NOT NULL,
        title TEXT NOT NULL,
        description TEXT,
        positive_tags TEXT NOT NULL DEFAULT '[]',
        negative_tags TEXT NOT NULL DEFAULT '[]',
        is_obstacle INTEGER NOT NULL,
        author TEXT NOT NULL,
        rating INTEGER NOT NULL DEFAULT 0,
        photo_url TEXT,
        reviews TEXT NOT NULL DEFAULT '[]',
        created_at INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Добавляем поле created_at с значением по умолчанию 0
      await db.execute('ALTER TABLE place_reports ADD COLUMN created_at INTEGER NOT NULL DEFAULT 0');
      
      // Обновляем существующие записи, устанавливая created_at в текущее время
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000; // в секундах
      await db.update(
        'place_reports',
        {'created_at': now},
        where: 'created_at = ?',
        whereArgs: [0],
      );
    }
  }

  Future<void> saveReports(List<PlaceReport> reports) async {
    if (reports.isEmpty) return;
    
    final db = await database;
    await db.transaction((txn) async {
      for (final report in reports) {
        await txn.insert(
          'place_reports',
          {
            'id': report.id,
            'latitude': report.location.latitude,
            'longitude': report.location.longitude,
            'title': report.title,
            'description': report.description,
            'positive_tags': jsonEncode(report.positiveTags),
            'negative_tags': jsonEncode(report.negativeTags),
            'is_obstacle': report.isObstacle ? 1 : 0,
            'author': report.author,
            'rating': report.rating,
            'photo_url': report.photoUrl,
            'reviews': jsonEncode(report.reviews.map((r) => {
              'id': r.id,
              'userId': r.userId,
              'username': r.username,
              'rating': r.rating,
              'comment': r.comment,
              'timestamp': r.timestamp.toIso8601String(),
              'photos': r.photos,
            }).toList()),
            'created_at': DateTime.now().millisecondsSinceEpoch ~/ 1000, // Unix timestamp в секундах
          },
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
    });
  }

  Future<List<PlaceReport>> loadReports() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'place_reports',
      orderBy: 'created_at DESC', // Сортируем по дате создания
    );

    return List.generate(maps.length, (i) {
      final map = maps[i];
      try {
        return PlaceReport(
          id: map['id'] as String,
          location: LatLng(
            map['latitude'] as double,
            map['longitude'] as double,
          ),
          title: map['title'] as String,
          description: map['description'] != null ? map['description'] as String : '',
          positiveTags: _decodeJsonList(map['positive_tags'] as String),
          negativeTags: _decodeJsonList(map['negative_tags'] as String),
          isObstacle: (map['is_obstacle'] as int) == 1,
          author: map['author'] as String,
          rating: map['rating'] as int,
          photoUrl: map['photo_url'] as String?,
          reviews: _decodeReviews(map['reviews'] as String),
        );
      } catch (e) {
        print('Ошибка при загрузке отчета ${map['id']}: $e');
        // Возвращаем пустой отчет в случае ошибки
        return PlaceReport(
          id: map['id'] as String,
          location: LatLng(0, 0),
          title: 'Ошибка загрузки',
          description: '',
          positiveTags: [],
          negativeTags: [],
          isObstacle: false,
          author: 'Система',
          rating: 0,
          photoUrl: null,
          reviews: [],
        );
      }
    });
  }

  List<String> _decodeJsonList(String jsonString) {
    try {
      if (jsonString.isEmpty || jsonString == '[]') return [];
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((e) => e.toString()).toList();
    } catch (e) {
      print('Ошибка декодирования списка: $e');
      return [];
    }
  }

  List<Review> _decodeReviews(String jsonString) {
    try {
      if (jsonString.isEmpty || jsonString == '[]') return [];
      final List<dynamic> decoded = jsonDecode(jsonString);
      return decoded.map((r) {
        try {
          return Review(
            id: r['id'] as String,
            userId: r['userId'] as String,
            username: r['username'] as String,
            rating: r['rating'] as int,
            comment: r['comment'] as String,
            timestamp: DateTime.parse(r['timestamp'] as String),
            photos: r['photos'] != null ? List<String>.from(r['photos']) : [],
          );
        } catch (e) {
          print('Ошибка создания отзыва: $e');
          return null;
        }
      }).whereType<Review>().toList();
    } catch (e) {
      print('Ошибка декодирования отзывов: $e');
      return [];
    }
  }

  // Метод для удаления базы данных (для тестирования)
  Future<void> deleteDatabase() async {
    final String dbPath = await getDatabasesPath();
    final String pathStr = path.join(dbPath, 'rostov_access.db');
    await databaseFactory.deleteDatabase(pathStr);
    _database = null;
  }

  // Метод для удаления всех отчетов
  Future<void> deleteAllReports() async {
    final db = await database;
    await db.delete('place_reports');
  }

  // Метод для получения статистики
  Future<Map<String, dynamic>> getStatistics() async {
    final db = await database;
    
    // Получаем общее количество
    final totalResult = await db.rawQuery('SELECT COUNT(*) as count FROM place_reports');
    final totalCount = totalResult.isNotEmpty ? totalResult.first['count'] as int : 0;
    
    // Получаем количество препятствий
    final obstacleResult = await db.rawQuery('SELECT COUNT(*) as count FROM place_reports WHERE is_obstacle = 1');
    final obstacleCount = obstacleResult.isNotEmpty ? obstacleResult.first['count'] as int : 0;
    
    // Получаем количество доступных мест
    final accessibleResult = await db.rawQuery('SELECT COUNT(*) as count FROM place_reports WHERE is_obstacle = 0');
    final accessibleCount = accessibleResult.isNotEmpty ? accessibleResult.first['count'] as int : 0;
    
    return {
      'total': totalCount,
      'obstacles': obstacleCount,
      'accessible': accessibleCount,
    };
  }

  // Метод для поиска отчетов по радиусу
  Future<List<PlaceReport>> findReportsNearby(LatLng center, double radiusInMeters) async {
    final db = await database;
    
    // Приблизительный расчет: 1 градус широты ≈ 111 км
    final latDelta = radiusInMeters / 111000.0;
    // 1 градус долготы зависит от широты, используем максимальное значение для простоты
    final lngDelta = radiusInMeters / (111000.0 * cos(center.latitude * pi / 180));
    
    final minLat = center.latitude - latDelta;
    final maxLat = center.latitude + latDelta;
    final minLng = center.longitude - lngDelta;
    final maxLng = center.longitude + lngDelta;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'place_reports',
      where: 'latitude BETWEEN ? AND ? AND longitude BETWEEN ? AND ?',
      whereArgs: [minLat, maxLat, minLng, maxLng],
    );

    return maps.map((map) {
      try {
        return PlaceReport(
          id: map['id'] as String,
          location: LatLng(
            map['latitude'] as double,
            map['longitude'] as double,
          ),
          title: map['title'] as String,
          description: map['description'] != null ? map['description'] as String : '',
          positiveTags: _decodeJsonList(map['positive_tags'] as String),
          negativeTags: _decodeJsonList(map['negative_tags'] as String),
          isObstacle: (map['is_obstacle'] as int) == 1,
          author: map['author'] as String,
          rating: map['rating'] as int,
          photoUrl: map['photo_url'] as String?,
          reviews: _decodeReviews(map['reviews'] as String),
        );
      } catch (e) {
        print('Ошибка при загрузке отчета ${map['id']}: $e');
        return null;
      }
    }).whereType<PlaceReport>().toList();
  }

  // Метод для получения отчетов по автору
  Future<List<PlaceReport>> getReportsByAuthor(String author) async {
    final db = await database;
    
    final List<Map<String, dynamic>> maps = await db.query(
      'place_reports',
      where: 'author = ?',
      whereArgs: [author],
    );

    return maps.map((map) {
      try {
        return PlaceReport(
          id: map['id'] as String,
          location: LatLng(
            map['latitude'] as double,
            map['longitude'] as double,
          ),
          title: map['title'] as String,
          description: map['description'] != null ? map['description'] as String : '',
          positiveTags: _decodeJsonList(map['positive_tags'] as String),
          negativeTags: _decodeJsonList(map['negative_tags'] as String),
          isObstacle: (map['is_obstacle'] as int) == 1,
          author: map['author'] as String,
          rating: map['rating'] as int,
          photoUrl: map['photo_url'] as String?,
          reviews: _decodeReviews(map['reviews'] as String),
        );
      } catch (e) {
        print('Ошибка при загрузке отчета ${map['id']}: $e');
        return null;
      }
    }).whereType<PlaceReport>().toList();
  }
}