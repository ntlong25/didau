import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';
import 'location_picker.dart';
import 'place_detail_screen.dart';

const _needs = [
  ('Coffee', 'Cà phê', Icons.local_cafe_outlined),
  ('Food', 'Quán ăn', Icons.ramen_dining_outlined),
  ('Breakfast', 'Ăn sáng', Icons.bakery_dining_outlined),
  ('Dinner', 'Ăn tối', Icons.dinner_dining_outlined),
];

class SuggestionsScreen extends StatefulWidget {
  final ApiClient api;
  const SuggestionsScreen({super.key, required this.api});
  @override
  State<SuggestionsScreen> createState() => _SuggestionsScreenState();
}

class _SuggestionsScreenState extends State<SuggestionsScreen> {
  GeoPoint? location;
  String need = 'Coffee';
  int radius = 2000;
  SuggestionResult? result;
  Object? error;
  bool busy = false;
  Future<void> search() async {
    if (location == null) return;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final data = await widget.api.suggestions(location!, need, radius);
      if (mounted) setState(() => result = data);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void pickNeed(String value) {
    setState(() {
      need = value;
      radius = 2000;
      result = null;
    });
    // Re-run straight away once a location is known: one tap instead of two.
    if (location != null) search();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: AppSpace.page,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpace.md),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: AppColors.terracottaInk, borderRadius: BorderRadius.circular(10)),
                child: const Icon(Icons.explore, color: Colors.white, size: 20),
              ),
              const SizedBox(width: AppSpace.sm),
              Text('Đi Đâu', style: t.titleMedium),
            ],
          ),
        ),
        const PageHeader(
          title: 'Hôm nay\nđi đâu nhỉ?',
          subtitle: 'Vài chỗ ngon gần bạn, chọn trong một chạm.',
        ),
        const StepLabel('Bạn đang ở đâu?', step: 1),
        LocationPicker(
          key: const ValueKey('suggestions-location-picker'),
          api: widget.api,
          onSelected: (p) {
            setState(() {
              location = p;
              radius = 2000;
              result = null;
            });
            search();
          },
        ),
        const SizedBox(height: AppSpace.xl),
        const StepLabel('Bạn đang thèm gì?', step: 2),
        LayoutBuilder(
          builder: (context, constraints) => GridView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: constraints.maxWidth < 340 ? 2 : 4,
              mainAxisSpacing: AppSpace.sm,
              crossAxisSpacing: AppSpace.sm,
              mainAxisExtent: 96,
            ),
            children: [
              for (final (value, label, icon) in _needs)
                ChoiceTile(icon: icon, label: label, selected: need == value, onTap: busy ? null : () => pickNeed(value)),
            ],
          ),
        ),
        const SizedBox(height: AppSpace.xl),
        if (location == null)
          const Notice('Chọn vị trí ở bước 1, gợi ý sẽ hiện ngay bên dưới.', icon: Icons.touch_app_outlined),
        if (busy) ...[
          const LinearProgressIndicator(minHeight: 3),
          const SizedBox(height: AppSpace.md),
          Text('Đang tìm quanh bạn…', style: t.bodyMedium),
        ],
        if (error != null) ErrorRetry(error!, search),
        if (result != null) ...[
          Row(
            children: [
              Expanded(child: Text('Gợi ý cho bạn', style: t.headlineSmall)),
              Text('trong ${formatDistance(radius)}', style: t.bodySmall),
            ],
          ),
          const SizedBox(height: AppSpace.md),
          if (result!.items.isEmpty)
            EmptyState(
              icon: Icons.travel_explore,
              title: 'Chưa thấy chỗ nào hợp',
              message: 'Thử nhu cầu khác hoặc mở rộng vùng tìm kiếm.',
              action: result!.canExpandRadius ? _expandButton() : null,
            ),
          for (final (i, s) in result!.items.indexed) ...[
            _SuggestionCard(
              rank: i + 1,
              suggestion: s,
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailScreen(
                    place: s.place,
                    category: _needs.firstWhere((n) => n.$1 == need).$2,
                    distanceMeters: s.distanceMeters,
                  ),
                ),
              ),
            ),
            const SizedBox(height: AppSpace.md),
          ],
          if (result!.items.isNotEmpty && result!.canExpandRadius) _expandButton(),
          const SourceAttribution(),
        ],
      ],
    );
  }

  Widget _expandButton() => OutlinedButton.icon(
    onPressed: busy
        ? null
        : () {
            radius = 5000;
            search();
          },
    icon: const Icon(Icons.zoom_out_map),
    label: const Text('Tìm rộng hơn, trong 5 km'),
  );
}

class _SuggestionCard extends StatelessWidget {
  final int rank;
  final Suggestion suggestion;
  final VoidCallback onTap;
  const _SuggestionCard({required this.rank, required this.suggestion, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final place = suggestion.place;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.lg),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: rank == 1 ? AppColors.terracottaInk : AppColors.paper,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '$rank',
                  style: t.titleMedium?.copyWith(color: rank == 1 ? Colors.white : AppColors.ink),
                ),
              ),
              const SizedBox(width: AppSpace.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(place.name, style: t.titleLarge),
                    const SizedBox(height: AppSpace.sm),
                    Wrap(
                      spacing: AppSpace.sm,
                      runSpacing: AppSpace.xs,
                      children: [
                        Pill(formatDistance(suggestion.distanceMeters), icon: Icons.directions_walk),
                        if (place.openNow != null) Pill.openState(place.openNow),
                        if (place.price != null) Pill(place.price!, icon: Icons.payments_outlined),
                      ],
                    ),
                    const SizedBox(height: AppSpace.sm),
                    Text(suggestion.reason, style: t.bodyMedium),
                    if (place.address != null) ...[
                      const SizedBox(height: AppSpace.xs),
                      Text(place.address!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: AppColors.faintDecor),
            ],
          ),
        ),
      ),
    );
  }
}
