import 'package:flutter/material.dart';
import '../../api/models.dart';
import 'saved_store.dart';

class SaveButton extends StatefulWidget {
  final String kind, id, title;
  final Json snapshot;
  const SaveButton({
    super.key,
    required this.kind,
    required this.id,
    required this.title,
    required this.snapshot,
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

  Future<void> toggle() async {
    setState(() => busy = true);
    try {
      if (saved) {
        await store.remove('${widget.kind}:${widget.id}');
      } else {
        await store.save(widget.kind, widget.id, widget.title, widget.snapshot);
      }
      await refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Không thể lưu. Bộ nhớ trình duyệt có thể đã đầy hoặc bị chặn.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: busy ? null : toggle,
    icon: Icon(saved ? Icons.bookmark : Icons.bookmark_outline),
    label: Text(saved ? 'Đã lưu' : 'Lưu'),
  );
}
