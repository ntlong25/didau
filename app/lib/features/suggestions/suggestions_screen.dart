import 'package:flutter/material.dart';
import '../../api/api_client.dart';
import '../../api/models.dart';
import '../../widgets/error_retry.dart';
import '../../widgets/info_value.dart';
import '../../widgets/google_attribution.dart';
import 'location_picker.dart';
import 'place_detail_screen.dart';

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

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(20),
    children: [
      if (result != null) const GoogleAttribution(),
      Text(
        'Hôm nay, đi đâu?',
        style: Theme.of(context).textTheme.headlineMedium,
      ),
      const Text('Tìm một chỗ gần bạn để dừng chân.'),
      const SizedBox(height: 16),
      LocationPicker(
        api: widget.api,
        onSelected: (p) => setState(() {
          location = p;
          radius = 2000;
          result = null;
        }),
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 8,
        children:
            const {
                  'Coffee': 'Cà phê',
                  'Food': 'Ăn uống',
                  'Breakfast': 'Ăn sáng',
                  'Dinner': 'Ăn tối',
                }.entries
                .map(
                  (e) => ChoiceChip(
                    label: Text(e.value),
                    selected: need == e.key,
                    onSelected: busy
                        ? null
                        : (_) => setState(() {
                            need = e.key;
                            radius = 2000;
                            result = null;
                          }),
                  ),
                )
                .toList(),
      ),
      const SizedBox(height: 12),
      FilledButton(
        onPressed: busy || location == null ? null : search,
        child: Text(busy ? 'Đang tìm…' : 'Gợi ý cho tôi'),
      ),
      if (busy) const LinearProgressIndicator(),
      if (error != null) ErrorRetry(error!, search),
      if (result != null && result!.items.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Chưa tìm thấy địa điểm phù hợp trong khu vực này.'),
        ),
      if (result != null)
        ...result!.items.map(
          (s) => Card(
            child: InkWell(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PlaceDetailScreen(place: s.place),
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.place.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${s.distanceMeters} m • ${s.place.openNow == true
                          ? 'Đang mở'
                          : s.place.openNow == false
                          ? 'Đang đóng'
                          : 'chưa có thông tin'}',
                    ),
                    Text(s.reason),
                    InfoValue('Địa chỉ', s.place.address),
                    InfoValue('Mức giá', s.place.price),
                    InfoValue('Giờ mở cửa', s.place.openingHours?.join('\n')),
                    if (s.place.nextOpenAt != null)
                      InfoValue('Mở lần tới', s.place.nextOpenAt),
                  ],
                ),
              ),
            ),
          ),
        ),
      if (result?.canExpandRadius == true)
        OutlinedButton(
          onPressed: busy
              ? null
              : () {
                  radius = 5000;
                  search();
                },
          child: const Text('Mở rộng bán kính lên 5 km'),
        ),
    ],
  );
}
