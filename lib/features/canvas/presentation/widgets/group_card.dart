import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/board_object.dart';

class GroupCard extends StatelessWidget {
  final GroupObject group;
  final bool isSelected;
  final VoidCallback? onTap;
  final VoidCallback? onRename;
  final VoidCallback? onArrange;

  const GroupCard({
    super.key,
    required this.group,
    this.isSelected = false,
    this.onTap,
    this.onRename,
    this.onArrange,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: group.width,
        height: group.height,
        decoration: BoxDecoration(
          color: AppColors.groupFill,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.borderSelected : AppColors.groupBorder,
            width: isSelected ? 2.0 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Group Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primaryMuted
                    : AppColors.surface.withOpacity(0.7),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
                border: const Border(
                  bottom: BorderSide(color: AppColors.border, width: 1),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.folder_open_rounded,
                    size: 16,
                    color: isSelected ? AppColors.primary : AppColors.textSecondary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      group.title,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontSize: 13,
                        color: isSelected ? AppColors.primaryDark : AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onArrange != null)
                    InkWell(
                      onTap: onArrange,
                      borderRadius: BorderRadius.circular(4),
                      child: const Tooltip(
                        message: 'Arrange notes in group',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                          child: Icon(
                            Icons.grid_view_rounded,
                            size: 14,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ),
                  if (onRename != null)
                    InkWell(
                      onTap: onRename,
                      borderRadius: BorderRadius.circular(4),
                      child: const Tooltip(
                        message: 'Rename group',
                        child: Padding(
                          padding: EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                          child: Icon(
                            Icons.edit_outlined,
                            size: 14,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
