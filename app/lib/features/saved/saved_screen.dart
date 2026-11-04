import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/source_attribution.dart';
import '../suggestions/place_detail_screen.dart';
import '../tours/tour_screen.dart';
import 'saved_snapshot.dart';
import 'saved_store.dart';

class SavedScreen extends StatefulWidget {
  final ApiClient api;
  const SavedScreen({super.key, required this.api});
  @override
  State<SavedScreen> createState() => _SavedScreenState();
}

class _SavedScreenState extends State<SavedScreen> {
  final store = SavedStore();
  List<SavedItem>? items;
  Object? error;
  String? openingId;
  @override
  void initState() {
    super.initState();
    load();
  }

  // Place names are not stored on the device (Places terms); fetched when online.
  final names = <String, String>{};

  Future<void> load() async {
    try {
      await store.compact();
      final data = await store.list();
      if (mounted) {
        setState(() {
          items = data;
          error = null;
        });
      }
      for (final item in data.where(
        (i) => i.kind == 'place' && !names.containsKey(i.id),
      )) {
        widget.api
            .place(item.snapshot['id'])
            .then((p) {
              if (mounted) setState(() => names[item.id] = p.name);
            })
            .catchError((_) {});
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> open(SavedItem item) async {
    if (openingId != null) return;
    setState(() => openingId = item.id);
    var snapshot = item.snapshot;
    var offline = false;
    try {
      snapshot = await hydrate(item.kind, item.snapshot, widget.api);
    } on ApiException {
      offline = true;
    }
    if (!mounted) return;
    setState(() => openingId = null);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => item.kind == 'tour'
            ? TourScreen(tour: Tour.fromJson(snapshot), offline: offline)
            : PlaceDetailScreen(
                place: Place.fromJson(snapshot),
                offline: offline,
              ),
      ),
    );
    await load();
  }

  Future<void> remove(SavedItem item) async {
    try {
      await store.remove(item.id);
      await load();
    } catch (_) {
      if (mounted) {
        setState(() => error = 'Không thể bỏ lưu. Vui lòng thử lại.');
      }
    }
  }

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (items?.isNotEmpty == true) const SourceAttribution(),
      Text(
        'Những nơi muốn quay lại',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text(
        'Lưu trên thiết bị này. Khi offline vẫn xem được lời dẫn tour; tên và chi tiết địa điểm cần kết nối mạng.',
      ),
      const SizedBox(height: 20),
      if (error != null) ErrorRetry(error!, load),
      if (items == null) const LinearProgressIndicator(),
      if (items?.isEmpty == true)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              Icon(Icons.bookmark_outline, size: 56),
              SizedBox(height: 12),
              Text(
                'Chưa có mục đã lưu. Hãy lưu một địa điểm hoặc tour bạn thích.',
              ),
            ],
          ),
        ),
      if (items != null)
        ...items!.map(
          (item) => Card(
            child: ListTile(
              leading: openingId == item.id
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(),
                    )
                  : Icon(
                      item.kind == 'tour' ? Icons.route : Icons.place_outlined,
                    ),
              title: Text(names[item.id] ?? item.title),
              subtitle: Text(
                'Đã lưu ${item.savedAt.toLocal().day}/${item.savedAt.toLocal().month}/${item.savedAt.toLocal().year}',
              ),
              trailing: IconButton(
                tooltip: 'Bỏ lưu',
                icon: const Icon(Icons.bookmark_remove_outlined),
                onPressed: () => remove(item),
              ),
              onTap: openingId == null ? () => open(item) : null,
            ),
          ),
        ),
    ],
  );
}
