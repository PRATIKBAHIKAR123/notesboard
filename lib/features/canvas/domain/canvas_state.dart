import 'package:flutter/material.dart';
import 'board_object.dart';
import 'board_connection.dart';
import 'canvas_camera.dart';

/// Immutable state for a board canvas
class CanvasState {
  final String boardId;
  final Map<String, BoardObject> objects;
  final List<BoardConnection> connections;
  final CanvasCamera camera;
  final String? selectedObjectId;
  final String? connectingFromObjectId; // Non-null when user is in "Connect" mode
  final bool isLoading;
  final bool snapToGrid;

  const CanvasState({
    required this.boardId,
    this.objects = const {},
    this.connections = const [],
    this.camera = const CanvasCamera(),
    this.selectedObjectId,
    this.connectingFromObjectId,
    this.isLoading = false,
    this.snapToGrid = false,
  });

  bool get isConnecting => connectingFromObjectId != null;

  BoardObject? get selectedObject =>
      selectedObjectId != null ? objects[selectedObjectId] : null;

  List<NoteObject> get notes =>
      objects.values.whereType<NoteObject>().toList();

  List<ImageObject> get images =>
      objects.values.whereType<ImageObject>().toList();

  List<GroupObject> get groups =>
      objects.values.whereType<GroupObject>().toList();

  /// Computes the bounding rectangle encompassing all objects in world coordinates
  Rect get worldBounds {
    if (objects.isEmpty) {
      return Rect.zero;
    }
    double left = double.infinity;
    double top = double.infinity;
    double right = double.negativeInfinity;
    double bottom = double.negativeInfinity;

    for (final obj in objects.values) {
      if (obj.x < left) left = obj.x;
      if (obj.y < top) top = obj.y;
      if (obj.x + obj.width > right) right = obj.x + obj.width;
      if (obj.y + obj.height > bottom) bottom = obj.y + obj.height;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }

  CanvasState copyWith({
    String? boardId,
    Map<String, BoardObject>? objects,
    List<BoardConnection>? connections,
    CanvasCamera? camera,
    String? selectedObjectId,
    bool clearSelection = false,
    String? connectingFromObjectId,
    bool clearConnecting = false,
    bool? isLoading,
    bool? snapToGrid,
  }) {
    return CanvasState(
      boardId: boardId ?? this.boardId,
      objects: objects ?? this.objects,
      connections: connections ?? this.connections,
      camera: camera ?? this.camera,
      selectedObjectId: clearSelection ? null : (selectedObjectId ?? this.selectedObjectId),
      connectingFromObjectId: clearConnecting
          ? null
          : (connectingFromObjectId ?? this.connectingFromObjectId),
      isLoading: isLoading ?? this.isLoading,
      snapToGrid: snapToGrid ?? this.snapToGrid,
    );
  }
}
