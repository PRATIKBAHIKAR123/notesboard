import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesboard/features/canvas/engine/canvas_controller.dart';
import 'package:notesboard/features/canvas/presentation/board_canvas.dart';
import 'package:notesboard/features/notes/presentation/widgets/note_content_renderer.dart';

void main() {
  group('Text & Notes Mapping Feature Tests', () {
    const testBoardId = 'test-board-features';

    testWidgets('Interactive checklist toggles state and persists', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BoardCanvas(
              boardId: testBoardId,
              boardName: 'Feature Test Board',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider(testBoardId).notifier);

      // Create a note with checklist items
      controller.createNote(
        title: 'Sprint Checklist',
        content: '- [ ] Priority item A\n- [x] Done item B\n- [ ] Pending item C',
        viewportSize: const Size(1200, 800),
      );

      await tester.pumpAndSettle();

      expect(find.text('Sprint Checklist'), findsOneWidget);
      expect(find.text('Priority item A'), findsOneWidget);
      expect(find.text('Done item B'), findsOneWidget);

      // Verify NoteContentRenderer is rendered
      expect(find.byType(NoteContentRenderer), findsOneWidget);

      // Programmatically toggle checklist line 0 from [ ] to [x]
      final note = container.read(canvasControllerProvider(testBoardId)).notes.first;
      controller.toggleNoteChecklistItem(noteId: note.id, lineIndex: 0);

      await tester.pumpAndSettle();

      final updatedNote = container.read(canvasControllerProvider(testBoardId)).notes.first;
      expect(updatedNote.content.contains('- [x] Priority item A'), isTrue);

      // Test undo reverts checklist item
      controller.undo();
      await tester.pumpAndSettle();

      final undoneNote = container.read(canvasControllerProvider(testBoardId)).notes.first;
      expect(undoneNote.content.contains('- [ ] Priority item A'), isTrue);
    });

    testWidgets('One-click mind-map branching spawns child note and connection', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BoardCanvas(
              boardId: 'branch-test-board',
              boardName: 'Branch Test Board',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider('branch-test-board').notifier);

      // Create parent note
      controller.createNote(
        title: 'Root Topic',
        content: 'Main concept for mapping',
        viewportSize: const Size(1200, 800),
      );

      await tester.pumpAndSettle();

      final parentNote = container.read(canvasControllerProvider('branch-test-board')).notes.first;

      // Branch child note
      controller.branchChildNote(
        parentNoteId: parentNote.id,
        title: 'Sub-topic 1',
      );

      await tester.pumpAndSettle();

      final state = container.read(canvasControllerProvider('branch-test-board'));
      expect(state.notes.length, 2);

      final childNote = state.notes.firstWhere((n) => n.title == 'Sub-topic 1');
      expect(childNote.parentId, parentNote.id);
      expect(childNote.x, greaterThan(parentNote.x));

      // Connection should link parent to child
      expect(state.connections.any((c) => c.fromObjectId == parentNote.id && c.toObjectId == childNote.id), isTrue);

      // Undo removes child note and connection atomically
      controller.undo();
      await tester.pumpAndSettle();

      final stateAfterUndo = container.read(canvasControllerProvider('branch-test-board'));
      expect(stateAfterUndo.notes.length, 1);
      expect(stateAfterUndo.connections.isEmpty, isTrue);
    });

    testWidgets('Connection editing updates label and line type', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BoardCanvas(
              boardId: 'conn-test-board',
              boardName: 'Connection Test Board',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider('conn-test-board').notifier);

      controller.createNote(title: 'Node 1', content: '', viewportSize: const Size(1200, 800));
      controller.createNote(title: 'Node 2', content: '', viewportSize: const Size(1200, 800));
      await tester.pumpAndSettle();

      final notes = container.read(canvasControllerProvider('conn-test-board')).notes;
      controller.startConnecting(notes[0].id);
      controller.completeConnecting(notes[1].id);
      await tester.pumpAndSettle();

      var conns = container.read(canvasControllerProvider('conn-test-board')).connections;
      expect(conns.length, 1);
      final connId = conns.first.id;

      // Edit connection label and style
      controller.editConnection(
        connectionId: connId,
        label: 'depends on',
        type: 'curved',
      );
      await tester.pumpAndSettle();

      conns = container.read(canvasControllerProvider('conn-test-board')).connections;
      expect(conns.first.label, 'depends on');
      expect(conns.first.type, 'curved');

      // Undo reverts connection changes
      controller.undo();
      await tester.pumpAndSettle();

      conns = container.read(canvasControllerProvider('conn-test-board')).connections;
      expect(conns.first.label, isNull);
      expect(conns.first.type, 'arrow');
    });

    testWidgets('Auto-arrange map positions connected notes into a clean hierarchy', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BoardCanvas(
              boardId: 'layout-test-board',
              boardName: 'Layout Test Board',
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider('layout-test-board').notifier);

      controller.createNote(title: 'Parent', content: '', viewportSize: const Size(1200, 800));
      await tester.pumpAndSettle();

      final parent = container.read(canvasControllerProvider('layout-test-board')).notes.first;
      controller.branchChildNote(parentNoteId: parent.id, title: 'Child A');
      controller.branchChildNote(parentNoteId: parent.id, title: 'Child B');
      await tester.pumpAndSettle();

      // Trigger auto-arrange map
      controller.autoArrangeMap();
      await tester.pumpAndSettle();

      final state = container.read(canvasControllerProvider('layout-test-board'));
      final parentAfter = state.objects[parent.id]!;
      final childA = state.notes.firstWhere((n) => n.title == 'Child A');
      final childB = state.notes.firstWhere((n) => n.title == 'Child B');

      // Children should be placed to the right of parent
      expect(childA.x, greaterThan(parentAfter.x));
      expect(childB.x, greaterThan(parentAfter.x));
      // Child B should be placed below Child A
      expect(childB.y, greaterThan(childA.y));
    });
  });
}
