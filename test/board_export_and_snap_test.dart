import 'package:flutter_test/flutter_test.dart';
import 'package:notesboard/features/canvas/domain/board_object.dart';
import 'package:notesboard/features/canvas/engine/canvas_controller.dart';
import 'package:notesboard/features/canvas/data/canvas_repository.dart';
import 'package:notesboard/features/canvas/domain/board_connection.dart';

class MockCanvasRepository implements CanvasRepository {
  List<BoardObject> objects = [];
  List<BoardConnection> connections = [];

  @override
  Future<void> deleteConnection(String id) async =>
      connections.removeWhere((c) => c.id == id);

  @override
  Future<void> deleteConnectionsForObject(String objectId) async =>
      connections.removeWhere(
          (c) => c.fromObjectId == objectId || c.toObjectId == objectId);

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
  group('Snap to Grid & Canvas Controller Tests', () {
    test('snapToGrid toggle updates state', () {
      final repo = MockCanvasRepository();
      final controller = CanvasController(boardId: 'test-b', repository: repo);

      expect(controller.state.snapToGrid, false);
      controller.toggleSnapToGrid();
      expect(controller.state.snapToGrid, true);
      controller.toggleSnapToGrid();
      expect(controller.state.snapToGrid, false);
    });

    test('updateObjectPosition snaps to 24px grid when enabled', () {
      final repo = MockCanvasRepository();
      final now = DateTime.now();
      final note = NoteObject(
        id: 'note-1',
        boardId: 'test-b',
        title: 'Title',
        content: 'Content',
        x: 0,
        y: 0,
        width: 200,
        height: 150,
        createdAt: now,
        updatedAt: now,
      );

      final controller = CanvasController(boardId: 'test-b', repository: repo);
      controller.state = controller.state.copyWith(
        objects: {'note-1': note},
        snapToGrid: true,
      );

      // Move to (35, 55): should snap to nearest multiple of 24 (24, 48)
      // 35 / 24 = 1.458 -> 1 -> 24
      // 55 / 24 = 2.29 -> 2 -> 48
      controller.updateObjectPosition('note-1', const Offset(35, 55));

      final updated = controller.state.objects['note-1']!;
      expect(updated.x, 24.0);
      expect(updated.y, 48.0);
    });
  });
}
