import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/external_link.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';
import '../saved/save_button.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Place place;
  final bool offline;
  /// Optional context from the list that opened this screen.
  final String? category;
  final int? distanceMeters;
  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.offline = false,
    this.category,
    this.distanceMeters,
  });

  String get directionsUrl => place.location == null
      ? place.mapsUri
      : 'https://www.google.com/maps/dir/?api=1&destination=${place.location!.lat},${place.location!.lng}';

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        actions: [
          SaveButton(kind: 'place', id: place.id, title: 'Địa điểm đã lưu', snapshot: place.json, compact: true),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: ListView(
        padding: AppSpace.page,
        children: [
          Text(place.name, style: t.displaySmall),
          const SizedBox(height: AppSpace.md),
          Wrap(
            spacing: AppSpace.sm,
            runSpacing: AppSpace.sm,
            children: [
              if (category != null) Pill(category!, icon: Icons.sell_outlined, background: AppColors.lagoonSoft, color: AppColors.lagoonDeep),
              if (distanceMeters != null) Pill(formatDistance(distanceMeters!), icon: Icons.directions_walk, background: AppColors.lagoonSoft, color: AppColors.lagoonDeep),
              if (place.openNow == true)
                const Pill('Đang mở cửa', icon: Icons.circle, color: AppColors.open, background: Color(0xffe3f2e8)),
              if (place.openNow == false)
                const Pill('Đã đóng cửa', icon: Icons.circle, color: AppColors.closed, background: Color(0xfff8e1dc)),
              if (place.price != null) Pill(place.price!, icon: Icons.payments_outlined, background: AppColors.lagoonSoft, color: AppColors.lagoonDeep),
            ],
          ),
          const SizedBox(height: AppSpace.xl),
          if (offline) ...[
            const Notice.offline('Bạn đang offline. Chi tiết địa điểm không được lưu trên máy, hãy kết nối mạng để xem.'),
            const SizedBox(height: AppSpace.lg),
          ],
          Panel(
            padding: const EdgeInsets.symmetric(horizontal: AppSpace.lg, vertical: AppSpace.xs),
            child: Column(
              children: [
                InfoRow(Icons.place_outlined, 'Địa chỉ', place.address),
                const Divider(),
                InfoRow(Icons.schedule, 'Giờ mở cửa', place.openingHours?.join('\n')),
                if (place.nextOpenAt != null) ...[
                  const Divider(),
                  InfoRow(Icons.event_available_outlined, 'Mở lần tới', place.nextOpenAt),
                ],
                const Divider(),
                InfoRow(Icons.payments_outlined, 'Mức giá', place.price),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.xl),
          SourceAttribution(
            link: TextButton.icon(
              onPressed: () => openExternal(context, place.mapsUri),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: const Text('Xem nguồn dữ liệu'),
            ),
          ),
        ],
      ),
      bottomNavigationBar: BottomAction(
        child: FilledButton.icon(
          onPressed: () => openExternal(context, directionsUrl),
          icon: const Icon(Icons.directions),
          label: const Text('Chỉ đường bằng Google Maps'),
        ),
      ),
    );
  }
}
