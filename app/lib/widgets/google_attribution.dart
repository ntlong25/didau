import 'package:flutter/material.dart';

class GoogleAttribution extends StatelessWidget {
  const GoogleAttribution({super.key});
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 8),
    child: Text(
      'Google Maps',
      softWrap: false,
      style: TextStyle(
        fontFamily: 'RobotoLocal',
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: Color(0xff5e5e5e),
      ),
    ),
  );
}
