import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/board_object.dart';

/// Quick Search and Filter Dialog for Canvas objects (Ctrl+F)
class CanvasSearchDialog extends StatefulWidget {
  final List<BoardObject> objects;
  final void Function(BoardObject object) onSelectObject;

  const CanvasSearchDialog({
    super.key,
    required this.objects,
    required this.onSelectObject,
  });

  static Future<void> show(
    BuildContext context, {
    required List<BoardObject> objects,
    required void Function(BoardObject object) onSelectObject,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => CanvasSearchDialog(
        objects: objects,
        onSelectObject: onSelectObject,
      ),
    );
  }

  @override
  State<CanvasSearchDialog> createState() => _CanvasSearchDialogState();
}

class _CanvasSearchDialogState extends State<CanvasSearchDialog> {
  final TextEditingController _queryController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  List<BoardObject> get _filteredObjects {
    if (_query.trim().isEmpty) {
      return widget.objects;
    }
    final q = _query.toLowerCase().trim();
    return widget.objects.where((obj) {
      if (obj is NoteObject) {
        return obj.title.toLowerCase().contains(q) ||
            obj.content.toLowerCase().contains(q);
      } else if (obj is ImageObject) {
        return obj.caption?.toLowerCase().contains(q) == true;
      } else if (obj is GroupObject) {
        return obj.title.toLowerCase().contains(q);
      }
      return false;
    }).toList();
  }

  Color _getNoteColor(int colorIndex) {
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
    final results = _filteredObjects;

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 20, right: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 480),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Search input
              TextField(
                controller: _queryController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: 'Search notes by title, content, or #tag... (Ctrl+F)',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: _query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _queryController.clear();
                            setState(() => _query = '');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.canvasBackground,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
                  ),
                ),
                style: AppTextStyles.bodyMedium,
                onChanged: (val) => setState(() => _query = val),
              ),

              const SizedBox(height: 10),

              // Match counter & Quick tips
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${results.length} item${results.length == 1 ? '' : 's'} found',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  const Text(
                    'Tap to jump to note',
                    style: TextStyle(fontSize: 11, color: AppColors.textMuted),
                  ),
                ],
              ),

              const Divider(height: 16),

              // Results list
              if (results.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 36),
                  child: Center(
                    child: Text(
                      'No matching objects on this board',
                      style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                    ),
                  ),
                )
              else
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: results.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final obj = results[index];
                      String title = '';
                      String subtitle = '';
                      IconData leadingIcon = Icons.note_rounded;
                      Color iconColor = AppColors.primary;

                      if (obj is NoteObject) {
                        title = obj.title.isEmpty ? 'Untitled Note' : obj.title;
                        subtitle = obj.content.replaceAll('\n', ' ');
                        iconColor = _getNoteColor(obj.colorIndex);
                        leadingIcon = Icons.sticky_note_2_rounded;
                      } else if (obj is ImageObject) {
                        title = obj.caption ?? 'Image';
                        subtitle = obj.imageUrl;
                        leadingIcon = Icons.image_rounded;
                        iconColor = const Color(0xFF3B82F6);
                      } else if (obj is GroupObject) {
                        title = obj.title;
                        subtitle = 'Group container';
                        leadingIcon = Icons.folder_rounded;
                        iconColor = const Color(0xFF8B5CF6);
                      }

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: iconColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(leadingIcon, size: 16, color: iconColor),
                        ),
                        title: Text(
                          title,
                          style: AppTextStyles.noteTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: subtitle.isNotEmpty
                            ? Text(
                                subtitle,
                                style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              )
                            : null,
                        trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                        onTap: () {
                          Navigator.of(context).pop();
                          widget.onSelectObject(obj);
                        },
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
