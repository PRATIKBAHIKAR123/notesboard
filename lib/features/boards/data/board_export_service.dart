import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../../canvas/data/canvas_repository.dart';
import '../../canvas/domain/board_connection.dart';
import '../../canvas/domain/board_object.dart';
import '../domain/board.dart';
import 'board_repository.dart';

class BoardExportService {
  final BoardRepository _boardRepo;
  final CanvasRepository _canvasRepo;

  BoardExportService({
    required BoardRepository boardRepo,
    required CanvasRepository canvasRepo,
  })  : _boardRepo = boardRepo,
        _canvasRepo = canvasRepo;

  /// Serializes an entire board and all its objects & connections into a formatted JSON string.
  Future<String> exportBoardToJson(String boardId) async {
    final board = await _boardRepo.getBoardById(boardId);
    if (board == null) throw Exception('Board not found: $boardId');

    final objects = await _canvasRepo.getObjects(boardId);
    final connections = await _canvasRepo.getConnections(boardId);

    final Map<String, dynamic> data = {
      'format': 'notesboard',
      'version': 1,
      'exportedAt': DateTime.now().toIso8601String(),
      'board': board.toJson(),
      'objects': objects.map((o) => o.toJson()).toList(),
      'connections': connections.map((c) => c.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(data);
  }

  /// Exports all notes, groups, and connections on a board as structured Markdown.
  Future<String> exportBoardToMarkdown(String boardId) async {
    final board = await _boardRepo.getBoardById(boardId);
    if (board == null) throw Exception('Board not found: $boardId');

    final objects = await _canvasRepo.getObjects(boardId);
    final connections = await _canvasRepo.getConnections(boardId);

    final buffer = StringBuffer();
    buffer.writeln('# ${board.name}');
    if (board.description != null && board.description!.isNotEmpty) {
      buffer.writeln(board.description);
    }
    buffer.writeln();
    buffer.writeln('> Exported from Notesboard on ${DateTime.now().toLocal().toString().split('.')[0]}');
    buffer.writeln();

    // 1. Notes
    final notes = objects.whereType<NoteObject>().toList();
    if (notes.isNotEmpty) {
      buffer.writeln('## Notes (${notes.length})');
      buffer.writeln();
      for (final note in notes) {
        buffer.writeln('### ${note.title.isEmpty ? 'Untitled Note' : note.title}');
        if (note.content.isNotEmpty) {
          buffer.writeln(note.content);
        }
        buffer.writeln();
      }
    }

    // 2. Groups
    final groups = objects.whereType<GroupObject>().toList();
    if (groups.isNotEmpty) {
      buffer.writeln('## Groups (${groups.length})');
      buffer.writeln();
      for (final g in groups) {
        buffer.writeln('- **${g.title}**');
      }
      buffer.writeln();
    }

    // 3. Relationships & Connections
    if (connections.isNotEmpty) {
      final objMap = {for (final o in objects) o.id: o};
      buffer.writeln('## Connections & Relationships');
      buffer.writeln();
      for (final conn in connections) {
        final from = objMap[conn.fromObjectId];
        final to = objMap[conn.toObjectId];
        if (from == null || to == null) continue;

        final fromName = from is NoteObject ? (from.title.isEmpty ? 'Untitled Note' : from.title) : (from is GroupObject ? from.title : 'Image');
        final toName = to is NoteObject ? (to.title.isEmpty ? 'Untitled Note' : to.title) : (to is GroupObject ? to.title : 'Image');
        final label = conn.label != null && conn.label!.isNotEmpty ? ' [${conn.label}]' : '';
        buffer.writeln('- "$fromName" --$label--> "$toName"');
      }
      buffer.writeln();
    }

    return buffer.toString();
  }

  /// Imports a board from JSON, re-mapping IDs to prevent collisions.
  Future<Board> importBoardFromJson(String jsonString, {String? customName}) async {
    final dynamic decoded = jsonDecode(jsonString);
    if (decoded is! Map<String, dynamic> || decoded['format'] != 'notesboard') {
      throw const FormatException('Invalid Notesboard JSON backup format');
    }

    final rawBoard = decoded['board'] as Map<String, dynamic>;
    final rawObjects = (decoded['objects'] as List<dynamic>?) ?? [];
    final rawConnections = (decoded['connections'] as List<dynamic>?) ?? [];

    final now = DateTime.now();
    final newBoardId = IdGenerator.generate();
    final originalName = rawBoard['name'] as String? ?? 'Imported Board';

    final newBoard = Board(
      id: newBoardId,
      name: customName ?? '$originalName (Imported)',
      description: rawBoard['description'] as String?,
      thumbnail: rawBoard['thumbnail'] as String?,
      createdAt: now,
      updatedAt: now,
    );

    await _boardRepo.createBoard(newBoard);

    // Map old object IDs to new object IDs
    final Map<String, String> idMapping = {};
    for (final raw in rawObjects) {
      final oldId = raw['id'] as String;
      idMapping[oldId] = IdGenerator.generate();
    }

    // Reconstruct objects with new IDs and re-mapped parentId
    final List<BoardObject> newObjects = [];
    for (final raw in rawObjects) {
      final oldId = raw['id'] as String;
      final newId = idMapping[oldId]!;
      final type = raw['type'] as String;
      final oldParentId = raw['parentId'] as String?;
      final newParentId = oldParentId != null ? idMapping[oldParentId] : null;

      if (type == 'note') {
        newObjects.add(NoteObject(
          id: newId,
          boardId: newBoardId,
          title: raw['title'] as String? ?? '',
          content: raw['content'] as String? ?? '',
          colorIndex: raw['colorIndex'] as int? ?? 0,
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
          createdAt: now,
          updatedAt: now,
          parentId: newParentId,
        ));
      } else if (type == 'image') {
        newObjects.add(ImageObject(
          id: newId,
          boardId: newBoardId,
          imageUrl: raw['imageUrl'] as String? ?? '',
          caption: raw['caption'] as String?,
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
          createdAt: now,
          updatedAt: now,
          parentId: newParentId,
        ));
      } else if (type == 'group') {
        newObjects.add(GroupObject(
          id: newId,
          boardId: newBoardId,
          title: raw['title'] as String? ?? 'Group',
          x: (raw['x'] as num).toDouble(),
          y: (raw['y'] as num).toDouble(),
          width: (raw['width'] as num).toDouble(),
          height: (raw['height'] as num).toDouble(),
          createdAt: now,
          updatedAt: now,
        ));
      }
    }

    if (newObjects.isNotEmpty) {
      await _canvasRepo.saveObjects(newObjects);
    }

    // Reconstruct connections with re-mapped source and target IDs
    for (final raw in rawConnections) {
      final oldFrom = raw['fromObjectId'] as String;
      final oldTo = raw['toObjectId'] as String;

      final newFrom = idMapping[oldFrom];
      final newTo = idMapping[oldTo];

      if (newFrom != null && newTo != null) {
        final conn = BoardConnection(
          id: IdGenerator.generate(),
          boardId: newBoardId,
          fromObjectId: newFrom,
          toObjectId: newTo,
          type: raw['type'] as String? ?? 'arrow',
          label: raw['label'] as String?,
          createdAt: now,
        );
        await _canvasRepo.saveConnection(conn);
      }
    }

    return newBoard;
  }
}

final boardExportServiceProvider = Provider<BoardExportService>((ref) {
  final boardRepo = ref.watch(boardRepositoryProvider);
  final canvasRepo = ref.watch(canvasRepositoryProvider);
  return BoardExportService(boardRepo: boardRepo, canvasRepo: canvasRepo);
});
