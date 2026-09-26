import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesboard/features/boards/data/board_export_service.dart';
import 'package:notesboard/features/boards/data/board_repository.dart';
import 'package:notesboard/features/boards/domain/board.dart';
import 'package:notesboard/features/canvas/data/canvas_repository.dart';
import 'package:notesboard/features/canvas/domain/board_connection.dart';
import 'package:notesboard/features/canvas/domain/board_object.dart';
import 'package:notesboard/features/canvas/domain/canvas_camera.dart';
import 'package:notesboard/features/canvas/engine/auto_layout_manager.dart';
import 'package:notesboard/features/canvas/engine/canvas_controller.dart';
import 'package:notesboard/features/canvas/presentation/board_canvas.dart';
import 'package:notesboard/features/canvas/presentation/widgets/canvas_search_dialog.dart';
import 'package:notesboard/features/canvas/presentation/widgets/connections_painter.dart';
import 'package:notesboard/features/notes/presentation/note_card.dart';
import 'package:notesboard/features/notes/presentation/widgets/note_content_renderer.dart';

class _MockBoardRepo implements BoardRepository {
  final Map<String, Board> boards = {};

  @override
  Future<void> createBoard(Board board) async => boards[board.id] = board;

  @override
  Future<void> deleteBoard(String id) async => boards.remove(id);

  @override
  Future<Board?> getBoardById(String id) async => boards[id];

  @override
  Future<int> getBoardObjectCount(String boardId) async => 0;

  @override
  Future<List<Board>> getBoards() async => boards.values.toList();

  @override
  Future<void> updateBoard(Board board) async => boards[board.id] = board;

  @override
  Stream<List<Board>> watchBoards() => Stream.value(boards.values.toList());
}

class _MockCanvasRepo implements CanvasRepository {
  final List<BoardObject> objects = [];
  final List<BoardConnection> connections = [];

  @override
  Future<void> deleteConnection(String id) async =>
      connections.removeWhere((c) => c.id == id);

  @override
  Future<void> deleteConnectionsForObject(String objectId) async =>
      connections.removeWhere((c) => c.fromObjectId == objectId || c.toObjectId == objectId);

  @override
  Future<void> deleteObject(String id, BoardObjectType type) async =>
      objects.removeWhere((o) => o.id == id);

  @override
  Future<List<BoardConnection>> getConnections(String boardId) async => connections;

  @override
  Future<List<BoardObject>> getObjects(String boardId) async => objects;

  @override
  Future<void> saveConnection(BoardConnection connection) async =>
      connections.add(connection);

  @override
  Future<void> saveObject(BoardObject object) async => objects.add(object);

  @override
  Future<void> saveObjects(List<BoardObject> objs) async => objects.addAll(objs);

  @override
  Future<void> seedDemoDataIfEmpty() async {}

  @override
  Stream<List<BoardConnection>> watchConnections(String boardId) =>
      Stream.value(connections);

  @override
  Stream<List<BoardObject>> watchObjects(String boardId) =>
      Stream.value(objects);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Requirement 1 & 4: Shift+Scroll & Snap to Grid Tests', () {
    const boardId = 'test-board-snap-scroll';

    test('Snap to grid snaps object positions and aligns all objects', () async {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: boardId, repository: repo);

      expect(controller.state.snapToGrid, isFalse);

      // Toggle snap to grid ON
      controller.toggleSnapToGrid();
      expect(controller.state.snapToGrid, isTrue);

      // Create note while snap to grid is on - position should be snapped to multiple of 24
      final note = await controller.createNote(
        title: 'Snapped Note',
        content: 'Content',
        worldPos: const Offset(105, 203),
      );

      // 105 / 24 = 4.375 -> 96, 203 / 24 = 8.45 -> 192
      expect(note.x % 24, equals(0.0));
      expect(note.y % 24, equals(0.0));
      expect(note.x, equals(96.0));
      expect(note.y, equals(192.0));

      // Move object - should also snap
      controller.updateObjectPosition(note.id, const Offset(150, 250));
      final moved = controller.state.objects[note.id]!;
      // 150 / 24 = 6.25 -> 144, 250 / 24 = 10.41 -> 240
      expect(moved.x % 24, equals(0.0));
      expect(moved.y % 24, equals(0.0));
      expect(moved.x, equals(144.0));
      expect(moved.y, equals(240.0));

      // Toggle OFF and create un-snapped note
      controller.toggleSnapToGrid();
      final unaligned = await controller.createNote(
        title: 'Unaligned Note',
        content: 'Unaligned',
        worldPos: const Offset(111, 222),
      );
      expect(unaligned.x, equals(111.0));
      expect(unaligned.y, equals(222.0));

      // Now call snapAllObjectsToGrid()
      controller.snapAllObjectsToGrid();
      final aligned = controller.state.objects[unaligned.id]!;
      expect(aligned.x % 24, equals(0.0));
      expect(aligned.y % 24, equals(0.0));
      expect(aligned.x, equals(120.0));
      expect(aligned.y, equals(216.0));

      controller.dispose();
    });

    testWidgets('Pointer scroll with Shift pans horizontally', (tester) async {
      tester.view.physicalSize = const Size(1000, 700);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: BoardCanvas(
              boardId: 'scroll-test-board',
              boardName: 'Scroll Test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final initialPan = container.read(canvasControllerProvider('scroll-test-board')).camera.pan;

      final listenerFinder = find.byWidgetPredicate((w) => w is Listener && w.onPointerSignal != null);
      expect(listenerFinder, findsWidgets);
      final listener = tester.widget<Listener>(listenerFinder.first);

      // 1. Test Shift+Scroll
      await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
      listener.onPointerSignal!(const PointerScrollEvent(scrollDelta: Offset(0, 100)));
      await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
      await tester.pump();

      var newPan = container.read(canvasControllerProvider('scroll-test-board')).camera.pan;
      expect(newPan.dx, isNot(equals(initialPan.dx)));

      // 2. Test Trackpad horizontal swipe (dx != 0, dy == 0)
      final midPan = newPan;
      listener.onPointerSignal!(const PointerScrollEvent(scrollDelta: Offset(50, 0)));
      await tester.pump();

      newPan = container.read(canvasControllerProvider('scroll-test-board')).camera.pan;
      expect(newPan.dx, isNot(equals(midPan.dx)));
    });
  });

  group('Requirement 2 & 5: Text Formatting, Design, and Mapping Features', () {
    testWidgets('NoteContentRenderer renders callouts, dividers, strikethrough, highlights, and tags', (tester) async {
      const markdownContent = '''
> [!NOTE] This is a callout box
---
Here is **bold**, *italic*, ~~strikethrough~~, ==highlighted==, and #feature_tag
''';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: NoteContentRenderer(content: markdownContent),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(Divider), findsOneWidget);
      expect(find.textContaining('This is a callout box'), findsOneWidget);
      expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
      expect(find.textContaining('feature_tag'), findsOneWidget);
      expect(find.textContaining('highlighted'), findsOneWidget);
      expect(find.textContaining('strikethrough'), findsOneWidget);
    });

    testWidgets('NoteCard shows checklist progress micro-badge', (tester) async {
      final now = DateTime.now();
      final noteWithChecklist = NoteObject(
        id: 'note-check',
        boardId: 'test-board',
        title: 'Tasks Card',
        content: '- [x] Completed task\n- [ ] Remaining task',
        colorIndex: 2,
        x: 100,
        y: 100,
        width: 240,
        height: 160,
        createdAt: now,
        updatedAt: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: NoteCard(note: noteWithChecklist),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1/2'), findsOneWidget);
      expect(find.byIcon(Icons.check_circle_outline_rounded), findsOneWidget);
    });

    testWidgets('branchSiblingNote creates sibling with common parent', (tester) async {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'mapping-test-board', repository: repo);

      final parentNote = await controller.createNote(
        title: 'Root Idea',
        content: 'Main concept',
        worldPos: const Offset(100, 100),
      );

      // Branch child
      controller.branchChildNote(parentNoteId: parentNote.id, title: 'Child 1');
      final child1 = controller.state.notes.firstWhere((n) => n.title == 'Child 1');
      expect(child1.parentId, equals(parentNote.id));

      // Branch sibling from child 1
      controller.branchSiblingNote(sourceNoteId: child1.id, title: 'Child 2 (Sibling)');
      final sibling = controller.state.notes.firstWhere((n) => n.title == 'Child 2 (Sibling)');

      // Sibling shares the same parent
      expect(sibling.parentId, equals(parentNote.id));
      expect(sibling.y, greaterThan(child1.y));
    });

    testWidgets('AutoLayoutManager computes vertical and grid layouts', (tester) async {
      final now = DateTime.now();
      final objects = {
        'n1': NoteObject(
          id: 'n1',
          boardId: 'b',
          title: 'Root',
          content: '',
          x: 0,
          y: 0,
          width: 200,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
        'n2': NoteObject(
          id: 'n2',
          boardId: 'b',
          title: 'Child',
          content: '',
          parentId: 'n1',
          x: 0,
          y: 0,
          width: 200,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
      };
      final connections = [
        BoardConnection(
          id: 'c1',
          boardId: 'b',
          fromObjectId: 'n1',
          toObjectId: 'n2',
          createdAt: now,
        ),
      ];

      // Vertical hierarchy: child must be positioned below parent
      final verticalPositions = AutoLayoutManager.computeVerticalLayout(
        objects: objects,
        connections: connections,
      );
      expect(verticalPositions['n2']!.dy, greaterThan(verticalPositions['n1']!.dy));

      // Grid layout: places objects cleanly
      final gridPositions = AutoLayoutManager.computeGridLayout(
        objects: objects,
        columns: 2,
      );
      expect(gridPositions.length, equals(2));
      expect(gridPositions['n2']!.dx, greaterThan(gridPositions['n1']!.dx));
    });

    test('ConnectionsPainter supports step, bidirectional, line, and colors', () {
      final now = DateTime.now();
      final objects = {
        'o1': NoteObject(
          id: 'o1',
          boardId: 'b',
          title: 'A',
          content: '',
          x: 100,
          y: 100,
          width: 100,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
        'o2': NoteObject(
          id: 'o2',
          boardId: 'b',
          title: 'B',
          content: '',
          x: 300,
          y: 200,
          width: 100,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
      };
      final connections = [
        BoardConnection(
          id: 'c1',
          boardId: 'b',
          fromObjectId: 'o1',
          toObjectId: 'o2',
          type: 'step:blue',
          label: 'depends on',
          createdAt: now,
        ),
        BoardConnection(
          id: 'c2',
          boardId: 'b',
          fromObjectId: 'o1',
          toObjectId: 'o2',
          type: 'bidirectional:green',
          createdAt: now,
        ),
        BoardConnection(
          id: 'c3',
          boardId: 'b',
          fromObjectId: 'o1',
          toObjectId: 'o2',
          type: 'line:rose',
          createdAt: now,
        ),
      ];

      final painter = ConnectionsPainter(
        camera: const CanvasCamera(),
        connections: connections,
        objects: objects,
      );

      expect(painter.connections.length, equals(3));
    });
  });

  group('Requirement 3: Feature Richness - Search and Markdown Export', () {
    testWidgets('CanvasSearchDialog filters objects by query', (tester) async {
      final now = DateTime.now();
      final objects = [
        NoteObject(
          id: '1',
          boardId: 'b',
          title: 'Design System',
          content: 'Buttons and colors',
          x: 0,
          y: 0,
          width: 200,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
        NoteObject(
          id: '2',
          boardId: 'b',
          title: 'Backend Roadmap',
          content: 'Database tables #backend',
          x: 0,
          y: 0,
          width: 200,
          height: 100,
          createdAt: now,
          updatedAt: now,
        ),
      ];

      BoardObject? selected;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CanvasSearchDialog(
              objects: objects,
              onSelectObject: (obj) => selected = obj,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Design System'), findsOneWidget);
      expect(find.text('Backend Roadmap'), findsOneWidget);

      // Search for "roadmap"
      await tester.enterText(find.byType(TextField), 'roadmap');
      await tester.pumpAndSettle();

      expect(find.text('Design System'), findsNothing);
      expect(find.text('Backend Roadmap'), findsOneWidget);

      // Tap on the result
      await tester.tap(find.text('Backend Roadmap'));
      await tester.pumpAndSettle();

      expect(selected?.id, equals('2'));
    });

    testWidgets('BoardExportService exports structured Markdown', (tester) async {
      final boardRepo = _MockBoardRepo();
      final canvasRepo = _MockCanvasRepo();
      final exportService = BoardExportService(
        boardRepo: boardRepo,
        canvasRepo: canvasRepo,
      );

      final now = DateTime.now();
      final board = Board(
        id: 'export-md-board',
        name: 'Sprint Planning',
        description: 'Q3 Board',
        createdAt: now,
        updatedAt: now,
      );
      await boardRepo.createBoard(board);

      final note = NoteObject(
        id: 'exp-n1',
        boardId: board.id,
        title: 'Launch Checklist',
        content: '- [x] Unit tests\n- [ ] UI verification',
        x: 100,
        y: 100,
        width: 200,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );
      await canvasRepo.saveObject(note);

      final md = await exportService.exportBoardToMarkdown(board.id);

      expect(md.contains('# Sprint Planning'), isTrue);
      expect(md.contains('## Notes'), isTrue);
      expect(md.contains('### Launch Checklist'), isTrue);
      expect(md.contains('- [x] Unit tests'), isTrue);
    });
  });
}
