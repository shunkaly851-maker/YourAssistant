import 'package:latlong2/latlong.dart';

// типы инвалидности 
enum DisabilityProfile { wheelchair, vision, hearing, motor, stroller, none }

// отзыв
class Review {
  final String author;
  final String text;
  final int rating;
  Review(this.author, this.text, this.rating);
}

// место 
class Place {
  final String id;
  final String name;
  final LatLng location;
  final String type; // кафе, магазин,аптека
  final List<String> tags; // пандус и т.д
  final List<Review> reviews;
  final String? photoUrl;

  Place({
    required this.id,
    required this.name,
    required this.location,
    required this.type,
    required this.tags,
    this.reviews = const[],
    this.photoUrl,
  });

  bool isAccessibleFor(DisabilityProfile profile) {
    if (profile == DisabilityProfile.wheelchair && tags.contains('stairs') && !tags.contains('ramp')) return false;
    if (profile == DisabilityProfile.stroller && tags.contains('stairs') && !tags.contains('ramp')) return false;
    return true; 
  }
}