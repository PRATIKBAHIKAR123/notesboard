import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/board_object.dart';
import '../domain/board_connection.dart';

abstract class CanvasRepository {
  Future<List<BoardObject>> getObjects(String boardId);
  Stream<List<BoardObject>> watchObjects(String boardId);
  Future<void> saveObject(BoardObject object);
  Future<void> saveObjects(List<BoardObject> objects);
  Future<void> deleteObject(String id, BoardObjectType type);

  Future<List<BoardConnection>> getConnections(String boardId);
  Stream<List<BoardConnection>> watchConnections(String boardId);
  Future<void> saveConnection(BoardConnection connection);
  Future<void> deleteConnection(String id);
  Future<void> deleteConnectionsForObject(String objectId);

  Future<void> seedDemoDataIfEmpty();
}

class DriftCanvasRepository implements CanvasRepository {
  final AppDatabase _db;

  DriftCanvasRepository(this._db);

  @override
  Future<List<BoardObject>> getObjects(String boardId) async {
    final notes = await (_db.select(_db.notesTable)..where((t) => t.boardId.equals(boardId))).get();
    final images = await (_db.select(_db.imagesTable)..where((t) => t.boardId.equals(boardId))).get();
    final groups = await (_db.select(_db.groupsTable)..where((t) => t.boardId.equals(boardId))).get();

    final List<BoardObject> results = [];
    results.addAll(groups.map(_mapRowToGroup));
    results.addAll(images.map(_mapRowToImage));
    results.addAll(notes.map(_mapRowToNote));
    return results;
  }

  @override
  Stream<List<BoardObject>> watchObjects(String boardId) {
    return (_db.select(_db.notesTable)..where((t) => t.boardId.equals(boardId)))
        .watch()
        .asyncMap((notes) async {
      final images = await (_db.select(_db.imagesTable)..where((t) => t.boardId.equals(boardId))).get();
      final groups = await (_db.select(_db.groupsTable)..where((t) => t.boardId.equals(boardId))).get();

      final List<BoardObject> results = [];
      results.addAll(groups.map(_mapRowToGroup));
      results.addAll(images.map(_mapRowToImage));
      results.addAll(notes.map(_mapRowToNote));
      return results;
    });
  }

  @override
  Future<void> saveObject(BoardObject object) async {
    switch (object) {
      case NoteObject note:
        await _db.into(_db.notesTable).insertOnConflictUpdate(
              NotesTableCompanion.insert(
                id: note.id,
                boardId: note.boardId,
                title: note.title,
                content: note.content,
                colorIndex: Value(note.colorIndex),
                x: note.x,
                y: note.y,
                width: note.width,
                height: note.height,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                parentId: Value(note.parentId),
              ),
            );
        break;
      case ImageObject img:
        await _db.into(_db.imagesTable).insertOnConflictUpdate(
              ImagesTableCompanion.insert(
                id: img.id,
                boardId: img.boardId,
                imageUrl: img.imageUrl,
                caption: Value(img.caption),
                x: img.x,
                y: img.y,
                width: img.width,
                height: img.height,
                createdAt: img.createdAt,
                updatedAt: img.updatedAt,
                parentId: Value(img.parentId),
              ),
            );
        break;
      case GroupObject group:
        await _db.into(_db.groupsTable).insertOnConflictUpdate(
              GroupsTableCompanion.insert(
                id: group.id,
                boardId: group.boardId,
                title: group.title,
                x: group.x,
                y: group.y,
                width: group.width,
                height: group.height,
                createdAt: group.createdAt,
                updatedAt: group.updatedAt,
              ),
            );
        break;
    }
  }

  @override
  Future<void> saveObjects(List<BoardObject> objects) async {
    await _db.batch((batch) {
      for (final obj in objects) {
        switch (obj) {
          case NoteObject note:
            batch.insert(
              _db.notesTable,
              NotesTableCompanion.insert(
                id: note.id,
                boardId: note.boardId,
                title: note.title,
                content: note.content,
                colorIndex: Value(note.colorIndex),
                x: note.x,
                y: note.y,
                width: note.width,
                height: note.height,
                createdAt: note.createdAt,
                updatedAt: note.updatedAt,
                parentId: Value(note.parentId),
              ),
              mode: InsertMode.insertOrReplace,
            );
            break;
          case ImageObject img:
            batch.insert(
              _db.imagesTable,
              ImagesTableCompanion.insert(
                id: img.id,
                boardId: img.boardId,
                imageUrl: img.imageUrl,
                caption: Value(img.caption),
                x: img.x,
                y: img.y,
                width: img.width,
                height: img.height,
                createdAt: img.createdAt,
                updatedAt: img.updatedAt,
                parentId: Value(img.parentId),
              ),
              mode: InsertMode.insertOrReplace,
            );
            break;
          case GroupObject group:
            batch.insert(
              _db.groupsTable,
              GroupsTableCompanion.insert(
                id: group.id,
                boardId: group.boardId,
                title: group.title,
                x: group.x,
                y: group.y,
                width: group.width,
                height: group.height,
                createdAt: group.createdAt,
                updatedAt: group.updatedAt,
              ),
              mode: InsertMode.insertOrReplace,
            );
            break;
        }
      }
    });
  }

  @override
  Future<void> deleteObject(String id, BoardObjectType type) async {
    await _db.transaction(() async {
      await deleteConnectionsForObject(id);
      switch (type) {
        case BoardObjectType.note:
          await (_db.delete(_db.notesTable)..where((t) => t.id.equals(id))).go();
          break;
        case BoardObjectType.image:
          await (_db.delete(_db.imagesTable)..where((t) => t.id.equals(id))).go();
          break;
        case BoardObjectType.group:
          await (_db.delete(_db.groupsTable)..where((t) => t.id.equals(id))).go();
          break;
      }
    });
  }

  @override
  Future<List<BoardConnection>> getConnections(String boardId) async {
    final rows = await (_db.select(_db.connectionsTable)..where((t) => t.boardId.equals(boardId))).get();
    return rows.map(_mapRowToConnection).toList();
  }

  @override
  Stream<List<BoardConnection>> watchConnections(String boardId) {
    return (_db.select(_db.connectionsTable)..where((t) => t.boardId.equals(boardId)))
        .watch()
        .map((rows) => rows.map(_mapRowToConnection).toList());
  }

  @override
  Future<void> saveConnection(BoardConnection connection) async {
    await _db.into(_db.connectionsTable).insertOnConflictUpdate(
          ConnectionsTableCompanion.insert(
            id: connection.id,
            boardId: connection.boardId,
            fromObjectId: connection.fromObjectId,
            toObjectId: connection.toObjectId,
            type: Value(connection.type),
            label: Value(connection.label),
            createdAt: connection.createdAt,
          ),
        );
  }

  @override
  Future<void> deleteConnection(String id) async {
    await (_db.delete(_db.connectionsTable)..where((t) => t.id.equals(id))).go();
  }

  @override
  Future<void> deleteConnectionsForObject(String objectId) async {
    await (_db.delete(_db.connectionsTable)
          ..where((t) => t.fromObjectId.equals(objectId) | t.toObjectId.equals(objectId)))
        .go();
  }

  @override
  Future<void> seedDemoDataIfEmpty() async {
    final existingBoards = await _db.select(_db.boardsTable).get();
    if (existingBoards.isNotEmpty) return;

    final now = DateTime.now();
    const demoBoardId = 'demo-board-project-planning';

    await _db.into(_db.boardsTable).insert(
          BoardsTableCompanion.insert(
            id: demoBoardId,
            name: 'Project Planning',
            description: const Value('Visual roadmap and architecture for Notesboard MVP'),
            createdAt: now,
            updatedAt: now,
          ),
        );

    // Seed Notes
    final note1 = NoteObject(
      id: 'demo-note-project',
      boardId: demoBoardId,
      x: 320,
      y: 120,
      width: 250,
      height: 140,
      title: 'Project: Notesboard',
      content: 'A simplified visual note-taking application. Notes + Images + Visual Canvas + Simple Connections.',
      colorIndex: 0,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final note2 = NoteObject(
      id: 'demo-note-ui',
      boardId: demoBoardId,
      x: 140,
      y: 350,
      width: 230,
      height: 140,
      title: 'UI Design',
      content: 'Calm light canvas, cards with subtle borders, adaptive desktop and mobile responsive layout.',
      colorIndex: 2, // blue
      parentId: 'demo-note-project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final note3 = NoteObject(
      id: 'demo-note-dev',
      boardId: demoBoardId,
      x: 520,
      y: 350,
      width: 230,
      height: 140,
      title: 'Development',
      content: 'Local-first architecture with Drift SQLite, Riverpod state, and 60fps canvas engine.',
      colorIndex: 3, // green
      parentId: 'demo-note-project',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final note4 = NoteObject(
      id: 'demo-note-canvas',
      boardId: demoBoardId,
      x: 140,
      y: 560,
      width: 230,
      height: 140,
      title: 'Canvas Design',
      content: 'World coordinates, camera pan and zoom, resize handles, and connections behind objects.',
      colorIndex: 1, // yellow
      parentId: 'demo-note-ui',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    // Seed Image
    final img1 = ImageObject(
      id: 'demo-image-ref',
      boardId: demoBoardId,
      x: 520,
      y: 560,
      width: 240,
      height: 160,
      imageUrl: 'architecture_diagram',
      caption: 'Visual Workspace Architecture',
      parentId: 'demo-note-dev',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    // Seed Group
    final grp1 = GroupObject(
      id: 'demo-group-design',
      boardId: demoBoardId,
      x: 100,
      y: 300,
      width: 310,
      height: 440,
      title: 'Design Track',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    await saveObjects([grp1, img1, note1, note2, note3, note4]);

    // Seed Connections
    final conn1 = BoardConnection(
      id: 'demo-conn-1',
      boardId: demoBoardId,
      fromObjectId: 'demo-note-project',
      toObjectId: 'demo-note-ui',
      type: 'arrow',
      label: 'designs',
      createdAt: now,
    );

    final conn2 = BoardConnection(
      id: 'demo-conn-2',
      boardId: demoBoardId,
      fromObjectId: 'demo-note-project',
      toObjectId: 'demo-note-dev',
      type: 'arrow',
      label: 'builds',
      createdAt: now,
    );

    final conn3 = BoardConnection(
      id: 'demo-conn-3',
      boardId: demoBoardId,
      fromObjectId: 'demo-note-ui',
      toObjectId: 'demo-note-canvas',
      type: 'arrow',
      createdAt: now,
    );

    final conn4 = BoardConnection(
      id: 'demo-conn-4',
      boardId: demoBoardId,
      fromObjectId: 'demo-note-dev',
      toObjectId: 'demo-image-ref',
      type: 'arrow',
      label: 'spec',
      createdAt: now,
    );

    await saveConnection(conn1);
    await saveConnection(conn2);
    await saveConnection(conn3);
    await saveConnection(conn4);
  }

  NoteObject _mapRowToNote(NotesTableData row) {
    return NoteObject(
      id: row.id,
      boardId: row.boardId,
      title: row.title,
      content: row.content,
      colorIndex: row.colorIndex,
      x: row.x,
      y: row.y,
      width: row.width,
      height: row.height,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      parentId: row.parentId,
    );
  }

  ImageObject _mapRowToImage(ImagesTableData row) {
    return ImageObject(
      id: row.id,
      boardId: row.boardId,
      imageUrl: row.imageUrl,
      caption: row.caption,
      x: row.x,
      y: row.y,
      width: row.width,
      height: row.height,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      parentId: row.parentId,
    );
  }

  GroupObject _mapRowToGroup(GroupsTableData row) {
    return GroupObject(
      id: row.id,
      boardId: row.boardId,
      title: row.title,
      x: row.x,
      y: row.y,
      width: row.width,
      height: row.height,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }

  BoardConnection _mapRowToConnection(ConnectionsTableData row) {
    return BoardConnection(
      id: row.id,
      boardId: row.boardId,
      fromObjectId: row.fromObjectId,
      toObjectId: row.toObjectId,
      type: row.type,
      label: row.label,
      createdAt: row.createdAt,
    );
  }
}

final canvasRepositoryProvider = Provider<CanvasRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftCanvasRepository(db);
});
