import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/google_attribution.dart';

class LocationPicker extends StatefulWidget {
  final ApiClient api;
  final ValueChanged<GeoPoint> onSelected;
  const LocationPicker({
    super.key,
    required this.api,
    required this.onSelected,
  });
  @override
  State<LocationPicker> createState() => _LocationPickerState();
}

class _LocationPickerState extends State<LocationPicker> {
  final query = TextEditingController();
  List<City>? cities;
  String? city;
  List<Json> results = [];
  Object? error;
  bool busy = false;
  String? selected;
  @override
  void initState() {
    super.initState();
    loadCities();
  }

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> loadCities() async {
    try {
      final data = await widget.api.cities();
      if (mounted) {
        setState(() {
          cities = data;
          city = data.first.id;
          error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = e);
    }
  }

  Future<void> locate() async {
    setState(() {
      busy = true;
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
          'Chưa có quyền vị trí. Bạn có thể chọn thành phố và tìm địa chỉ bên dưới.',
        );
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 12),
        ),
      );
      if (mounted) {
        setState(() => selected = 'Vị trí hiện tại');
        widget.onSelected(GeoPoint(p.latitude, p.longitude));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => error = e is ApiException
              ? e
              : const ApiException(
                  'Không lấy được vị trí. Hãy tìm địa chỉ bên dưới.',
                ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> search() async {
    if (city == null) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final data = await widget.api.geocode(city!, query.text.trim());
      if (mounted) setState(() => results = data);
    } catch (e) {
      if (mounted) setState(() => error = e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      OutlinedButton.icon(
        onPressed: busy ? null : locate,
        icon: const Icon(Icons.my_location),
        label: const Text('Dùng vị trí hiện tại'),
      ),
      if (selected != null)
        Text(
          'Đã chọn: $selected',
          style: TextStyle(color: Theme.of(context).colorScheme.primary),
        ),
      if (cities != null)
        DropdownButtonFormField<String>(
          initialValue: city,
          decoration: const InputDecoration(labelText: 'Hoặc chọn thành phố'),
          items: cities!
              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
              .toList(),
          onChanged: busy
              ? null
              : (v) => setState(() {
                  city = v;
                  results = [];
                }),
        ),
      TextField(
        controller: query,
        decoration: const InputDecoration(
          labelText: 'Địa chỉ / khu vực',
          hintText: 'Ví dụ: Hồ Hoàn Kiếm',
        ),
        onSubmitted: (_) => search(),
      ),
      TextButton.icon(
        onPressed: busy || city == null ? null : search,
        icon: const Icon(Icons.search),
        label: const Text('Tìm khu vực'),
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null)
        ErrorRetry(error!, cities == null ? loadCities : search),
      if (results.isNotEmpty) const GoogleAttribution(),
      ...results.map(
        (area) => ListTile(
          title: Text(area['label']),
          trailing: const Icon(Icons.chevron_right),
          onTap: () {
            widget.onSelected(GeoPoint.fromJson(area['location']));
            setState(() {
              selected = area['label'];
              results = [];
            });
          },
        ),
      ),
    ],
  );
}
