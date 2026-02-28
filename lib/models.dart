import 'package:latlong2/latlong.dart';

// Типы инвалидности
enum DisabilityType {
  wheelchair,      // колясочники
  blind,           // незрячие
  deaf,            // глухие
  mobility,        // проблемы с мобильностью
  none,            // без инвалидности
}

const Map<DisabilityType, List<String>> importantNegativeTagsForDisability = {
  DisabilityType.wheelchair: [
    'крутые лестницы',
    'узкие проходы',
    'отсутствие пандуса',
    'высокие пороги',
    'отсутствие лифта',
    'некачественная дорога',
  ],
  DisabilityType.blind: [
    'нет тактильной плитки',
    'недостаточное освещение',
    'высокие пороги',
  ],
  DisabilityType.deaf: [
    'отсутствие субтитров',
    'шумное окружение',
  ],
  DisabilityType.mobility: [
    'крутые лестницы',
    'отсутствие пандуса',
    'высокие пороги',
    'отсутствие лифта',
    'некачественная дорога',
  ],
  DisabilityType.none: [],
};


// Хорошие теги
const List<String> positiveTags = [
  'пандусы',
  'субтитры',
  'тактильная плитка',
  'широкие проходы',
  'парковка для инвалидов',
  'лифт',
  'доступный туалет',
  'аудиогид',
  'вибросигналы',
  'световые сигналы',
  'звуковые сигналы',
  'низкопольный транспорт',
  'специальный вход',
];

// Плохие теги
const List<String> negativeTags = [
  'крутые лестницы',
  'узкие проходы',
  'отсутствие пандуса',
  'высокие пороги',
  'нет тактильной плитки',
  'отсутствие субтитров',
  'шумное окружение',
  'недостаточное освещение',
  'некачественная дорога',
  'отсутствие лифта',
  'неудобная парковка',
];

class Review {
  final String id;
  final String userId;
  final String username;
  final int rating;
  final String comment;
  final DateTime timestamp;
  final List<String> photos;

  Review({
    required this.id,
    required this.userId,
    required this.username,
    required this.rating,
    required this.comment,
    required this.timestamp,
    this.photos = const [],
  });
}

class PlaceReport {
  final String id;
  final LatLng location;
  final String title;
  final String description;
  final List<String> positiveTags;
  final List<String> negativeTags;
  final bool isObstacle;
  final String author;
  final int rating;
  final String? photoUrl;
  final List<Review> reviews;

  PlaceReport({
    required this.id,
    required this.location,
    required this.title,
    required this.description,
    this.positiveTags = const [],
    this.negativeTags = const [],
    required this.isObstacle,
    required this.author,
    this.rating = 0,
    this.photoUrl,
    this.reviews = const [],
  });

  PlaceReport copyWith({
    String? id,
    LatLng? location,
    String? title,
    String? description,
    List<String>? positiveTags,
    List<String>? negativeTags,
    bool? isObstacle,
    String? author,
    int? rating,
    String? photoUrl,
    List<Review>? reviews,
  }) {
    return PlaceReport(
      id: id ?? this.id,
      location: location ?? this.location,
      title: title ?? this.title,
      description: description ?? this.description,
      positiveTags: positiveTags ?? this.positiveTags,
      negativeTags: negativeTags ?? this.negativeTags,
      isObstacle: isObstacle ?? this.isObstacle,
      author: author ?? this.author,
      rating: rating ?? this.rating,
      photoUrl: photoUrl ?? this.photoUrl,
      reviews: reviews ?? this.reviews,
    );
  }
}