import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../app/theme/app_text_styles.dart';
import '../../domain/board_object.dart';

enum ObjectActionType {
  edit,
  connect,
  setParent,
  duplicate,
  delete,
}

class ObjectActionSheet extends StatelessWidget {
  final BoardObject object;

  const ObjectActionSheet({super.key, required this.object});

  static Future<ObjectActionType?> show(BuildContext context, BoardObject object) {
    return showModalBottomSheet<ObjectActionType>(
      context: context,
      builder: (context) => ObjectActionSheet(object: object),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title;
    IconData leadingIcon;

    if (object is NoteObject) {
      final note = object as NoteObject;
      title = note.title.isNotEmpty ? note.title : 'Untitled Note';
      leadingIcon = Icons.sticky_note_2_outlined;
    } else if (object is ImageObject) {
      final img = object as ImageObject;
      title = img.caption ?? 'Image Object';
      leadingIcon = Icons.image_outlined;
    } else {
      final grp = object as GroupObject;
      title = grp.title;
      leadingIcon = Icons.folder_open_rounded;
    }

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Title Header
            Row(
              children: [
                Icon(leadingIcon, size: 20, color: AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.titleLarge.copyWith(fontSize: 16),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),

            // Actions
            if (object is NoteObject)
              ListTile(
                dense: true,
                leading: const Icon(Icons.edit_outlined),
                title: const Text('Edit Note'),
                onTap: () => Navigator.of(context).pop(ObjectActionType.edit),
              ),

            ListTile(
              dense: true,
              leading: const Icon(Icons.alt_route_rounded),
              title: const Text('Connect to Another Object'),
              onTap: () => Navigator.of(context).pop(ObjectActionType.connect),
            ),

            if (object is! GroupObject)
              ListTile(
                dense: true,
                leading: const Icon(Icons.account_tree_outlined),
                title: const Text('Set Parent Hierarchy'),
                onTap: () => Navigator.of(context).pop(ObjectActionType.setParent),
              ),

            ListTile(
              dense: true,
              leading: const Icon(Icons.copy_rounded),
              title: const Text('Duplicate'),
              onTap: () => Navigator.of(context).pop(ObjectActionType.duplicate),
            ),

            ListTile(
              dense: true,
              leading: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
              title: const Text('Delete', style: TextStyle(color: AppColors.error)),
              onTap: () => Navigator.of(context).pop(ObjectActionType.delete),
            ),
          ],
        ),
      ),
    );
  }
}
