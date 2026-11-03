import 'package:flutter/material.dart';

class InfoValue extends StatelessWidget {
  final String label;
  final String? value;
  const InfoValue(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Text(
      '$label: ${value == null || value!.trim().isEmpty ? 'chưa có thông tin' : value}',
    ),
  );
}
