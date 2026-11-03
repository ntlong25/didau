import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/google_attribution.dart';
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
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (areas.isNotEmpty) const GoogleAttribution(),
      Text(
        'Một hành trình của riêng bạn',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text('Chọn nơi đến, thời gian và điều bạn muốn khám phá.'),
      const SizedBox(height: 24),
      if (cities != null)
        DropdownButtonFormField<String>(
          initialValue: city,
          decoration: const InputDecoration(labelText: 'Thành phố'),
          items: cities!
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: busy
              ? null
              : (v) {
                  setState(() => city = v);
                  loadAreas();
                },
        ),
      if (loadingAreas) const LinearProgressIndicator(),
      if (areaError != null) ErrorRetry(areaError!, loadAreas),
      DropdownButtonFormField<String>(
        key: ValueKey('$city:$area:${areas.length}'),
        initialValue: area ?? '',
        isExpanded: true,
        decoration: const InputDecoration(labelText: 'Khu vực (tùy chọn)'),
        items: [
          const DropdownMenuItem(value: '', child: Text('Toàn thành phố')),
          ...areas.map(
            (a) => DropdownMenuItem<String>(
              value: a['id'],
              child: Text(a['name'], overflow: TextOverflow.ellipsis),
            ),
          ),
        ],
        onChanged: busy
            ? null
            : (v) => setState(() => area = v == '' ? null : v),
      ),
      const SizedBox(height: 20),
      const Text('Bạn có bao nhiêu thời gian?'),
      Wrap(
        spacing: 8,
        children:
            const {
                  'OneHour': '1 giờ',
                  'HalfDay': 'Nửa ngày',
                  'FullDay': 'Cả ngày',
                }.entries
                .map(
                  (e) => ChoiceChip(
                    label: Text(e.value),
                    selected: duration == e.key,
                    onSelected: busy
                        ? null
                        : (_) => setState(() => duration = e.key),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 16),
      const Text('Bạn thích khám phá gì?'),
      Wrap(
        spacing: 8,
        children:
            const {'History': 'Lịch sử', 'Food': 'Ẩm thực', 'Photo': 'Chụp ảnh'}
                .entries
                .map(
                  (e) => FilterChip(
                    label: Text(e.value),
                    selected: interests.contains(e.key),
                    onSelected: busy
                        ? null
                        : (v) => setState(() {
                            v ? interests.add(e.key) : interests.remove(e.key);
                          }),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 16),
      OutlinedButton.icon(
        onPressed: busy || locating ? null : locate,
        icon: const Icon(Icons.my_location),
        label: Text(
          locating
              ? 'Đang lấy vị trí…'
              : location == null
              ? 'Bắt đầu từ vị trí của tôi (tùy chọn)'
              : 'Đã chọn vị trí hiện tại',
        ),
      ),
      if (location != null)
        TextButton(
          onPressed: busy ? null : () => setState(() => location = null),
          child: const Text('Bắt đầu tại điểm đầu tiên'),
        ),
      const SizedBox(height: 16),
      FilledButton.icon(
        onPressed: busy || locating || city == null || interests.isEmpty
            ? null
            : create,
        icon: const Icon(Icons.route),
        label: Text(busy ? 'Đang tạo tour…' : 'Tạo tour'),
      ),
      if (busy)
        const Padding(
          padding: EdgeInsets.all(12),
          child: Column(
            children: [
              LinearProgressIndicator(),
              Text(
                'Đang tìm điểm đến và kiểm tra nguồn. Tối đa khoảng 20 giây.',
              ),
            ],
          ),
        ),
      if (error != null) ErrorRetry(error!, cities == null ? load : create),
    ],
  );
}
