import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/external_link.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';

const _sections = {
  'History': ('Lịch sử & bối cảnh', Icons.history_edu_outlined),
  'Trivia': ('Điều thú vị', Icons.lightbulb_outline),
  'Tips': ('Mẹo tham quan', Icons.tips_and_updates_outlined),
};

class StopScreen extends StatelessWidget {
  final Json stop;
  final bool offline;
  const StopScreen({super.key, required this.stop, this.offline = false});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final place = Place.fromJson(stop['place']);
    final narration = (stop['narration'] as List).cast<Json>();
    return Scaffold(
      appBar: AppBar(title: Text('Điểm dừng ${stop['order']}')),
      body: ListView(
        padding: AppSpace.page,
        children: [
          Text(place.name, style: t.displaySmall),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            children: [
              Pill('Dành khoảng ${formatMinutes(stop['stayMinutes'] as int)}', icon: Icons.hourglass_bottom),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (offline) ...[
            const Notice.offline('Bạn đang offline. Địa chỉ, giờ và giá cần kết nối mạng để xem.'),
            const SizedBox(height: AppSpace.lg),
          ],
          if (narration.isEmpty)
            const Notice('Chưa có nguồn đáng tin cho lời giới thiệu ở điểm này, nên hướng dẫn viên xin phép im lặng.'),
          for (final section in narration) ...[
            _NarrationCard(section: section),
            const SizedBox(height: AppSpace.md),
          ],
          const SizedBox(height: AppSpace.md),
          Text('Thông tin địa điểm', style: t.titleMedium),
          const SizedBox(height: AppSpace.sm),
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
            child: Column(
              children: [
                InfoRow(Icons.place_outlined, 'Địa chỉ', place.address),
                const Divider(),
                InfoRow(Icons.schedule, 'Giờ mở cửa', place.openingHours?.join('\n')),
                const Divider(),
                InfoRow(Icons.payments_outlined, 'Mức giá', place.price),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.sm),
          TextButton.icon(
            onPressed: () => openExternal(context, place.mapsUri),
            icon: const Icon(Icons.open_in_new, size: 18),
            label: const Text('Xem nguồn dữ liệu'),
          ),
          const SourceAttribution(),
        ],
      ),
    );
  }
}

class _NarrationCard extends StatelessWidget {
  final Json section;
  const _NarrationCard({required this.section});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final (title, icon) = _sections[section['kind']] ?? ('Giới thiệu', Icons.notes);
    final sources = (section['sources'] as List? ?? const []).cast<Json>();
    return Panel(
      padding: const EdgeInsets.all(AppSpace.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(AppSpace.sm),
                decoration: BoxDecoration(color: AppColors.terracottaSoft, borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, size: 20, color: AppColors.terracotta),
              ),
              const SizedBox(width: AppSpace.md),
              Text(title, style: t.titleMedium),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          Text(section['text'], style: t.bodyLarge),
          if (sources.isNotEmpty) ...[
            const SizedBox(height: AppSpace.md),
            Wrap(
              spacing: AppSpace.sm,
              runSpacing: AppSpace.xs,
              children: [
                for (final source in sources)
                  ActionChip(
                    avatar: const Icon(Icons.menu_book_outlined, size: 16),
                    label: Text('Nguồn: ${source['title']}', overflow: TextOverflow.ellipsis),
                    onPressed: () => openExternal(context, source['url']),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
