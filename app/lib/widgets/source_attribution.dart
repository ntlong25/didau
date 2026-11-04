import 'package:flutter/material.dart';

class SourceAttribution extends StatelessWidget {
  const SourceAttribution({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Dữ liệu địa điểm: Goong · © OpenStreetMap contributors',
      softWrap: true,
      style: TextStyle(
        fontFamily: 'RobotoLocal',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xff5e5e5e),
      ),
    ),
  );
}
