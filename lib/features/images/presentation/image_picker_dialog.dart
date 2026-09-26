import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';

class ImagePickerResult {
  final String imageUrl;
  final String? caption;

  ImagePickerResult({required this.imageUrl, this.caption});
}

class ImagePickerDialog extends StatefulWidget {
  const ImagePickerDialog({super.key});

  static Future<ImagePickerResult?> show(BuildContext context) {
    return showDialog<ImagePickerResult>(
      context: context,
      barrierDismissible: true,
      builder: (context) => const ImagePickerDialog(),
    );
  }

  @override
  State<ImagePickerDialog> createState() => _ImagePickerDialogState();
}

class _ImagePickerDialogState extends State<ImagePickerDialog> {
  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _captionController = TextEditingController();

  final List<Map<String, String>> _presetTemplates = [
    {
      'title': 'Architecture Diagram',
      'url': 'architecture_diagram',
      'desc': 'System components and visual flow',
    },
    {
      'title': 'Wireframe Mockup',
      'url': 'wireframe_mockup',
      'desc': 'UI layout and design draft',
    },
    {
      'title': 'Flowchart Reference',
      'url': 'flowchart_reference',
      'desc': 'Decision tree and logic mapping',
    },
    {
      'title': 'Visual Inspiration',
      'url': 'visual_inspiration',
      'desc': 'Moodboard visual reference',
    },
  ];

  String? _selectedPreset;
  String? _pickedLocalDataUrl;
  String? _pickedFileName;
  bool _isPicking = false;

  @override
  void dispose() {
    _urlController.dispose();
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickFromDevice() async {
    setState(() => _isPicking = true);
    try {
      final picker = ImagePicker();
      final xfile = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (xfile != null) {
        final bytes = await xfile.readAsBytes();
        final base64String = 'data:image/png;base64,${base64Encode(bytes)}';

        setState(() {
          _pickedLocalDataUrl = base64String;
          _pickedFileName = xfile.name;
          _selectedPreset = null;
          if (_captionController.text.isEmpty) {
            _captionController.text =
                xfile.name.replaceAll(RegExp(r'\.[^.]+$'), '');
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isPicking = false);
    }
  }

  void _onConfirm() {
    String chosenUrl;

    if (_pickedLocalDataUrl != null) {
      chosenUrl = _pickedLocalDataUrl!;
    } else {
      final customUrl = _urlController.text.trim();
      chosenUrl = customUrl.isNotEmpty
          ? customUrl
          : (_selectedPreset ?? 'architecture_diagram');
    }

    final caption = _captionController.text.trim();

    Navigator.of(context).pop(
      ImagePickerResult(
        imageUrl: chosenUrl,
        caption: caption.isEmpty ? null : caption,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Add Image', style: AppTextStyles.titleLarge),
                  IconButton(
                    icon: const Icon(Icons.close, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Pick from Device Button
              OutlinedButton.icon(
                onPressed: _isPicking ? null : _pickFromDevice,
                icon: _isPicking
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.photo_library_outlined, size: 18),
                label: Text(
                  _pickedFileName != null
                      ? 'Selected: $_pickedFileName'
                      : 'Choose from Device / Gallery',
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: _pickedLocalDataUrl != null
                      ? AppColors.primaryMuted
                      : null,
                  side: BorderSide(
                    color: _pickedLocalDataUrl != null
                        ? AppColors.primary
                        : AppColors.border,
                  ),
                ),
              ),

              const SizedBox(height: 16),
              const Row(
                children: [
                  Expanded(child: Divider()),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Text('OR USE PRESET', style: TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ),
                  Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 12),

              // Presets Title
              const Text('Choose Preset Template:', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),

              // Preset options
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _presetTemplates.map((preset) {
                  final isSelected = _selectedPreset == preset['url'] && _pickedLocalDataUrl == null;
                  return ChoiceChip(
                    label: Text(preset['title']!),
                    selected: isSelected,
                    onSelected: (selected) {
                      setState(() {
                        _selectedPreset = selected ? preset['url'] : null;
                        _pickedLocalDataUrl = null;
                        _pickedFileName = null;
                        if (selected && _captionController.text.isEmpty) {
                          _captionController.text = preset['title']!;
                        }
                      });
                    },
                    selectedColor: AppColors.primaryMuted,
                    labelStyle: TextStyle(
                      color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  );
                }).toList(),
              ),

              const SizedBox(height: 16),

              // Custom URL Option
              TextField(
                controller: _urlController,
                decoration: const InputDecoration(
                  labelText: 'Or enter Image URL (optional)',
                  hintText: 'https://images.unsplash.com/...',
                  prefixIcon: Icon(Icons.link_rounded, size: 18),
                ),
                style: AppTextStyles.bodyMedium,
                onChanged: (_) {
                  if (_pickedLocalDataUrl != null) {
                    setState(() {
                      _pickedLocalDataUrl = null;
                      _pickedFileName = null;
                    });
                  }
                },
              ),

              const SizedBox(height: 12),

              // Caption Field
              TextField(
                controller: _captionController,
                decoration: const InputDecoration(
                  labelText: 'Caption (optional)',
                  hintText: 'e.g. Architecture Overview',
                ),
                style: AppTextStyles.bodyMedium,
              ),

              const SizedBox(height: 24),

              // Action Buttons
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
                    child: const Text('Add Image'),
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
