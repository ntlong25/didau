import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../widgets/external_link.dart';
import '../../widgets/info_value.dart';
import '../../widgets/google_attribution.dart';

class StopScreen extends StatelessWidget {
  final Json stop;
  final bool offline;
  const StopScreen({super.key, required this.stop, this.offline = false});
  @override
  Widget build(BuildContext context) {
    final place = Place.fromJson(stop['place']);
    final narration = (stop['narration'] as List).cast<Json>();
    return Scaffold(
      appBar: AppBar(title: Text(place.name)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const GoogleAttribution(),
          Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
          Text('Dành khoảng ${stop['stayMinutes']} phút tại đây.'),
          if (offline)
            const Text(
              'Đang offline • Địa chỉ, giờ và giá từ Google Maps cần kết nối mạng để xem.',
            ),
          InfoValue('Địa chỉ', place.address),
          InfoValue('Giờ mở cửa', place.openingHours?.join('\n')),
          InfoValue('Mức giá', place.price),
          TextButton.icon(
            onPressed: () => openExternal(context, place.mapsUri),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Xem nguồn Google Maps'),
          ),
          if (narration.isEmpty)
            const Text('Lời giới thiệu: chưa có thông tin có nguồn phù hợp.'),
          for (final section in narration) ...[
            const SizedBox(height: 20),
            Text(
              const {
                    'History': 'Lịch sử / Bối cảnh',
                    'Trivia': 'Điều thú vị',
                    'Tips': 'Mẹo tham quan',
                  }[section['kind']] ??
                  '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(section['text']),
            for (final source in section['sources'])
              TextButton.icon(
                onPressed: () => openExternal(context, source['url']),
                icon: const Icon(Icons.link),
                label: Text(source['title']),
              ),
          ],
        ],
      ),
    );
  }
}
