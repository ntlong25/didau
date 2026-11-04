import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Required data attribution (Goong, OpenStreetMap ODbL). Shown quietly at the
/// bottom of any screen that displays provider data.
class SourceAttribution extends StatelessWidget {
  /// Optional source link shown together with the attribution as one footer.
  final Widget? link;
  const SourceAttribution({super.key, this.link});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpace.lg),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ?link,
        Text(
          'Dữ liệu địa điểm: Goong · © OpenStreetMap contributors',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}
