import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/board_connection.dart';

class ConnectionEditResult {
  final String? label;
  final String type;
  final bool delete;

  ConnectionEditResult({
    this.label,
    required this.type,
    this.delete = false,
  });
}

class ConnectionEditorDialog extends StatefulWidget {
  final BoardConnection connection;

  const ConnectionEditorDialog({super.key, required this.connection});

  static Future<ConnectionEditResult?> show(
    BuildContext context, {
    required BoardConnection connection,
  }) {
    return showDialog<ConnectionEditResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => ConnectionEditorDialog(connection: connection),
    );
  }

  @override
  State<ConnectionEditorDialog> createState() => _ConnectionEditorDialogState();
}

class _ConnectionEditorDialogState extends State<ConnectionEditorDialog> {
  late final TextEditingController _labelController;
  late String _selectedStyle;
  String? _selectedColor;

  static const List<String> _presetLabels = [
    'leads to',
    'depends on',
    'relates to',
    'causes',
    'contains',
    'blocks',
    'triggers',
    'part of',
  ];

  static const List<Map<String, dynamic>> _lineStyles = [
    {'type': 'arrow', 'label': 'Arrow', 'icon': Icons.arrow_forward_rounded},
    {'type': 'curved', 'label': 'Curved', 'icon': Icons.gesture_rounded},
    {'type': 'step', 'label': 'Stepped', 'icon': Icons.turn_sharp_right_rounded},
    {'type': 'bidirectional', 'label': 'Two-way', 'icon': Icons.sync_alt_rounded},
    {'type': 'dashed', 'label': 'Dashed', 'icon': Icons.more_horiz_rounded},
    {'type': 'line', 'label': 'Plain', 'icon': Icons.remove_rounded},
  ];

  static const List<Map<String, dynamic>> _colors = [
    {'key': null, 'label': 'Default', 'color': Color(0xFF64748B)},
    {'key': 'blue', 'label': 'Blue', 'color': Color(0xFF3B82F6)},
    {'key': 'green', 'label': 'Green', 'color': Color(0xFF10B981)},
    {'key': 'amber', 'label': 'Amber', 'color': Color(0xFFF59E0B)},
    {'key': 'purple', 'label': 'Purple', 'color': Color(0xFF8B5CF6)},
    {'key': 'rose', 'label': 'Rose', 'color': Color(0xFFEF4444)},
  ];

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController(text: widget.connection.label ?? '');
    final parts = widget.connection.type.split(':');
    _selectedStyle = parts[0];
    _selectedColor = parts.length > 1 ? parts[1] : null;
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }

  void _onSave() {
    final labelText = _labelController.text.trim();
    final fullType = _selectedColor != null ? '$_selectedStyle:$_selectedColor' : _selectedStyle;
    Navigator.of(context).pop(
      ConnectionEditResult(
        label: labelText.isEmpty ? null : labelText,
        type: fullType,
      ),
    );
  }

  void _onDelete() {
    final fullType = _selectedColor != null ? '$_selectedStyle:$_selectedColor' : _selectedStyle;
    Navigator.of(context).pop(
      ConnectionEditResult(
        type: fullType,
        delete: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 460),
        child: Padding(
          padding: const EdgeInsets.all(22.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Connection Settings', style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                    splashRadius: 18,
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Relationship Label
              TextField(
                controller: _labelController,
                decoration: InputDecoration(
                  labelText: 'Relationship Label (optional)',
                  hintText: 'e.g. leads to, depends on...',
                  suffixIcon: _labelController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 16),
                          onPressed: () => setState(() => _labelController.clear()),
                        )
                      : null,
                ),
                style: AppTextStyles.bodyMedium,
              ),
              const SizedBox(height: 10),

              // Preset Relationship Chips
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _presetLabels.map((preset) {
                  final isSelected = _labelController.text == preset;
                  return ChoiceChip(
                    label: Text(preset, style: const TextStyle(fontSize: 11)),
                    selected: isSelected,
                    selectedColor: AppColors.primaryMuted,
                    visualDensity: VisualDensity.compact,
                    onSelected: (selected) {
                      setState(() {
                        _labelController.text = selected ? preset : '';
                      });
                    },
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Line Style Selection
              const Text('Line Style:', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _lineStyles.map((style) {
                  final isSelected = _selectedStyle == style['type'];
                  return InkWell(
                    onTap: () => setState(() => _selectedStyle = style['type'] as String),
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      width: 66,
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primaryMuted : AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isSelected ? AppColors.primary : AppColors.border,
                          width: isSelected ? 1.5 : 1.0,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            style['icon'] as IconData,
                            size: 18,
                            color: isSelected ? AppColors.primaryDark : AppColors.textSecondary,
                          ),
                          const SizedBox(height: 3),
                          Text(
                            style['label'] as String,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                              color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 14),

              // Connection Color
              const Text('Line Color:', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),
              Row(
                children: _colors.map((c) {
                  final isSelected = _selectedColor == c['key'];
                  final color = c['color'] as Color;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: InkWell(
                      onTap: () => setState(() => _selectedColor = c['key'] as String?),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isSelected ? AppColors.primaryDark : Colors.transparent,
                            width: 2.2,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: color.withOpacity(0.4),
                                blurRadius: 4,
                                spreadRadius: 1,
                              ),
                          ],
                        ),
                        child: isSelected
                            ? const Icon(Icons.check, size: 14, color: Colors.white)
                            : null,
                      ),
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 20),

              // Actions
              Row(
                children: [
                  TextButton.icon(
                    onPressed: _onDelete,
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                    label: const Text('Delete', style: TextStyle(color: AppColors.error)),
                  ),
                  const Spacer(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 10),
                  ElevatedButton(
                    onPressed: _onSave,
                    child: const Text('Save'),
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
