import 'package:flutter/material.dart';
import 'ui.dart';

/// Legacy alias kept for callers; renders an [InfoRow] with a neutral icon.
class InfoValue extends StatelessWidget {
  final String label;
  final String? value;
  const InfoValue(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) => InfoRow(Icons.info_outline, label, value);
}
