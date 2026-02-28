import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import 'models.dart';
import 'database.dart';
import 'app_state.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Инициализация базы данных перед запуском приложения
  final databaseService = DatabaseService();
  await databaseService.initDatabase();
  
  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(),
      child: const MaterialApp(
        debugShowCheckedModeBanner: false,
        home: HomeScreen(),
      ),
    ),
  );
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text("RostovAccess"),
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => context.read<AppState>().loadReportsFromDatabase(),
            tooltip: 'Обновить данные',
          ),
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: () async {
              final shouldDelete = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Очистить базу данных'),
                  content: const Text('Вы уверены, что хотите удалить все метки?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text('Удалить всё'),
                    ),
                  ],
                ),
              );
              
              if (shouldDelete == true) {
                await context.read<AppState>().clearAllReports();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('База данных очищена'))
                  );
                }
              }
            },
            tooltip: 'Очистить базу данных',
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: const LatLng(47.2045, 39.6660),
              initialZoom: 17.0,
              onTap: (tapPos, point) => state.setRoutePoint(point),
              onLongPress: (tapPos, point) => _showAddDialog(context, point),
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://cartodb-basemaps-{s}.global.ssl.fastly.net/light_all/{z}/{x}/{y}.png',
                subdomains: const ['a', 'b', 'c'],
                userAgentPackageName: 'ru.rostov.hackathon',
              ),
              PolylineLayer(
                polylines: [
                  if (state.currentRoute.isNotEmpty)
                    Polyline(
                      points: state.currentRoute,
                      strokeWidth: 6.0,
                      color: Colors.blue,
                    ),
                ],
              ),
              MarkerLayer(
                markers: [
                  if (state.startPoint != null)
                    Marker(
                      point: state.startPoint!,
                      child: const Icon(Icons.my_location, color: Colors.green, size: 35),
                    ),
                  if (state.endPoint != null)
                    Marker(
                      point: state.endPoint!,
                      child: const Icon(Icons.flag, color: Colors.black, size: 35),
                    ),
                  ...state.filteredReports.map((report) {
                    return Marker(
                      point: report.location,
                      width: 40,
                      height: 40,
                      child: GestureDetector(
                        onTap: () => _showDetails(context, report),
                        child: Container(
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: report.isObstacle ? Colors.red : Colors.green,
                              width: 2,
                            ),
                          ),
                          child: Icon(
                            report.isObstacle ? Icons.warning : Icons.accessible,
                            color: report.isObstacle ? Colors.red : Colors.green,
                            size: 25,
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ],
              ),
            ],
          ),
          _tagsFilterPanel(context),
          _disabilitySelector(context), 
          if (state.routeWarning != null)
            Positioned(
              top: 140, // чуть ниже селектора
              left: 20,
              right: 20,
              child: Card(
                color: Colors.red,
                elevation: 8,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber, color: Colors.white, size: 30),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          state.routeWarning!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),


          if (state.isLoading)
            const Positioned(
              top: 100,
              left: 0,
              right: 0,
              child: Center(
                child: Card(
                  child: Padding(
                    padding: EdgeInsets.all(16.0),
                    child: CircularProgressIndicator(),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDistance(double meters) {
    if (meters < 1000) {
      return '${meters.round()} м';
    } else {
      return '${(meters / 1000).toStringAsFixed(1)} км';
    }
  }

  Widget _tagsFilterPanel(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        color: Colors.white.withOpacity(0.9),
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              const SizedBox(width: 10),
              const Text("Теги: ", style: TextStyle(fontWeight: FontWeight.bold)),
              ...[...positiveTags, ...negativeTags].map((tag) => _tagChip(context, tag)).toList(),
            ],
          ),
        ),
      ),
    );
  }

  // В методе _disabilitySelector убираем DisabilityType.none
Widget _disabilitySelector(BuildContext context) {
  final state = context.watch<AppState>();
  
  return Positioned(
    top: 80,
    left: 10,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButton<DisabilityType>(
        value: state.currentDisability,
        underline: const SizedBox(),
        icon: const Icon(Icons.arrow_drop_down),
        items: const [
          DropdownMenuItem(
            value: DisabilityType.wheelchair,
            child: Row(
              children: [
                Icon(Icons.wheelchair_pickup, size: 20),
                SizedBox(width: 8),
                Text('Колясочник'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: DisabilityType.blind,
            child: Row(
              children: [
                Icon(Icons.visibility_off, size: 20),
                SizedBox(width: 8),
                Text('Незрячий'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: DisabilityType.deaf,
            child: Row(
              children: [
                Icon(Icons.hearing_disabled, size: 20),
                SizedBox(width: 8),
                Text('Глухой'),
              ],
            ),
          ),
          DropdownMenuItem(
            value: DisabilityType.mobility,
            child: Row(
              children: [
                Icon(Icons.elderly, size: 20),
                SizedBox(width: 8),
                Text('С ограничениями'),
              ],
            ),
          ),
        ],
        onChanged: (DisabilityType? newValue) {
          if (newValue != null) {
            context.read<AppState>().setDisabilityType(newValue);
          }
        },
      ),
    ),
  );
}
  Widget _tagChip(BuildContext context, String tag) {
    final state = context.watch<AppState>();
    final isSelected = state.isTagSelected(tag);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(tag),
        selected: isSelected,
        onSelected: (selected) => selected
            ? context.read<AppState>().addTagToFilter(tag)
            : context.read<AppState>().removeTagFromFilter(tag),
        selectedColor: Colors.indigo.shade100,
      ),
    );
  }

  void _showAddDialog(BuildContext context, LatLng point) {
    final titleCtrl = TextEditingController();
    final descCtrl = TextEditingController();
    List<String> _selectedPositiveTags = [];
    List<String> _selectedNegativeTags = [];
    bool isObstacle = true;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text("Добавить метку"),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleCtrl,
                  decoration: const InputDecoration(labelText: "Название (напр. Кинотеатр)"),
                ),
                TextField(
                  controller: descCtrl,
                  decoration: const InputDecoration(labelText: "Описание"),
                ),
                const SizedBox(height: 10),
                const Text("Что здесь есть?", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 5,
                  children: positiveTags.map((tag) {
                    bool selected = _selectedPositiveTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          if (value) {
                            _selectedPositiveTags.add(tag);
                          } else {
                            _selectedPositiveTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                const Text("Какие проблемы?", style: TextStyle(fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 5,
                  children: negativeTags.map((tag) {
                    bool selected = _selectedNegativeTags.contains(tag);
                    return FilterChip(
                      label: Text(tag),
                      selected: selected,
                      onSelected: (bool value) {
                        setState(() {
                          if (value) {
                            _selectedNegativeTags.add(tag);
                          } else {
                            _selectedNegativeTags.remove(tag);
                          }
                        });
                      },
                    );
                  }).toList(),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  title: Text(isObstacle ? "Это ПРЕПЯТСТВИЕ" : "Это ДОСТУПНОЕ МЕСТО"),
                  value: isObstacle,
                  activeColor: Colors.red,
                  inactiveThumbColor: Colors.green,
                  onChanged: (v) => setState(() => isObstacle = v),
                ),
                ElevatedButton.icon(
                  icon: const Icon(Icons.camera_alt),
                  label: const Text("Добавить фото"),
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Фото пока не поддерживается'))
                    );
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Отмена'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.isNotEmpty) {
                  final newReport = PlaceReport(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    location: point,
                    title: titleCtrl.text,
                    description: descCtrl.text,
                    positiveTags: _selectedPositiveTags,
                    negativeTags: _selectedNegativeTags,
                    isObstacle: isObstacle,
                    author: 'Пользователь',
                    rating: 0,
                    photoUrl: null,
                    reviews: [],
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сохранение...'))
                  );
                  
                  await context.read<AppState>().addReport(newReport);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Метка "${newReport.title}" добавлена'))
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Заполните название'))
                  );
                }
              },
              child: const Text('Сохранить'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(BuildContext context, PlaceReport report) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(report.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Описание: ${report.description.isEmpty ? "Нет описания" : report.description}'),
              const SizedBox(height: 8),
              if (report.positiveTags.isNotEmpty) ...[
                Text('Доступные элементы: ${report.positiveTags.join(', ')}'),
                const SizedBox(height: 8),
              ],
              if (report.negativeTags.isNotEmpty) ...[
                Text('Проблемы: ${report.negativeTags.join(', ')}'),
                const SizedBox(height: 8),
              ],
              Container(
                padding: const EdgeInsets.all(8),
                color: report.isObstacle ? Colors.red.shade50 : Colors.green.shade50,
                child: Row(
                  children: [
                    Icon(
                      report.isObstacle ? Icons.warning : Icons.check_circle,
                      color: report.isObstacle ? Colors.red : Colors.green,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        report.isObstacle ? 'ПРЕПЯТСТВИЕ' : 'ДОСТУПНОЕ МЕСТО',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: report.isObstacle ? Colors.red : Colors.green,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text('Рейтинг: ${report.rating}★ (${report.reviews.length} отзывов)'),
              const SizedBox(height: 8),
              if (report.reviews.isNotEmpty) ...[
                const Text('Отзывы:', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                ...report.reviews.map((review) => Card(
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              review.username,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Text('${review.rating}★'),
                            const Spacer(),
                            Text(
                              _formatDate(review.timestamp),
                              style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(review.comment),
                        if (review.photos.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 60,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: review.photos.length,
                              itemBuilder: (ctx, idx) => Container(
                                width: 60,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade200,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Center(child: Icon(Icons.photo)),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                )).toList(),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Закрыть'),
          ),
          ElevatedButton(
            onPressed: () => _showAddReviewDialog(context, report.id),
            child: const Text('Добавить отзыв'),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}.${date.month}.${date.year}';
  }

  void _showAddReviewDialog(BuildContext context, String placeId) {
    final ratingCtrl = TextEditingController();
    final commentCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Добавить отзыв"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: ratingCtrl,
                decoration: const InputDecoration(
                  labelText: "Рейтинг (1–5)",
                  hintText: "Введите число от 1 до 5",
                ),
                keyboardType: TextInputType.number,
              ),
              TextField(
                controller: commentCtrl,
                decoration: const InputDecoration(labelText: "Комментарий"),
                maxLines: 3,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Отмена'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (ratingCtrl.text.isNotEmpty && commentCtrl.text.isNotEmpty) {
                final rating = int.tryParse(ratingCtrl.text) ?? 0;
                if (rating >= 1 && rating <= 5) {
                  final newReview = Review(
                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                    userId: 'user_${DateTime.now().millisecondsSinceEpoch}',
                    username: 'Анонимный пользователь',
                    rating: rating,
                    comment: commentCtrl.text,
                    timestamp: DateTime.now(),
                    photos: [],
                  );
                  
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Сохранение отзыва...'))
                  );
                  
                  await context.read<AppState>().addReview(placeId, newReview);
                  
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Отзыв добавлен'))
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Рейтинг должен быть от 1 до 5'))
                  );
                }
              } else {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Заполните все поля'))
                );
              }
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}