import 'package:flutter/material.dart';
import '../../api/models.dart';
import '../../theme/app_theme.dart';
import 'saved_store.dart';

class SaveButton extends StatefulWidget {
  final String kind, id, title;
  final Json snapshot;
  /// Icon-only variant for app bars.
  final bool compact;
  const SaveButton({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.snapshot,
    this.compact = false,
  });
  @override
  State<SaveButton> createState() => _SaveButtonState();
}

class _SaveButtonState extends State<SaveButton> {
  final store = SavedStore();
  bool saved = false, busy = false;
  @override
  void initState() {
    super.initState();
    refresh();
  }

  @override
  void didUpdateWidget(covariant SaveButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.id != widget.id) refresh();
  }

  Future<void> refresh() async {
    final items = await store.list();
    if (mounted) {
      setState(
        () => saved = items.any((i) => i.id == '${widget.kind}:${widget.id}'),
      );
    }
  }

  Future<void> toggle({bool undo = false}) async {
    setState(() => busy = true);
    try {
      if (saved) {
        await store.remove('${widget.kind}:${widget.id}');
      } else {
        await store.save(widget.kind, widget.id, widget.title, widget.snapshot);
      }
      await refresh();
      if (mounted && !undo) {
        final messenger = ScaffoldMessenger.of(context);
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            // Auto-dismiss even with an action (also under accessible navigation).
            persist: false,
            content: Text(saved ? 'Đã lưu' : 'Đã bỏ lưu'),
            action: SnackBarAction(
              label: 'Hoàn tác',
              onPressed: () {
                if (mounted) toggle(undo: true);
              },
            ),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lưu. Bộ nhớ thiết bị có thể đã đầy hoặc bị chặn.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => widget.compact
      ? IconButton(
          tooltip: saved ? 'Bỏ lưu' : 'Lưu',
          onPressed: busy ? null : toggle,
          isSelected: saved,
          color: AppColors.lagoon,
          selectedIcon: const Icon(Icons.bookmark, color: AppColors.lagoon),
          icon: const Icon(Icons.bookmark_border, color: AppColors.lagoon),
        )
      : OutlinedButton.icon(
          onPressed: busy ? null : toggle,
          icon: Icon(saved ? Icons.bookmark : Icons.bookmark_border, color: AppColors.lagoon),
          label: Text(saved ? 'Đã lưu' : 'Lưu'),
        );
}
