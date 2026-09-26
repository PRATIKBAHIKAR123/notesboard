import 'package:flutter/material.dart';
import '../../../app/theme/app_text_styles.dart';

class CreateBoardResult {
  final String name;
  final String? description;

  CreateBoardResult({required this.name, this.description});
}

class CreateBoardDialog extends StatefulWidget {
  final String? initialName;
  final String? initialDescription;
  final String titleText;
  final String confirmText;

  const CreateBoardDialog({
    super.key,
    this.initialName,
    this.initialDescription,
    this.titleText = 'Create New Board',
    this.confirmText = 'Create Board',
  });

  static Future<CreateBoardResult?> show(
    BuildContext context, {
    String? initialName,
    String? initialDescription,
    String titleText = 'Create New Board',
    String confirmText = 'Create Board',
  }) {
    return showDialog<CreateBoardResult>(
      context: context,
      builder: (context) => CreateBoardDialog(
        initialName: initialName,
        initialDescription: initialDescription,
        titleText: titleText,
        confirmText: confirmText,
      ),
    );
  }

  @override
  State<CreateBoardDialog> createState() => _CreateBoardDialogState();
}

class _CreateBoardDialogState extends State<CreateBoardDialog> {
  late final TextEditingController _nameController;
  late final TextEditingController _descController;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController = TextEditingController(text: widget.initialDescription ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    super.dispose();
  }

  void _onConfirm() {
    final name = _nameController.text.trim();
    final desc = _descController.text.trim();

    if (name.isEmpty) return;

    Navigator.of(context).pop(
      CreateBoardResult(
        name: name,
        description: desc.isEmpty ? null : desc,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.titleText, style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: _nameController,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Board Name',
                  hintText: 'e.g. Sprint Planning, Brainstorming...',
                ),
                style: AppTextStyles.titleMedium,
                onSubmitted: (_) => _onConfirm(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _descController,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'What is this board for?',
                ),
                style: AppTextStyles.bodyMedium,
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
