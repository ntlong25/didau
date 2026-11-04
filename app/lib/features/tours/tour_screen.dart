import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/external_link.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';
import 'stop_screen.dart';
import '../saved/save_button.dart';

const interestLabels = {'History': 'Lịch sử', 'Food': 'Ẩm thực', 'Photo': 'Chụp ảnh'};

class TourScreen extends StatefulWidget {
  final Tour tour;
  final ApiClient? api;
  final Json? request;
  final bool offline;
  const TourScreen({
    super.key,
    required this.tour,
    this.api,
    this.request,
    this.offline = false,
  });
  @override
  State<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends State<TourScreen> {
  late Tour tour = widget.tour;
  bool busy = false;
  Object? error;
  Future<void> alternative() async {
    if (widget.api == null || widget.request == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final next = await widget.api!.tour({
        ...widget.request!,
        'variant': tour.variant + 1,
      });
      if (mounted) setState(() => tour = next);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final interests = (tour.json['interests'] as List? ?? const []).map((i) => interestLabels[i] ?? '$i').join(' · ');
    final canReroll = !widget.offline && widget.request != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Lộ trình của bạn'),
        actions: [
          SaveButton(
            kind: 'tour',
            id: tour.id,
            title: 'Tour ${cityNames[tour.cityId] ?? tour.cityId}',
            snapshot: tour.json,
            compact: true,
          ),
          const SizedBox(width: AppSpace.sm),
        ],
      ),
      body: ListView(
        padding: AppSpace.page,
        children: [
          _Summary(
            city: cityNames[tour.cityId] ?? tour.cityId,
            stops: tour.stops.length,
            minutes: tour.totalMinutes,
            interests: interests,
          ),
          const SizedBox(height: AppSpace.lg),
          if (widget.offline) ...[
            const Notice.offline('Bạn đang offline. Lời dẫn vẫn xem được; tên và chi tiết địa điểm cần kết nối mạng.'),
            const SizedBox(height: AppSpace.lg),
          ],
          if (error != null) ErrorRetry(error!, alternative),
          if (tour.json['start'] == 'UserLocation')
            const _TimelineRow(
              marker: _Marker(icon: Icons.my_location),
              child: Padding(
                padding: EdgeInsets.only(bottom: AppSpace.sm),
                child: Text('Xuất phát từ vị trí của bạn'),
              ),
            ),
          for (final (i, stop) in tour.stops.indexed) ...[
            for (final leg in tour.legs.where((l) => l['toOrder'] == stop['order']))
              _TimelineRow(marker: const _Marker.line(), child: _LegChip(leg: leg)),
            _TimelineRow(
              marker: _Marker(number: '${stop['order']}'),
              last: i == tour.stops.length - 1,
              child: _StopCard(
                stop: stop,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => StopScreen(stop: stop, offline: widget.offline)),
                ),
              ),
            ),
          ],
          const SourceAttribution(),
        ],
      ),
      bottomNavigationBar: canReroll
          ? BottomAction(
              child: OutlinedButton.icon(
                onPressed: busy ? null : alternative,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.shuffle),
                label: Text(busy ? 'Đang tạo phương án khác…' : 'Đổi lộ trình khác'),
              ),
            )
          : null,
    );
  }
}

class _Summary extends StatelessWidget {
  final String city, interests;
  final int stops, minutes;
  const _Summary({required this.city, required this.stops, required this.minutes, required this.interests});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    Widget stat(String value, String label, {String? note}) => Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: t.headlineSmall?.copyWith(color: Colors.white)),
          Text(label, style: t.bodySmall?.copyWith(color: Colors.white70)),
          if (note != null) ...[
            const SizedBox(height: AppSpace.xs),
            Text(note, style: t.bodySmall?.copyWith(color: Colors.white)),
          ],
        ],
      ),
    );
    return Container(
      padding: const EdgeInsets.all(AppSpace.xl),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.card + 4),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.lagoon, AppColors.lagoonDeep],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(city.toUpperCase(), style: t.labelMedium?.copyWith(color: AppColors.sunLight, letterSpacing: 1.4)),
          const SizedBox(height: AppSpace.xs),
          Text(interests.isEmpty ? 'Hành trình khám phá' : interests, style: t.titleLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: AppSpace.lg),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              stat('$stops', 'điểm dừng'),
              stat(formatMinutes(minutes), 'tổng thời gian', note: 'Thời gian gồm tham quan và di chuyển ước tính.'),
            ],
          ),
        ],
      ),
    );
  }
}

/// Left rail (marker + connecting line) and content.
class _TimelineRow extends StatelessWidget {
  final Widget marker;
  final Widget child;
  final bool last;
  const _TimelineRow({required this.marker, required this.child, this.last = false});
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: 40,
          child: Stack(
            alignment: Alignment.topCenter,
            children: [
              if (!last) Positioned.fill(child: Center(child: Container(width: 2, color: AppColors.line))),
              marker,
            ],
          ),
        ),
        const SizedBox(width: AppSpace.md),
        Expanded(child: child),
      ],
    ),
  );
}

class _Marker extends StatelessWidget {
  final String? number;
  final IconData? icon;
  const _Marker({this.number, this.icon});
  const _Marker.line() : number = null, icon = null;
  @override
  Widget build(BuildContext context) {
    if (number == null && icon == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: AppSpace.md),
      width: 32,
      height: 32,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: number != null ? AppColors.terracottaInk : AppColors.lagoon,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.paper, width: 3),
      ),
      child: number != null
          ? Text(number!, style: Theme.of(context).textTheme.labelLarge?.copyWith(color: Colors.white))
          : Icon(icon, size: 16, color: Colors.white),
    );
  }
}

class _LegChip extends StatelessWidget {
  final Json leg;
  const _LegChip({required this.leg});
  @override
  Widget build(BuildContext context) {
    final walk = leg['mode'] == 'Walk';
    final url = leg['directionsUrl'] as String?;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.sm),
      child: Row(
        children: [
          Icon(walk ? Icons.directions_walk : Icons.two_wheeler, size: 18, color: AppColors.muted),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Text(
              '${walk ? 'Đi bộ' : 'Xe máy / taxi'} · ${formatMinutes(leg['minutes'] as int)} · ${formatDistance(leg['distanceMeters'] as int)}',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          if (url != null)
            TextButton(onPressed: () => openExternal(context, url), child: const Text('Chỉ đường')),
        ],
      ),
    );
  }
}

class _StopCard extends StatelessWidget {
  final Json stop;
  final VoidCallback onTap;
  const _StopCard({required this.stop, required this.onTap});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final place = Place.fromJson(stop['place']);
    final narration = (stop['narration'] as List? ?? const []).cast<Json>();
    final teaser = narration.isEmpty ? null : narration.first['text'] as String?;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.sm),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(AppSpace.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(place.name, style: t.titleLarge)),
                    const Icon(Icons.chevron_right, color: AppColors.faintDecor),
                  ],
                ),
                const SizedBox(height: AppSpace.sm),
                Pill('Tham quan ${formatMinutes(stop['stayMinutes'] as int)}', icon: Icons.hourglass_bottom),
                if (teaser != null) ...[
                  const SizedBox(height: AppSpace.md),
                  Text(teaser, style: t.bodyMedium, maxLines: 3, overflow: TextOverflow.ellipsis),
                ],
                if (narration.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.sm),
                  Row(
                    children: [
                      Text('Nghe hướng dẫn viên kể', style: t.labelLarge?.copyWith(color: AppColors.terracottaInk)),
                      const SizedBox(width: AppSpace.xs),
                      const Icon(Icons.arrow_forward, size: 16, color: AppColors.terracotta),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
