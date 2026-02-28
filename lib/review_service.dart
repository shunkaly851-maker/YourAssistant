
import 'models.dart';
import 'database.dart';

class ReviewService {
  final DatabaseService dbService = DatabaseService();

  // Добавить отзыв к месту
  Future<void> addReview(String placeId, Review review) async {
    final reports = await dbService.loadReports();
    final report = reports.firstWhere((r) => r.id == placeId);

    final updatedReviews = [...report.reviews, review];
    final averageRating = _calculateAverageRating(updatedReviews);


    final updatedReport = report.copyWith(
      reviews: updatedReviews,
      rating: averageRating,
    );

    await dbService.saveReports([updatedReport]);
  }

  // Рассчитать средний рейтинг
  int _calculateAverageRating(List<Review> reviews) {
    if (reviews.isEmpty) return 0;
    final total = reviews.map((r) => r.rating).reduce((a, b) => a + b);
    return (total / reviews.length).round();
  }
}
