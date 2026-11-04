import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';
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

  Future<void> confirmRemove(SavedItem item) async {
    // A dismissed Dismissible must leave the tree in the same frame.
    setState(() => items?.remove(item));
    final removed = item;
    await remove(removed);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        // Auto-dismiss even with an action (also under accessible navigation).
        persist: false,
        duration: const Duration(seconds: 5),
        content: Text('Đã bỏ lưu “${names[removed.id] ?? removed.title}”.'),
        action: SnackBarAction(
          label: 'Hoàn tác',
          onPressed: () async {
            final prefix = '${removed.kind}:';
            final rawId = removed.id.startsWith(prefix) ? removed.id.substring(prefix.length) : removed.id;
            await store.save(removed.kind, rawId, removed.title, removed.snapshot);
            await load();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tours = items?.where((i) => i.kind == 'tour').toList() ?? [];
    final places = items?.where((i) => i.kind == 'place').toList() ?? [];
    return RefreshIndicator(
      onRefresh: load,
      child: ListView(
        padding: AppSpace.page,
        children: [
          const PageHeader(
            eyebrow: 'Đã lưu',
            title: 'Những nơi\nmuốn quay lại',
          ),
          if (error != null) ErrorRetry(error!, load),
          if (items == null) const LinearProgressIndicator(minHeight: 3),
          if (items?.isEmpty == true)
            const EmptyState(
              icon: Icons.bookmark_add_outlined,
              title: 'Chưa lưu gì cả',
              message: 'Chạm biểu tượng dấu trang ở một địa điểm hoặc lộ trình để giữ lại xem sau.',
            ),
          if (items?.isNotEmpty == true) ...[
            const Notice(
              'Khi offline vẫn đọc được lời dẫn tour. Tên và chi tiết địa điểm cần kết nối mạng.',
              icon: Icons.offline_pin_outlined,
            ),
            const SizedBox(height: AppSpace.xl),
          ],
          for (final (label, group) in [('Lộ trình', tours), ('Địa điểm', places)])
            if (group.isNotEmpty) ...[
              Text('$label · ${group.length}', style: t.titleMedium),
              const SizedBox(height: AppSpace.md),
              for (final item in group) ...[
                Dismissible(
                  key: ValueKey(item.id),
                  direction: DismissDirection.endToStart,
                  onDismissed: (_) => confirmRemove(item),
                  background: Container(
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(right: AppSpace.xl),
                    decoration: BoxDecoration(
                      color: AppColors.closed,
                      borderRadius: BorderRadius.circular(AppRadius.card),
                    ),
                    child: const Icon(Icons.delete_outline, color: Colors.white),
                  ),
                  child: _SavedCard(
                    item: item,
                    title: names[item.id] ?? item.title,
                    opening: openingId == item.id,
                    onTap: openingId == null ? () => open(item) : null,
                    onRemove: () => confirmRemove(item),
                  ),
                ),
                const SizedBox(height: AppSpace.md),
              ],
              const SizedBox(height: AppSpace.md),
            ],
          if (items?.isNotEmpty == true) const SourceAttribution(),
        ],
      ),
    );
  }
}

class _SavedCard extends StatelessWidget {
  final SavedItem item;
  final String title;
  final bool opening;
  final VoidCallback? onTap;
  final VoidCallback onRemove;
  const _SavedCard({required this.item, required this.title, required this.opening, required this.onTap, required this.onRemove});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final tour = item.kind == 'tour';
    final d = item.savedAt.toLocal();
    final stops = tour ? (item.snapshot['stops'] as List? ?? const []).length : 0;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.xs, AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: tour ? AppColors.lagoonSoft : AppColors.terracottaSoft,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: opening
                    ? const Padding(padding: EdgeInsets.all(14), child: CircularProgressIndicator(strokeWidth: 2))
                    : Icon(tour ? Icons.route : Icons.place, color: tour ? AppColors.lagoon : AppColors.terracotta),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 2),
                    Text(
                      [if (tour) '$stops điểm dừng', 'Lưu ngày ${d.day}/${d.month}/${d.year}'].join(' · '),
                      style: t.bodySmall,
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Bỏ lưu',
                icon: const Icon(Icons.bookmark_remove_outlined, color: AppColors.muted),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
