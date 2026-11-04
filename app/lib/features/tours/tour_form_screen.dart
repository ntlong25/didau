import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../location/current_location.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../theme/app_theme.dart';
import '../../widgets/source_attribution.dart';
import '../../widgets/ui.dart';
import 'tour_screen.dart';

class TourFormScreen extends StatefulWidget {
  final ApiClient api;
  const TourFormScreen({super.key, required this.api});
  @override
  State<TourFormScreen> createState() => _TourFormScreenState();
}

class _TourFormScreenState extends State<TourFormScreen> {
  List<City>? cities;
  List<Json> areas = [];
  String? city, area;
  String duration = 'HalfDay';
  final interests = <String>{'History'};
  bool busy = false, locating = false, loadingAreas = false;
  GeoPoint? location;
  Object? error, areaError;
  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    try {
      final data = await widget.api.cities();
      if (mounted) {
        setState(() {
          cities = data;
          city = data.first.id;
          error = null;
        });
        await loadAreas();
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> loadAreas() async {
    final selectedCity = city;
    if (selectedCity == null) return;
    setState(() {
      loadingAreas = true;
      areaError = null;
      areas = [];
      area = null;
    });
    try {
      final data = await widget.api.areas(selectedCity);
      if (mounted && city == selectedCity) setState(() => areas = data);
    } catch (e) {
      if (mounted && city == selectedCity) setState(() => areaError = e);
    } finally {
      if (mounted && city == selectedCity) setState(() => loadingAreas = false);
    }
  }

  Future<void> locate() async {
    setState(() {
      locating = true;
      error = null;
    });
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw const ApiException(
          'Chưa có quyền vị trí. Tour sẽ bắt đầu tại điểm dừng đầu tiên.',
        );
      }
      final p = await currentLocation();
      if (mounted) setState(() => location = GeoPoint(p.latitude, p.longitude));
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e
              : const ApiException(
                  'Không lấy được vị trí. Tour vẫn có thể bắt đầu tại điểm đầu tiên.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => locating = false);
    }
  }

  Future<void> create() async {
    if (city == null || interests.isEmpty) return;
    setState(() {
      busy = true;
      error = null;
    });
    final request = <String, dynamic>{
      'cityId': city,
      'areaPlaceId': area,
      'duration': duration,
      'interests': interests.toList(),
      'variant': 0,
      'userLocation': location?.toJson(),
    };
    try {
      final tour = await widget.api.tour(request);
      if (mounted) {
        await Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) =>
                TourScreen(tour: tour, api: widget.api, request: request),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  static const _durations = [
    ('OneHour', '1 giờ', 'Dạo nhanh', Icons.timer_outlined),
    ('HalfDay', 'Nửa ngày', '≈ 4 giờ', Icons.wb_twilight_outlined),
    ('FullDay', 'Cả ngày', '≈ 8 giờ', Icons.wb_sunny_outlined),
  ];
  static const _interests = [
    ('History', 'Lịch sử', Icons.account_balance_outlined),
    ('Food', 'Ẩm thực', Icons.ramen_dining_outlined),
    ('Photo', 'Chụp ảnh', Icons.photo_camera_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: AppSpace.page.copyWith(bottom: 96),
            children: [
              const PageHeader(
                eyebrow: 'Hướng dẫn viên riêng',
                title: 'Lên lộ trình\ntrong 3 bước',
                subtitle: 'Chọn nơi đến, thời gian và điều bạn muốn khám phá.',
              ),
              const StepLabel('Bạn muốn đi đâu?', step: 1),
              if (cities == null && error == null) const LinearProgressIndicator(minHeight: 3),
              if (cities != null)
                Wrap(
                  spacing: AppSpace.sm,
                  runSpacing: AppSpace.sm,
                  children: [
                    for (final c in cities!)
                      ChoiceChip(
                        label: Text(c.name),
                        selected: city == c.id,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: busy
                            ? null
                            : (_) {
                                setState(() => city = c.id);
                                loadAreas();
                              },
                      ),
                  ],
                ),
              const SizedBox(height: AppSpace.md),
              DropdownButtonFormField<String>(
                key: ValueKey('$city:$area:${areas.length}'),
                initialValue: area ?? '',
                isExpanded: true,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.place_outlined),
                  labelText: 'Khu vực (không bắt buộc)',
                  suffixIcon: loadingAreas
                      ? const Padding(
                          padding: EdgeInsets.all(14),
                          child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                        )
                      : null,
                ),
                items: [
                  const DropdownMenuItem(value: '', child: Text('Khắp thành phố')),
                  ...areas.map(
                    (a) => DropdownMenuItem<String>(
                      value: a['id'],
                      child: Text(a['name'], overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: busy ? null : (v) => setState(() => area = v == '' ? null : v),
              ),
              if (areaError != null) ErrorRetry(areaError!, loadAreas),
              const SizedBox(height: AppSpace.xl),
              const StepLabel('Bạn có bao nhiêu thời gian?', step: 2),
              Row(
                children: [
                  for (final (i, (value, label, caption, icon)) in _durations.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: ChoiceTile(
                        icon: icon,
                        label: label,
                        caption: caption,
                        selected: duration == value,
                        onTap: busy ? null : () => setState(() => duration = value),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              const StepLabel('Bạn thích khám phá gì?', step: 3, hint: 'Chọn một hoặc nhiều'),
              Row(
                children: [
                  for (final (i, (value, label, icon)) in _interests.indexed) ...[
                    if (i > 0) const SizedBox(width: AppSpace.sm),
                    Expanded(
                      child: ChoiceTile(
                        icon: icon,
                        label: label,
                        multiSelect: true,
                        selected: interests.contains(value),
                        onTap: busy
                            ? null
                            : () => setState(() {
                                interests.contains(value) ? interests.remove(value) : interests.add(value);
                              }),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: AppSpace.xl),
              const StepLabel('Điểm xuất phát (tuỳ chọn)', step: 4),
              Panel(
                padding: const EdgeInsets.symmetric(horizontal: AppSpace.sm, vertical: AppSpace.xs),
                child: SwitchListTile(
                  value: location != null,
                  onChanged: busy || locating
                      ? null
                      : (v) => v ? locate() : setState(() => location = null),
                  secondary: locating
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.my_location, color: AppColors.lagoon),
                  title: Text('Xuất phát từ chỗ tôi', style: t.titleMedium),
                  subtitle: Text(
                    location == null ? 'Tắt: bắt đầu tại điểm dừng đầu tiên' : 'Đã lấy vị trí hiện tại',
                    style: t.bodySmall,
                  ),
                ),
              ),
              if (error != null) ErrorRetry(error!, cities == null ? load : create),
              if (areas.isNotEmpty) const SourceAttribution(),
            ],
          ),
        ),
        BottomAction(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!busy && interests.isEmpty) ...[
                Text('Chọn ít nhất một sở thích', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: AppSpace.sm),
              ],
              if (busy) ...[
                Text('Đang chọn điểm đến và kiểm tra nguồn, có thể mất khoảng 20 giây…', style: t.bodySmall?.copyWith(color: AppColors.muted)),
                const SizedBox(height: AppSpace.sm),
              ],
              FilledButton.icon(
                onPressed: busy || locating || city == null || interests.isEmpty ? null : create,
                icon: busy
                    ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.auto_awesome),
                label: Text(busy ? 'Đang tạo lộ trình…' : 'Tạo lộ trình'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
