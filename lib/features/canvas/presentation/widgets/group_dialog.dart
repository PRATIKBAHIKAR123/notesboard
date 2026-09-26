import 'package:flutter/material.dart';
import '../../../../app/theme/app_text_styles.dart';

class GroupDialog extends StatefulWidget {
  final String initialTitle;
  final String titleText;
  final String confirmText;

  const GroupDialog({
    super.key,
    this.initialTitle = '',
    this.titleText = 'Create Group',
    this.confirmText = 'Create Group',
  });

  static Future<String?> show(
    BuildContext context, {
    String initialTitle = '',
    String titleText = 'Create Group',
    String confirmText = 'Create Group',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => GroupDialog(
        initialTitle: initialTitle,
        titleText: titleText,
        confirmText: confirmText,
      ),
    );
  }

  @override
  State<GroupDialog> createState() => _GroupDialogState();
}

class _GroupDialogState extends State<GroupDialog> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialTitle);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final title = _controller.text.trim();
    Navigator.of(context).pop(title.isEmpty ? 'Untitled Group' : title);
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titleText, style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _controller,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Group Title',
                  hintText: 'e.g. Design Track, Backend Ideas...',
                ),
                style: AppTextStyles.titleMedium,
                onSubmitted: (_) => _onConfirm(),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _onConfirm,
                    child: Text(widget.confirmText),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
