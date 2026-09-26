import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/board_object.dart';

class ParentHierarchyDialog extends StatelessWidget {
  final BoardObject currentObject;
  final List<BoardObject> allObjects;

  const ParentHierarchyDialog({
    super.key,
    required this.currentObject,
    required this.allObjects,
  });

  static Future<String?> show(
    BuildContext context, {
    required BoardObject currentObject,
    required List<BoardObject> allObjects,
  }) {
    return showDialog<String?>(
      context: context,
      builder: (context) => ParentHierarchyDialog(
        currentObject: currentObject,
        allObjects: allObjects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Candidates are all objects except this one and groups
    final candidates = allObjects
        .where((o) => o.id != currentObject.id && o is! GroupObject)
        .toList();

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440, maxHeight: 520),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Set Parent Hierarchy', style: AppTextStyles.titleLarge),
              const SizedBox(height: 6),
              const Text(
                'Logical parent/child relationship does not alter canvas x/y positions.',
                style: AppTextStyles.bodySmall,
              ),
              const SizedBox(height: 16),

              // Current Status
              if (currentObject.parentId != null) ...[
                ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                  tileColor: AppColors.surfaceVariant,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  leading: const Icon(Icons.link_off_rounded, color: AppColors.error),
                  title: const Text('Clear Current Parent', style: AppTextStyles.bodyMedium),
                  onTap: () => Navigator.of(context).pop('__CLEAR__'),
                ),
                const SizedBox(height: 12),
              ],

              const Text('Choose Parent Object:', style: AppTextStyles.labelMedium),
              const SizedBox(height: 8),

              Expanded(
                child: candidates.isEmpty
                    ? const Center(
                        child: Text(
                          'No eligible parent objects found.',
                          style: AppTextStyles.bodyMedium,
                        ),
                      )
                    : ListView.separated(
                        itemCount: candidates.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 6),
                        itemBuilder: (context, index) {
                          final candidate = candidates[index];
                          final isCurrentParent = candidate.id == currentObject.parentId;

                          String name;
                          IconData icon;
                          if (candidate is NoteObject) {
                            name = candidate.title;
                            icon = Icons.sticky_note_2_outlined;
                          } else if (candidate is ImageObject) {
                            name = candidate.caption ?? 'Image';
                            icon = Icons.image_outlined;
                          } else {
                            name = 'Object';
                            icon = Icons.widgets_outlined;
                          }

                          return ListTile(
                            dense: true,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                              side: BorderSide(
                                color: isCurrentParent
                                    ? AppColors.primary
                                    : AppColors.border,
                              ),
                            ),
                            tileColor: isCurrentParent
                                ? AppColors.primaryMuted
                                : AppColors.surface,
                            leading: Icon(
                              icon,
                              size: 18,
                              color: isCurrentParent
                                  ? AppColors.primary
                                  : AppColors.textSecondary,
                            ),
                            title: Text(
                              name,
                              style: AppTextStyles.titleMedium.copyWith(fontSize: 13),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            trailing: isCurrentParent
                                ? const Icon(Icons.check_circle,
                                    size: 18, color: AppColors.primary)
                                : null,
                            onTap: () => Navigator.of(context).pop(candidate.id),
                          );
                        },
                      ),
              ),

              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(null),
                  child: const Text('Cancel'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
