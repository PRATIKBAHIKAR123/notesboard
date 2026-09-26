import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../domain/board.dart';

abstract class BoardRepository {
  Future<List<Board>> getBoards();
  Stream<List<Board>> watchBoards();
  Future<Board?> getBoardById(String id);
  Future<void> createBoard(Board board);
  Future<void> updateBoard(Board board);
  Future<void> deleteBoard(String id);
  Future<int> getBoardObjectCount(String boardId);
}

class DriftBoardRepository implements BoardRepository {
  final AppDatabase _db;

  DriftBoardRepository(this._db);

  @override
  Future<List<Board>> getBoards() async {
    final query = _db.select(_db.boardsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    final rows = await query.get();
    return rows.map(_mapRowToBoard).toList();
  }

  @override
  Stream<List<Board>> watchBoards() {
    final query = _db.select(_db.boardsTable)
      ..orderBy([(t) => OrderingTerm(expression: t.updatedAt, mode: OrderingMode.desc)]);
    return query.watch().map((rows) => rows.map(_mapRowToBoard).toList());
  }

  @override
  Future<Board?> getBoardById(String id) async {
    final query = _db.select(_db.boardsTable)..where((t) => t.id.equals(id));
    final row = await query.getSingleOrNull();
    return row != null ? _mapRowToBoard(row) : null;
  }

  @override
  Future<void> createBoard(Board board) async {
    await _db.into(_db.boardsTable).insert(
          BoardsTableCompanion.insert(
            id: board.id,
            name: board.name,
            createdAt: board.createdAt,
            updatedAt: board.updatedAt,
            thumbnail: Value(board.thumbnail),
            description: Value(board.description),
          ),
        );
  }

  @override
  Future<void> updateBoard(Board board) async {
    await (_db.update(_db.boardsTable)..where((t) => t.id.equals(board.id))).write(
          BoardsTableCompanion(
            name: Value(board.name),
            updatedAt: Value(board.updatedAt),
            thumbnail: Value(board.thumbnail),
            description: Value(board.description),
          ),
        );
  }

  @override
  Future<void> deleteBoard(String id) async {
    await _db.transaction(() async {
      await (_db.delete(_db.connectionsTable)..where((t) => t.boardId.equals(id))).go();
      await (_db.delete(_db.notesTable)..where((t) => t.boardId.equals(id))).go();
      await (_db.delete(_db.imagesTable)..where((t) => t.boardId.equals(id))).go();
      await (_db.delete(_db.groupsTable)..where((t) => t.boardId.equals(id))).go();
      await (_db.delete(_db.boardsTable)..where((t) => t.id.equals(id))).go();
    });
  }

  @override
  Future<int> getBoardObjectCount(String boardId) async {
    final notes = await (_db.select(_db.notesTable)..where((t) => t.boardId.equals(boardId))).get();
    final images = await (_db.select(_db.imagesTable)..where((t) => t.boardId.equals(boardId))).get();
    final groups = await (_db.select(_db.groupsTable)..where((t) => t.boardId.equals(boardId))).get();
    return notes.length + images.length + groups.length;
  }

  Board _mapRowToBoard(BoardsTableData row) {
    return Board(
      id: row.id,
      name: row.name,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
      thumbnail: row.thumbnail,
      description: row.description,
    );
  }
}

final boardRepositoryProvider = Provider<BoardRepository>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return DriftBoardRepository(db);
});
