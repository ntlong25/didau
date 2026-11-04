import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ErrorRetry extends StatelessWidget {
  final Object error;
  final VoidCallback onRetry;
  const ErrorRetry(this.error, this.onRetry, {super.key});
  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.symmetric(vertical: AppSpace.md),
    padding: const EdgeInsets.fromLTRB(AppSpace.lg, AppSpace.md, AppSpace.sm, AppSpace.md),
    decoration: BoxDecoration(
      color: AppColors.terracottaSoft,
      borderRadius: BorderRadius.circular(AppRadius.chip),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.closed),
        const SizedBox(width: AppSpace.md),
        Expanded(
          child: Text(
            error.toString(),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.ink),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Thử lại')),
      ],
    ),
  );
}
