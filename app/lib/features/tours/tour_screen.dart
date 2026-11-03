import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/external_link.dart';
import '../../widgets/google_attribution.dart';
import 'stop_screen.dart';
import '../saved/save_button.dart';

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
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Hành trình của bạn')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GoogleAttribution(),
        Text(
          '${tour.stops.length} điểm dừng • ${tour.totalMinutes} phút',
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const Text('Thời gian gồm tham quan và di chuyển ước tính.'),
        SaveButton(
          kind: 'tour',
          id: tour.id,
          title: 'Tour ${cityNames[tour.cityId] ?? tour.cityId}',
          snapshot: tour.json,
        ),
        if (widget.offline)
          const Text(
            'Đang offline • Lời dẫn tour vẫn xem được; tên và chi tiết địa điểm cần kết nối mạng.',
          ),
        if (tour.json['start'] == 'UserLocation')
          const Text('Xuất phát từ vị trí của bạn.'),
        const SizedBox(height: 16),
        for (final stop in tour.stops) ...[
          for (final leg in tour.legs.where(
            (l) => l['toOrder'] == stop['order'],
          ))
            Card(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: ListTile(
                leading: Icon(
                  leg['mode'] == 'Walk'
                      ? Icons.directions_walk
                      : Icons.local_taxi_outlined,
                ),
                title: Text(
                  '${leg['mode'] == 'Walk' ? 'Đi bộ' : 'Xe máy / taxi'} • ${leg['minutes']} phút',
                ),
                subtitle: Text('${leg['distanceMeters']} m • ước tính'),
                trailing: IconButton(
                  tooltip: 'Chỉ đường',
                  icon: const Icon(Icons.directions),
                  onPressed: () => openExternal(context, leg['directionsUrl']),
                ),
              ),
            ),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(16),
              leading: CircleAvatar(child: Text('${stop['order']}')),
              title: Text(Place.fromJson(stop['place']).name),
              subtitle: Text('Tham quan ${stop['stayMinutes']} phút'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      StopScreen(stop: stop, offline: widget.offline),
                ),
              ),
            ),
          ),
        ],
        if (!widget.offline && widget.request != null)
          OutlinedButton.icon(
            onPressed: busy ? null : alternative,
            icon: const Icon(Icons.shuffle),
            label: Text(busy ? 'Đang tạo…' : 'Phương án khác'),
          ),
        if (busy) const LinearProgressIndicator(),
        if (error != null) ErrorRetry(error!, alternative),
      ],
    ),
  );
}
