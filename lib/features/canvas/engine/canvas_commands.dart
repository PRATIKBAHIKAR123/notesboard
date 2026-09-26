import 'dart:ui';
import '../domain/board_object.dart';
import '../domain/board_connection.dart';

/// Base command for undo/redo operations on the canvas
abstract class CanvasCommand {
  final String description;
  const CanvasCommand(this.description);
}

class CreateObjectCommand extends CanvasCommand {
  final BoardObject object;

  CreateObjectCommand(this.object) : super('Create ${object.type.name}');
}

class DeleteObjectCommand extends CanvasCommand {
  final BoardObject object;
  final List<BoardConnection> attachedConnections;

  DeleteObjectCommand({
    required this.object,
    required this.attachedConnections,
  }) : super('Delete ${object.type.name}');
}

class MoveObjectCommand extends CanvasCommand {
  final String objectId;
  final Offset oldPosition;
  final Offset newPosition;

  const MoveObjectCommand({
    required this.objectId,
    required this.oldPosition,
    required this.newPosition,
  }) : super('Move object');
}

class BatchMoveCommand extends CanvasCommand {
  final Map<String, Offset> oldPositions;
  final Map<String, Offset> newPositions;

  const BatchMoveCommand({
    required this.oldPositions,
    required this.newPositions,
  }) : super('Auto-arrange layout');
}

class ResizeObjectCommand extends CanvasCommand {
  final String objectId;
  final Rect oldRect;
  final Rect newRect;

  const ResizeObjectCommand({
    required this.objectId,
    required this.oldRect,
    required this.newRect,
  }) : super('Resize object');
}

class EditNoteCommand extends CanvasCommand {
  final String noteId;
  final String oldTitle;
  final String oldContent;
  final int oldColorIndex;
  final String newTitle;
  final String newContent;
  final int newColorIndex;

  const EditNoteCommand({
    required this.noteId,
    required this.oldTitle,
    required this.oldContent,
    required this.oldColorIndex,
    required this.newTitle,
    required this.newContent,
    required this.newColorIndex,
  }) : super('Edit note');
}

class CreateConnectionCommand extends CanvasCommand {
  final BoardConnection connection;

  const CreateConnectionCommand(this.connection) : super('Create connection');
}

class DeleteConnectionCommand extends CanvasCommand {
  final BoardConnection connection;

  const DeleteConnectionCommand(this.connection) : super('Delete connection');
}

class EditConnectionCommand extends CanvasCommand {
  final String connectionId;
  final String? oldLabel;
  final String oldType;
  final String? newLabel;
  final String newType;

  const EditConnectionCommand({
    required this.connectionId,
    required this.oldLabel,
    required this.oldType,
    required this.newLabel,
    required this.newType,
  }) : super('Edit connection');
}

class BranchNoteCommand extends CanvasCommand {
  final NoteObject childNote;
  final BoardConnection connection;

  const BranchNoteCommand({
    required this.childNote,
    required this.connection,
  }) : super('Branch child note');
}
