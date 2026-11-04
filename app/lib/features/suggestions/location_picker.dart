import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../location/current_location.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/ui.dart';

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
  // Collapses to a one-line summary once a location is chosen.
  bool editing = true;
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

  void choose(String label, GeoPoint point) {
    widget.onSelected(point);
    setState(() {
      selected = label;
      results = [];
      editing = false;
    });
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
      final p = await currentLocation();
      if (mounted) choose('Vị trí hiện tại', GeoPoint(p.latitude, p.longitude));
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
    if (city == null || query.text.trim().length < 2) return;
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
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (!editing && selected != null) {
      return Semantics(
        button: true,
        label: 'Đổi vị trí',
        child: Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => setState(() => editing = true),
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 64),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.sm, AppSpace.sm, AppSpace.sm),
                child: Row(
                  children: [
                    const Icon(Icons.place, color: AppColors.terracotta),
                    const SizedBox(width: AppSpace.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vị trí của bạn', style: t.labelMedium),
                          Text(selected!, style: t.titleMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    ),
                    TextButton(onPressed: () => setState(() => editing = true), child: const Text('Đổi')),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.tonalIcon(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.lagoonSoft,
              foregroundColor: AppColors.lagoonDeep,
            ),
            onPressed: busy ? null : locate,
            icon: const Icon(Icons.my_location),
            label: const Text('Dùng vị trí hiện tại'),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
            child: Row(
              children: [
                const Expanded(child: Divider()),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpace.md),
                    child: Text('hoặc tìm địa chỉ', style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const Expanded(child: Divider()),
              ],
            ),
          ),
          if (cities != null)
            SizedBox(
              height: 64,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  for (final c in cities!)
                    Padding(
                      padding: const EdgeInsets.only(right: AppSpace.sm),
                      child: ChoiceChip(
                        label: Text(c.name),
                        selected: city == c.id,
                        showCheckmark: true,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        materialTapTargetSize: MaterialTapTargetSize.padded,
                        onSelected: busy
                            ? null
                            : (_) => setState(() {
                                city = c.id;
                                results = [];
                              }),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpace.md),
          TextField(
            controller: query,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              labelText: 'Địa chỉ / khu vực',
              hintText: 'Ví dụ: Hồ Hoàn Kiếm, Chợ Bến Thành…',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: busy
                  ? const Padding(
                      padding: EdgeInsets.all(14),
                      child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)),
                    )
                  : IconButton(
                      tooltip: 'Tìm',
                      onPressed: city == null ? null : search,
                      icon: const Icon(Icons.arrow_forward),
                    ),
            ),
            onSubmitted: (_) => search(),
          ),
          if (error != null) ErrorRetry(error!, cities == null ? loadCities : search),
          if (results.isNotEmpty) ...[
            const SizedBox(height: AppSpace.sm),
            for (final area in results)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.place_outlined, color: AppColors.lagoon),
                title: Text(area['label'], style: t.bodyLarge),
                onTap: () => choose(area['label'], GeoPoint.fromJson(area['location'])),
              ),
          ],
        ],
      ),
    );
  }
}
