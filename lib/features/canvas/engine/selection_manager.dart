import 'package:flutter/material.dart';
import '../domain/board_object.dart';

/// Handles hit testing and object selection logic on the canvas.
class SelectionManager {
  SelectionManager._();

  /// Hit test to find the top-most object under [worldPoint].
  /// Rendering order: notes (top), images, groups (bottom).
  /// So hit test goes in reverse: notes first, then images, then groups.
  static BoardObject? findObjectAt(Offset worldPoint, Iterable<BoardObject> objects) {
    final list = objects.toList();

    // 1. Check notes first (rendered on top)
    for (int i = list.length - 1; i >= 0; i--) {
      final obj = list[i];
      if (obj is NoteObject && obj.rect.contains(worldPoint)) {
        return obj;
      }
    }

    // 2. Check images next
    for (int i = list.length - 1; i >= 0; i--) {
      final obj = list[i];
      if (obj is ImageObject && obj.rect.contains(worldPoint)) {
        return obj;
      }
    }

    // 3. Check groups last
    for (int i = list.length - 1; i >= 0; i--) {
      final obj = list[i];
      if (obj is GroupObject && obj.rect.contains(worldPoint)) {
        return obj;
      }
    }

    return null;
  }
}
