import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../canvas/domain/board_object.dart';

import 'widgets/note_content_renderer.dart';

class NoteCard extends StatelessWidget {
  final NoteObject note;
  final bool isSelected;
  final bool isConnectingSource;
  final VoidCallback? onTap;
  final VoidCallback? onDoubleTap;
  final void Function(int lineIndex)? onToggleChecklist;

  const NoteCard({
    super.key,
    required this.note,
    this.isSelected = false,
    this.isConnectingSource = false,
    this.onTap,
    this.onDoubleTap,
    this.onToggleChecklist,
  });

  Color _getBackgroundColor(int colorIndex) {
    switch (colorIndex) {
      case 1:
        return AppColors.noteYellow;
      case 2:
        return AppColors.noteBlue;
      case 3:
        return AppColors.noteGreen;
      case 4:
        return AppColors.notePurple;
      case 5:
        return AppColors.noteRose;
      case 0:
      default:
        return AppColors.surface;
    }
  }

  Color _getAccentColor(int colorIndex) {
    switch (colorIndex) {
      case 1:
        return const Color(0xFFF59E0B);
      case 2:
        return const Color(0xFF3B82F6);
      case 3:
        return const Color(0xFF10B981);
      case 4:
        return const Color(0xFF8B5CF6);
      case 5:
        return const Color(0xFFF43F5E);
      case 0:
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(note.colorIndex);
    final accentColor = _getAccentColor(note.colorIndex);

    // Compute checklist progress
    int totalChecklists = 0;
    int completedChecklists = 0;
    if (note.content.contains('[')) {
      for (final line in note.content.split('\n')) {
        final t = line.trim();
        if (t.startsWith('- [ ] ') || t.startsWith('[ ] ') || t.startsWith('* [ ] ')) {
          totalChecklists++;
        } else if (t.startsWith('- [x] ') ||
            t.startsWith('- [X] ') ||
            t.startsWith('[x] ') ||
            t.startsWith('[X] ') ||
            t.startsWith('* [x] ') ||
            t.startsWith('* [X] ')) {
          totalChecklists++;
          completedChecklists++;
        }
      }
    }

    return GestureDetector(
      onTap: onTap,
      onDoubleTap: onDoubleTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        width: note.width,
        height: note.height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isConnectingSource
                ? AppColors.primary
                : (isSelected ? AppColors.borderSelected : AppColors.border),
            width: isSelected || isConnectingSource ? 2.0 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: isSelected
                  ? AppColors.primary.withOpacity(0.16)
                  : AppColors.shadowColor,
              blurRadius: isSelected ? 10 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Accent Bar for colored cards
            if (note.colorIndex != 0)
              Container(
                height: 3.5,
                width: double.infinity,
                color: accentColor.withOpacity(0.85),
              ),

            // Card Body
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header with title, parent indicator, and checklist count
                    Row(
                      children: [
                        if (note.parentId != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            margin: const EdgeInsets.only(right: 6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryMuted,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.subdirectory_arrow_right_rounded,
                                    size: 10, color: AppColors.primaryDark),
                                SizedBox(width: 2),
                                Text(
                                  'child',
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primaryDark,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            note.title,
                            style: AppTextStyles.noteTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Checklist progress badge
                        if (totalChecklists > 0) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5.5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: completedChecklists == totalChecklists
                                  ? const Color(0xFF10B981).withOpacity(0.15)
                                  : Colors.black.withOpacity(0.06),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  completedChecklists == totalChecklists
                                      ? Icons.check_circle_rounded
                                      : Icons.check_circle_outline_rounded,
                                  size: 10,
                                  color: completedChecklists == totalChecklists
                                      ? const Color(0xFF10B981)
                                      : AppColors.textSecondary,
                                ),
                                const SizedBox(width: 3),
                                Text(
                                  '$completedChecklists/$totalChecklists',
                                  style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w600,
                                    color: completedChecklists == totalChecklists
                                        ? const Color(0xFF10B981)
                                        : AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (note.title.isNotEmpty && note.content.isNotEmpty)
                      const SizedBox(height: 6),
                    // Note Content
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const NeverScrollableScrollPhysics(),
                        child: NoteContentRenderer(
                          content: note.content,
                          onToggleChecklist: onToggleChecklist,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
