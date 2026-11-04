import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Screen title block: small eyebrow, large title, optional subtitle.
class PageHeader extends StatelessWidget {
  final String? eyebrow;
  final String title;
  final String? subtitle;
  const PageHeader({super.key, this.eyebrow, required this.title, this.subtitle});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.lg, bottom: AppSpace.xl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (eyebrow != null)
            Text(eyebrow!.toUpperCase(), style: t.labelMedium?.copyWith(color: AppColors.terracottaInk, letterSpacing: 1.2)),
          if (eyebrow != null) const SizedBox(height: AppSpace.sm),
          Text(title, style: t.displaySmall),
          if (subtitle != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(subtitle!, style: t.bodyLarge?.copyWith(color: AppColors.muted)),
          ],
        ],
      ),
    );
  }
}

/// Numbered step label used in forms.
class StepLabel extends StatelessWidget {
  final int? step;
  final String text;
  final String? hint;
  const StepLabel(this.text, {super.key, this.step, this.hint});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.md),
      child: Row(
        children: [
          if (step != null) ...[
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
              child: Text('$step', style: t.labelMedium?.copyWith(color: Colors.white)),
            ),
            const SizedBox(width: AppSpace.md),
          ],
          Expanded(child: Text(text, style: t.titleMedium)),
          if (hint != null)
            Flexible(child: Text(hint!, style: t.bodySmall, maxLines: 1, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

/// Small rounded label, e.g. distance or open state.
class Pill extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color color;
  final Color background;
  const Pill(this.text, {super.key, this.icon, this.color = AppColors.muted, this.background = AppColors.paper});
  factory Pill.openState(bool? open, {Key? key}) => open == null
      ? Pill('Giờ mở cửa: chưa rõ', key: key, icon: Icons.schedule)
      : open
      ? Pill('Đang mở', key: key, icon: Icons.circle, color: AppColors.open, background: const Color(0xffe3f2e8))
      : Pill('Đang đóng', key: key, icon: Icons.circle, color: AppColors.closed, background: const Color(0xfff8e1dc));
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: icon == Icons.circle ? 8 : 14, color: color),
          const SizedBox(width: 6),
        ],
        Text(text, style: Theme.of(context).textTheme.labelMedium?.copyWith(color: color, letterSpacing: 0)),
      ],
    ),
  );
}

/// Icon + label + value row. Missing values are shown, muted, as "Chưa có thông tin".
class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  const InfoRow(this.icon, this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final missing = value == null || value!.trim().isEmpty;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.lagoon),
          const SizedBox(width: AppSpace.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: t.labelMedium),
                const SizedBox(height: 2),
                Text(
                  missing ? 'Chưa có thông tin' : value!,
                  style: missing ? t.bodyMedium?.copyWith(color: AppColors.faint, fontStyle: FontStyle.italic) : t.bodyLarge,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// White rounded container for grouped content.
class Panel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(AppSpace.lg)});
  @override
  Widget build(BuildContext context) => Card(child: Padding(padding: padding, child: child));
}

/// Calm inline notice (offline, hints).
class Notice extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;
  final Color background;
  const Notice(this.text, {super.key, this.icon = Icons.info_outline, this.color = AppColors.lagoonDeep, this.background = AppColors.lagoonSoft});
  const Notice.offline(this.text, {super.key})
    : icon = Icons.cloud_off_outlined,
      color = const Color(0xff7a4b12),
      background = const Color(0xfffcefd2);
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AppSpace.md),
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(AppRadius.chip)),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: AppSpace.md),
        Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: color))),
      ],
    ),
  );
}

/// Large selectable tile with an icon, for the primary choices on a screen.
class ChoiceTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? caption;
  final bool selected;
  final bool multiSelect;
  final VoidCallback? onTap;
  const ChoiceTile({
    super.key,
    required this.icon,
    required this.label,
    this.caption,
    required this.selected,
    this.multiSelect = false,
    this.onTap,
  });
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      toggled: multiSelect ? selected : null,
      selected: !multiSelect ? selected : null,
      excludeSemantics: true,
      enabled: onTap != null,
      onTap: onTap,
      label: selected ? '$label, đã chọn' : label,
      child: Material(
        color: selected ? AppColors.lagoon : AppColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          side: BorderSide(color: selected ? AppColors.lagoon : AppColors.line),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadius.button),
          child: Padding(
            padding: caption == null
                ? const EdgeInsets.all(AppSpace.md)
                : const EdgeInsets.symmetric(horizontal: AppSpace.md, vertical: AppSpace.lg),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 26, color: selected ? Colors.white : AppColors.lagoon),
                const SizedBox(height: AppSpace.sm),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: t.labelLarge?.copyWith(color: selected ? Colors.white : AppColors.ink),
                  ),
                ),
                if (caption != null) ...[
                  const SizedBox(height: 2),
                  Text(caption!, maxLines: 1, overflow: TextOverflow.ellipsis, textAlign: TextAlign.center, style: t.bodySmall?.copyWith(color: selected ? Colors.white70 : AppColors.faint)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary action pinned above the bottom edge.
class BottomAction extends StatelessWidget {
  final Widget child;
  const BottomAction({super.key, required this.child});
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: const BoxDecoration(
      color: AppColors.paper,
      border: Border(top: BorderSide(color: AppColors.line)),
    ),
    child: SafeArea(
      top: false,
      child: Padding(padding: const EdgeInsets.fromLTRB(20, 12, 20, 12), child: child),
    ),
  );
}

/// Friendly empty / zero-result state.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  const EmptyState({super.key, required this.icon, required this.title, this.message, this.action});
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.xxl, horizontal: AppSpace.lg),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: const BoxDecoration(color: AppColors.terracottaSoft, shape: BoxShape.circle),
            child: Icon(icon, size: 32, color: AppColors.terracotta),
          ),
          const SizedBox(height: AppSpace.lg),
          Text(title, textAlign: TextAlign.center, style: t.titleLarge),
          if (message != null) ...[
            const SizedBox(height: AppSpace.sm),
            Text(message!, textAlign: TextAlign.center, style: t.bodyMedium),
          ],
          if (action != null) ...[const SizedBox(height: AppSpace.lg), action!],
        ],
      ),
    );
  }
}

/// Plain-language duration, e.g. 95 → "1 giờ 35 phút".
String formatMinutes(int minutes) {
  if (minutes < 60) return '$minutes phút';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h giờ' : '$h giờ $m phút';
}

String formatDistance(int meters) =>
    meters < 1000 ? '$meters m' : '${(meters / 1000).toStringAsFixed(1).replaceAll('.', ',')} km';
