import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';

enum AddObjectType { note, image, group }

class AddMenuWidget extends StatelessWidget {
  final void Function(AddObjectType type) onSelectType;

  const AddMenuWidget({super.key, required this.onSelectType});

  static Future<AddObjectType?> showBottomSheet(BuildContext context) {
    return showModalBottomSheet<AddObjectType>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Add to Canvas', style: AppTextStyles.titleLarge),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.sticky_note_2_outlined, color: AppColors.primary),
                ),
                title: const Text('Note', style: AppTextStyles.titleMedium),
                subtitle: const Text('Visual note with title and ideas', style: AppTextStyles.bodySmall),
                onTap: () => Navigator.of(context).pop(AddObjectType.note),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.image_outlined, color: AppColors.primary),
                ),
                title: const Text('Image', style: AppTextStyles.titleMedium),
                subtitle: const Text('Visual diagram or reference card', style: AppTextStyles.bodySmall),
                onTap: () => Navigator.of(context).pop(AddObjectType.image),
              ),
              const SizedBox(height: 6),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primaryMuted,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.folder_open_rounded, color: AppColors.primary),
                ),
                title: const Text('Group', style: AppTextStyles.titleMedium),
                subtitle: const Text('Organize related objects visually', style: AppTextStyles.bodySmall),
                onTap: () => Navigator.of(context).pop(AddObjectType.group),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border, width: 1),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMenuItem(
              icon: Icons.sticky_note_2_outlined,
              label: 'Note',
              shortcut: 'N',
              onTap: () => onSelectType(AddObjectType.note),
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.image_outlined,
              label: 'Image',
              shortcut: 'I',
              onTap: () => onSelectType(AddObjectType.image),
            ),
            const Divider(height: 1),
            _buildMenuItem(
              icon: Icons.folder_open_rounded,
              label: 'Group',
              shortcut: 'G',
              onTap: () => onSelectType(AddObjectType.group),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    required String shortcut,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 18, color: AppColors.textSecondary),
            const SizedBox(width: 10),
            Text(label, style: AppTextStyles.titleMedium.copyWith(fontSize: 13)),
            const SizedBox(width: 24),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color: AppColors.surfaceVariant,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                shortcut,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 10,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
