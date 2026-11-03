import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../widgets/info_value.dart';
import '../../widgets/google_attribution.dart';
import '../../widgets/external_link.dart';
import '../saved/save_button.dart';

class PlaceDetailScreen extends StatelessWidget {
  final Place place;
  final bool offline;
  const PlaceDetailScreen({
    super.key,
    required this.place,
    this.offline = false,
  });
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(place.name)),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const GoogleAttribution(),
        if (offline)
          const Text(
            'Đang offline • Chi tiết từ Google Maps không được lưu trên máy, hãy kết nối mạng để xem.',
          ),
        Text(place.name, style: Theme.of(context).textTheme.headlineSmall),
        SaveButton(
          kind: 'place',
          id: place.id,
          title: 'Địa điểm đã lưu',
          snapshot: place.json,
        ),
        InfoValue('Địa chỉ', place.address),
        InfoValue('Mức giá', place.price),
        InfoValue('Giờ mở cửa', place.openingHours?.join('\n')),
        InfoValue(
          'Trạng thái',
          place.openNow == null
              ? null
              : place.openNow!
              ? 'Đang mở'
              : 'Đang đóng',
        ),
        if (place.nextOpenAt != null) InfoValue('Mở lần tới', place.nextOpenAt),
        OutlinedButton.icon(
          onPressed: () => openExternal(context, place.mapsUri),
          icon: const Icon(Icons.open_in_new),
          label: const Text('Xem nguồn Google Maps'),
        ),
        FilledButton.icon(
          onPressed: () => openExternal(
            context,
            place.location == null
                ? place.mapsUri
                : 'https://www.google.com/maps/dir/?api=1&destination=${place.location!.lat},${place.location!.lng}&destination_place_id=${Uri.encodeComponent(place.id)}',
          ),
          icon: const Icon(Icons.directions),
          label: const Text('Chỉ đường'),
        ),
      ],
    ),
  );
}
