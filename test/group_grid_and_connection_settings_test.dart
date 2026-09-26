import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesboard/features/canvas/data/canvas_repository.dart';
import 'package:notesboard/features/canvas/domain/board_connection.dart';
import 'package:notesboard/features/canvas/domain/board_object.dart';
import 'package:notesboard/features/canvas/domain/canvas_camera.dart';
import 'package:notesboard/features/canvas/engine/canvas_controller.dart';
import 'package:notesboard/features/canvas/presentation/board_canvas.dart';
import 'package:notesboard/features/canvas/presentation/selection_overlay.dart';
import 'package:notesboard/features/canvas/presentation/widgets/connection_editor_dialog.dart';
import 'package:notesboard/features/canvas/presentation/widgets/group_card.dart';

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

  group('Group Grid Auto-Arrange & Preserving Containment', () {
    test('autoArrangeGrid with selected group only arranges contained notes and auto-expands group', () async {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-group-grid', repository: repo);

      final now = DateTime.now();

      // Create a group
      final group = GroupObject(
        id: 'group-1',
        boardId: 'test-group-grid',
        title: 'Project Group',
        x: 100,
        y: 100,
        width: 300,
        height: 200,
        createdAt: now,
        updatedAt: now,
      );

      // Create 2 notes inside the group
      final note1 = NoteObject(
        id: 'n1',
        boardId: 'test-group-grid',
        title: 'Note 1',
        content: 'Inside Group',
        x: 120,
        y: 150,
        width: 200,
        height: 120,
        createdAt: now,
        updatedAt: now,
      );

      final note2 = NoteObject(
        id: 'n2',
        boardId: 'test-group-grid',
        title: 'Note 2',
        content: 'Also Inside Group',
        x: 160,
        y: 180,
        width: 200,
        height: 120,
        createdAt: now,
        updatedAt: now,
      );

      // Create 1 note outside the group
      final outsideNote = NoteObject(
        id: 'n3-outside',
        boardId: 'test-group-grid',
        title: 'Outside Note',
        content: 'Far away',
        x: 800,
        y: 400,
        width: 200,
        height: 120,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          group.id: group,
          note1.id: note1,
          note2.id: note2,
          outsideNote.id: outsideNote,
        },
        selectedObjectId: group.id, // Group is selected!
      );

      // Trigger grid auto-arrange
      controller.autoArrangeGrid();

      final updatedGroup = controller.state.objects['group-1'] as GroupObject;
      final updatedN1 = controller.state.objects['n1']!;
      final updatedN2 = controller.state.objects['n2']!;
      final updatedOutside = controller.state.objects['n3-outside']!;

      // 1. Outside note was NOT moved
      expect(updatedOutside.x, equals(800.0));
      expect(updatedOutside.y, equals(400.0));

      // 2. Both note 1 and note 2 are strictly within the group bounding box
      expect(updatedN1.x, greaterThanOrEqualTo(updatedGroup.x));
      expect(updatedN1.y, greaterThan(updatedGroup.y));
      expect(updatedN1.x + updatedN1.width, lessThanOrEqualTo(updatedGroup.x + updatedGroup.width));
      expect(updatedN1.y + updatedN1.height, lessThanOrEqualTo(updatedGroup.y + updatedGroup.height));

      expect(updatedN2.x, greaterThanOrEqualTo(updatedGroup.x));
      expect(updatedN2.y, greaterThan(updatedGroup.y));
      expect(updatedN2.x + updatedN2.width, lessThanOrEqualTo(updatedGroup.x + updatedGroup.width));
      expect(updatedN2.y + updatedN2.height, lessThanOrEqualTo(updatedGroup.y + updatedGroup.height));

      // 3. Spacing between notes is generous (spacingX >= 72px)
      expect((updatedN2.x - (updatedN1.x + updatedN1.width)).abs(), greaterThanOrEqualTo(70.0));

      // 4. Group auto-expanded to fit the two side-by-side notes comfortably
      expect(updatedGroup.width, greaterThan(group.width));

      controller.dispose();
    });

    test('autoArrangeGrid preserves notes inside groups when no group is selected', () async {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-all-grid', repository: repo);
      final now = DateTime.now();

      final group = GroupObject(
        id: 'grp-a',
        boardId: 'test-all-grid',
        title: 'Team Alpha',
        x: 100,
        y: 100,
        width: 400,
        height: 300,
        createdAt: now,
        updatedAt: now,
      );

      final noteInside = NoteObject(
        id: 'n-alpha-1',
        boardId: 'test-all-grid',
        title: 'Alpha Task',
        content: '',
        x: 120,
        y: 160,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final freeNote = NoteObject(
        id: 'n-free',
        boardId: 'test-all-grid',
        title: 'Free Note',
        content: '',
        x: 600,
        y: 600,
        width: 200,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          group.id: group,
          noteInside.id: noteInside,
          freeNote.id: freeNote,
        },
        clearSelection: true,
      );

      // Trigger grid auto-arrange with no selection
      controller.autoArrangeGrid();

      final updatedGrp = controller.state.objects['grp-a'] as GroupObject;
      final updatedNoteInside = controller.state.objects['n-alpha-1']!;

      // Note inside group MUST remain inside group bounds
      expect(updatedNoteInside.x, greaterThanOrEqualTo(updatedGrp.x));
      expect(updatedNoteInside.y, greaterThanOrEqualTo(updatedGrp.y));
      expect(updatedNoteInside.x + updatedNoteInside.width, lessThanOrEqualTo(updatedGrp.x + updatedGrp.width));
      expect(updatedNoteInside.y + updatedNoteInside.height, lessThanOrEqualTo(updatedGrp.y + updatedGrp.height));

      controller.dispose();
    });
  });

  group('Simplified Connection Settings & Interactive Badges', () {
    testWidgets('Interactive connection badge is rendered and opens editor dialog', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const boardId = 'badge-test-board';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasRepositoryProvider.overrideWithValue(_MockCanvasRepo()),
          ],
          child: const MaterialApp(
            home: BoardCanvas(
              boardId: boardId,
              boardName: 'Badge Test Board',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider(boardId).notifier);

      // Create two notes and connect them
      final n1 = await controller.createNote(
        title: 'Source Card',
        content: 'Start',
        worldPos: const Offset(100, 100),
      );
      final n2 = await controller.createNote(
        title: 'Target Card',
        content: 'End',
        worldPos: const Offset(400, 100),
      );

      controller.startConnecting(n1.id);
      controller.completeConnecting(n2.id);
      final conn1 = controller.state.connections.first;
      controller.editConnection(connectionId: conn1.id, label: 'depends on', type: 'step:blue');
      await tester.pumpAndSettle();

      // The interactive badge should be rendered with label 'depends on'
      expect(find.text('depends on'), findsOneWidget);

      // Tapping the connection badge directly opens the ConnectionEditorDialog!
      await tester.tap(find.text('depends on'));
      await tester.pumpAndSettle();

      expect(find.byType(ConnectionEditorDialog), findsOneWidget);
      expect(find.text('Connection Settings'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Unlabeled connection never shows connection type name on canvas', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const boardId = 'no-conn-type-board';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasRepositoryProvider.overrideWithValue(_MockCanvasRepo()),
          ],
          child: const MaterialApp(
            home: BoardCanvas(
              boardId: boardId,
              boardName: 'No Type Badge Board',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider(boardId).notifier);

      final n1 = await controller.createNote(
        title: 'Card A',
        content: 'Alpha',
        worldPos: const Offset(100, 100),
      );
      final n2 = await controller.createNote(
        title: 'Card B',
        content: 'Beta',
        worldPos: const Offset(400, 100),
      );

      // Connect without label (type defaults to 'arrow')
      controller.startConnecting(n1.id);
      controller.completeConnecting(n2.id);
      await tester.pumpAndSettle();

      // Ensure connection type name is NOT rendered anywhere on canvas
      expect(find.text('arrow'), findsNothing);
      expect(find.text('ARROW'), findsNothing);
      expect(find.text('curved'), findsNothing);
      expect(find.text('CURVED'), findsNothing);
      expect(find.text('step'), findsNothing);
      expect(find.text('STEP'), findsNothing);

      // Now set type to 'curved:green' with no label
      final conn = controller.state.connections.first;
      controller.editConnection(connectionId: conn.id, type: 'curved:green');
      await tester.pumpAndSettle();

      expect(find.text('curved'), findsNothing);
      expect(find.text('CURVED'), findsNothing);
      expect(find.text('arrow'), findsNothing);

      // If user sets a label, ONLY the user's label text is shown
      controller.editConnection(connectionId: conn.id, label: 'data flow');
      await tester.pumpAndSettle();

      expect(find.text('data flow'), findsOneWidget);
      expect(find.text('curved'), findsNothing);
    });

    testWidgets('Selected note action bar displays Manage Connections button', (tester) async {
      tester.view.physicalSize = const Size(1200, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const boardId = 'action-bar-conn-board';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            canvasRepositoryProvider.overrideWithValue(_MockCanvasRepo()),
          ],
          child: const MaterialApp(
            home: BoardCanvas(
              boardId: boardId,
              boardName: 'Action Bar Connection Test',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final element = tester.element(find.byType(BoardCanvas));
      final container = ProviderScope.containerOf(element);
      final controller = container.read(canvasControllerProvider(boardId).notifier);

      final n1 = await controller.createNote(
        title: 'Feature Note',
        content: '',
        worldPos: const Offset(100, 100),
      );
      final n2 = await controller.createNote(
        title: 'Release Note',
        content: '',
        worldPos: const Offset(400, 100),
      );

      controller.startConnecting(n1.id);
      controller.completeConnecting(n2.id);
      final conn2 = controller.state.connections.first;
      controller.editConnection(connectionId: conn2.id, label: 'blocks', type: 'arrow:rose');
      await tester.pumpAndSettle();

      // Select Feature Note
      controller.selectObject(n1.id);
      await tester.pumpAndSettle();

      // CanvasActionBar should display the manage connections icon
      expect(find.byIcon(Icons.hub_outlined), findsOneWidget);

      // Tap on the manage connections button
      await tester.tap(find.byIcon(Icons.hub_outlined));
      await tester.pumpAndSettle();

      // Modal dialog showing connections appears
      expect(find.textContaining('Connections (1)'), findsOneWidget);
      expect(find.textContaining('To: Release Note'), findsOneWidget);

      // Close modal
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();
    });

    testWidgets('CanvasSelectionOverlay renders easily clickable Child and Sibling branch buttons', (tester) async {
      bool branchedChild = false;
      bool branchedSibling = false;

      final note = NoteObject(
        id: 'test-note',
        boardId: 'b',
        title: 'Main Note',
        content: '',
        x: 100,
        y: 100,
        width: 200,
        height: 120,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const camera = CanvasCamera(
        pan: Offset.zero,
        zoom: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CanvasSelectionOverlay(
                  object: note,
                  camera: camera,
                  onBranchRight: () => branchedChild = true,
                  onBranchBottom: () => branchedSibling = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Find Branch Child button and tap it
      final childButton = find.text('Child');
      expect(childButton, findsOneWidget);
      await tester.tap(childButton);
      expect(branchedChild, isTrue);

      // Find Branch Sibling button and tap it
      final siblingButton = find.text('Sibling');
      expect(siblingButton, findsOneWidget);
      await tester.tap(siblingButton);
      expect(branchedSibling, isTrue);
    });

    testWidgets('CanvasActionBar renders Branch Child and Branch Sibling buttons', (tester) async {
      bool branchedChild = false;
      bool branchedSibling = false;

      final note = NoteObject(
        id: 'test-note',
        boardId: 'b',
        title: 'Action Bar Note',
        content: '',
        x: 100,
        y: 100,
        width: 200,
        height: 120,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      const camera = CanvasCamera(
        pan: Offset.zero,
        zoom: 1.0,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                CanvasActionBar(
                  object: note,
                  camera: camera,
                  onBranch: () => branchedChild = true,
                  onBranchSibling: () => branchedSibling = true,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.call_split_rounded), findsOneWidget);
      expect(find.byIcon(Icons.subdirectory_arrow_right_rounded), findsOneWidget);

      await tester.tap(find.byIcon(Icons.call_split_rounded));
      expect(branchedChild, isTrue);

      await tester.tap(find.byIcon(Icons.subdirectory_arrow_right_rounded));
      expect(branchedSibling, isTrue);
    });

    testWidgets('GroupCard renders onArrange button in header and triggers callback', (tester) async {
      bool arranged = false;
      final group = GroupObject(
        id: 'grp-header',
        boardId: 'b',
        title: 'Test Group Header',
        x: 50,
        y: 50,
        width: 300,
        height: 200,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: GroupCard(
              group: group,
              onArrange: () => arranged = true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final arrangeIcon = find.byIcon(Icons.grid_view_rounded);
      expect(arrangeIcon, findsOneWidget);

      await tester.tap(arrangeIcon);
      expect(arranged, isTrue);
    });

    test('autoArrangeGrid when a note inside a group is selected automatically targets parent group', () async {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-group-target', repository: repo);
      final now = DateTime.now();

      final group = GroupObject(
        id: 'grp-1',
        boardId: 'test-group-target',
        title: 'Parent Group',
        x: 100,
        y: 100,
        width: 300,
        height: 200,
        createdAt: now,
        updatedAt: now,
      );

      final noteInside = NoteObject(
        id: 'n-child-1',
        boardId: 'test-group-target',
        title: 'Child 1',
        content: '',
        x: 120,
        y: 160,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final noteInside2 = NoteObject(
        id: 'n-child-2',
        boardId: 'test-group-target',
        title: 'Child 2',
        content: '',
        x: 140,
        y: 170,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final outside = NoteObject(
        id: 'n-outside',
        boardId: 'test-group-target',
        title: 'Outside',
        content: '',
        x: 900,
        y: 500,
        width: 200,
        height: 120,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          group.id: group,
          noteInside.id: noteInside,
          noteInside2.id: noteInside2,
          outside.id: outside,
        },
        selectedObjectId: noteInside.id, // NOTE inside group is selected!
      );

      controller.autoArrangeGrid();

      // Outside note was NOT moved
      expect(controller.state.objects['n-outside']!.x, equals(900.0));

      // Both notes are neatly inside the group with generous spacing
      final uGroup = controller.state.objects['grp-1'] as GroupObject;
      final u1 = controller.state.objects['n-child-1']!;
      final u2 = controller.state.objects['n-child-2']!;

      expect(u1.x, greaterThanOrEqualTo(uGroup.x));
      expect(u1.y, greaterThan(uGroup.y));
      expect(u2.x, greaterThanOrEqualTo(uGroup.x));
      expect(u2.y, greaterThan(uGroup.y));
      expect((u2.x - (u1.x + u1.width)).abs(), greaterThanOrEqualTo(100.0));

      controller.dispose();
    });

    test('Moving a group translates all contained objects together', () {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-group-move', repository: repo);
      final now = DateTime.now();

      final group = GroupObject(
        id: 'grp-move',
        boardId: 'test-group-move',
        x: 100,
        y: 100,
        width: 400,
        height: 300,
        title: 'Project Group',
        createdAt: now,
        updatedAt: now,
      );

      final noteInside = NoteObject(
        id: 'n-in',
        boardId: 'test-group-move',
        title: 'Inside Note',
        content: '',
        x: 140,
        y: 160,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final noteOutside = NoteObject(
        id: 'n-out',
        boardId: 'test-group-move',
        title: 'Outside Note',
        content: '',
        x: 800,
        y: 800,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          group.id: group,
          noteInside.id: noteInside,
          noteOutside.id: noteOutside,
        },
      );

      // Drag group by +150 in X and +200 in Y
      controller.updateObjectPosition('grp-move', const Offset(250, 300));

      // Contained note moved by the exact same delta (+150, +200)
      expect(controller.state.objects['n-in']!.x, equals(290.0));
      expect(controller.state.objects['n-in']!.y, equals(360.0));

      // Outside note was NOT affected
      expect(controller.state.objects['n-out']!.x, equals(800.0));
      expect(controller.state.objects['n-out']!.y, equals(800.0));

      controller.dispose();
    });

    test('Selective notes autoArrangeGrid arranges cluster at minX/minY and leaves outside notes untouched', () {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-selective-grid', repository: repo);
      final now = DateTime.now();

      final n1 = NoteObject(
        id: 'n1',
        boardId: 'test-selective-grid',
        title: 'Note 1',
        content: '',
        x: 200,
        y: 300,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final n2 = NoteObject(
        id: 'n2',
        boardId: 'test-selective-grid',
        title: 'Note 2',
        content: '',
        x: 200,
        y: 500,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final conn = BoardConnection(
        id: 'c1',
        boardId: 'test-selective-grid',
        fromObjectId: 'n1',
        toObjectId: 'n2',
        type: 'arrow',
        createdAt: now,
      );

      final unrelated = NoteObject(
        id: 'unrelated',
        boardId: 'test-selective-grid',
        title: 'Unrelated Note',
        content: '',
        x: 950,
        y: 120,
        width: 200,
        height: 120,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          n1.id: n1,
          n2.id: n2,
          unrelated.id: unrelated,
        },
        connections: [conn],
        selectedObjectId: 'n2', // Selective note in cluster selected
      );

      controller.autoArrangeGrid();

      // Unrelated note is totally untouched
      expect(controller.state.objects['unrelated']!.x, equals(950.0));
      expect(controller.state.objects['unrelated']!.y, equals(120.0));

      // Cluster was organized starting at original minX (200) and minY (300)
      final u1 = controller.state.objects['n1']!;
      final u2 = controller.state.objects['n2']!;
      expect(u1.x, equals(200.0));
      expect(u1.y, equals(300.0));
      expect(u2.x, equals(200.0 + 180.0 + 110.0)); // Placed in next column of 2-item grid
      expect(u2.y, equals(300.0));

      controller.dispose();
    });

    test('Single selected note without connections does not scramble the entire board', () {
      final repo = _MockCanvasRepo();
      final controller = CanvasController(boardId: 'test-single-note', repository: repo);
      final now = DateTime.now();

      final solitary = NoteObject(
        id: 'solitary',
        boardId: 'test-single-note',
        title: 'Solo Note',
        content: '',
        x: 400,
        y: 400,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      final other = NoteObject(
        id: 'other',
        boardId: 'test-single-note',
        title: 'Other Note',
        content: '',
        x: 100,
        y: 100,
        width: 180,
        height: 100,
        createdAt: now,
        updatedAt: now,
      );

      controller.state = controller.state.copyWith(
        objects: {
          solitary.id: solitary,
          other.id: other,
        },
        selectedObjectId: 'solitary',
      );

      controller.autoArrangeGrid();

      // Neither note is scrambled across the canvas
      expect(controller.state.objects['other']!.x, equals(100.0));
      expect(controller.state.objects['other']!.y, equals(100.0));
      expect(controller.state.objects['solitary']!.x, equals(400.0));
      expect(controller.state.objects['solitary']!.y, equals(400.0));

      controller.dispose();
    });
  });
}
