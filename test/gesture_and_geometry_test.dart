import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notesboard/features/canvas/domain/board_object.dart';
import 'package:notesboard/features/canvas/engine/coordinate_transform.dart';
import 'package:notesboard/features/canvas/engine/gesture_manager.dart';
import 'package:notesboard/features/canvas/engine/selection_manager.dart';

void main() {
  group('GestureManager & CoordinateTransform Tests', () {
    test('Resize bottomRight expands width and height', () {
      const initialRect = Rect.fromLTWH(100, 100, 200, 150);
      final newRect = GestureManager.computeResizedRect(
        initialRect: initialRect,
        handle: ResizeHandle.bottomRight,
        worldDelta: const Offset(50, 40),
        type: BoardObjectType.note,
      );

      expect(newRect.left, 100);
      expect(newRect.top, 100);
      expect(newRect.width, 250);
      expect(newRect.height, 190);
    });

    test('Resize clamps to minimum dimensions', () {
      const initialRect = Rect.fromLTWH(100, 100, 200, 150);
      // Attempt to shrink note to tiny/negative size
      final newRect = GestureManager.computeResizedRect(
        initialRect: initialRect,
        handle: ResizeHandle.bottomRight,
        worldDelta: const Offset(-180, -140),
        type: BoardObjectType.note,
      );

      expect(newRect.width, greaterThanOrEqualTo(140)); // AppConstants.minNoteWidth
      expect(newRect.height, greaterThanOrEqualTo(80)); // AppConstants.minNoteHeight
    });

    test('CoordinateTransform.getEdgeAnchor calculates boundary intersection', () {
      const rect = Rect.fromLTWH(100, 100, 100, 100); // Center at (150, 150)
      const targetCenter = Offset(300, 150); // Straight right

      final anchor = CoordinateTransform.getEdgeAnchor(rect, targetCenter);
      // Should touch right edge at (200, 150)
      expect(anchor.dx, 200);
      expect(anchor.dy, 150);
    });

    test('SelectionManager hit testing adheres to z-order (notes over groups)', () {
      final now = DateTime.now();
      final group = GroupObject(
        id: 'group-1',
        boardId: 'b-1',
        title: 'Group 1',
        x: 50,
        y: 50,
        width: 300,
        height: 300,
        createdAt: now,
        updatedAt: now,
      );

      final note = NoteObject(
        id: 'note-1',
        boardId: 'b-1',
        title: 'Note 1',
        content: 'Content',
        x: 100,
        y: 100,
        width: 150,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final objects = [group, note];

      // Point inside both group and note: should pick note (rendered on top)
      final hitOnBoth = SelectionManager.findObjectAt(const Offset(120, 120), objects);
      expect(hitOnBoth?.id, 'note-1');

      // Point inside group only: should pick group
      final hitOnGroupOnly = SelectionManager.findObjectAt(const Offset(60, 60), objects);
      expect(hitOnGroupOnly?.id, 'group-1');

      // Point outside both
      final hitOutside = SelectionManager.findObjectAt(const Offset(400, 400), objects);
      expect(hitOutside, isNull);
    });
  });
}
