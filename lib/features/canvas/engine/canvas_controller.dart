import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/debouncer.dart';
import '../../../core/utils/id_generator.dart';
import '../data/canvas_repository.dart';
import '../domain/board_connection.dart';
import '../domain/board_object.dart';
import '../domain/canvas_camera.dart';
import '../domain/canvas_state.dart';
import 'auto_layout_manager.dart';
import 'canvas_commands.dart';
import 'connection_manager.dart';

/// Main Controller for the interactive visual canvas.
/// Manages canvas objects, camera transforms, selection, connection creation,
/// undo/redo history, and debounced local persistence.
class CanvasController extends StateNotifier<CanvasState> {
  final CanvasRepository _repository;
  final Debouncer _autosaveDebouncer =
      Debouncer(delay: AppConstants.autosaveDebounceDuration);

  final List<CanvasCommand> _undoStack = [];
  final List<CanvasCommand> _redoStack = [];

  CanvasController({
    required String boardId,
    required CanvasRepository repository,
  })  : _repository = repository,
        super(CanvasState(boardId: boardId, isLoading: true)) {
    _loadBoardData();
  }

  bool get canUndo => _undoStack.isNotEmpty;
  bool get canRedo => _redoStack.isNotEmpty;

  @override
  void dispose() {
    _autosaveDebouncer.dispose();
    super.dispose();
  }

  Future<void> _loadBoardData() async {
    try {
      final objects = await _repository.getObjects(state.boardId);
      final connections = await _repository.getConnections(state.boardId);
      if (!mounted) return;

      final objectMap = {for (final obj in objects) obj.id: obj};

      state = state.copyWith(
        objects: objectMap,
        connections: connections,
        isLoading: false,
      );
    } catch (_) {
      if (!mounted) return;
      state = state.copyWith(isLoading: false);
    }
  }

  // ==========================================
  // CAMERA / VIEWPORT
  // ==========================================

  void panBy(Offset delta) {
    state = state.copyWith(camera: state.camera.panBy(delta));
  }

  void panTo(Offset pan) {
    state = state.copyWith(camera: state.camera.copyWith(pan: pan));
  }

  void centerOnObject(String objectId, Size viewportSize) {
    final obj = state.objects[objectId];
    if (obj == null || viewportSize.isEmpty) return;
    final targetCenter = obj.center;
    final targetPanX = (viewportSize.width / 2) - (targetCenter.dx * state.camera.zoom);
    final targetPanY = (viewportSize.height / 2) - (targetCenter.dy * state.camera.zoom);
    panTo(Offset(targetPanX, targetPanY));
  }

  void zoomAt(Offset screenFocalPoint, double targetZoom) {
    state = state.copyWith(camera: state.camera.zoomAt(screenFocalPoint, targetZoom));
  }

  void zoomStep({required bool zoomIn, Size? viewportSize}) {
    state = state.copyWith(
      camera: state.camera.zoomStep(zoomIn: zoomIn, viewportSize: viewportSize),
    );
  }

  void fitToViewport(Size viewportSize) {
    if (viewportSize.isEmpty) return;
    final bounds = state.worldBounds;
    if (bounds.isEmpty) {
      state = state.copyWith(
        camera: const CanvasCamera(pan: Offset.zero, zoom: AppConstants.defaultZoom),
      );
      return;
    }
    state = state.copyWith(
      camera: state.camera.fitBounds(bounds, viewportSize),
    );
  }

  void resetZoom(Size viewportSize) {
    final screenCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    state = state.copyWith(
      camera: state.camera.zoomAt(screenCenter, 1.0),
    );
  }

  // ==========================================
  // SELECTION
  // ==========================================

  void selectObject(String? id) {
    if (state.selectedObjectId == id) return;
    state = state.copyWith(
      selectedObjectId: id,
      clearSelection: id == null,
    );
  }

  void clearSelection() {
    state = state.copyWith(clearSelection: true, clearConnecting: true);
  }

  // ==========================================
  // OBJECT CREATION
  // ==========================================

  /// Calculates a default spawn position near the current camera center
  Offset _getSpawnPosition({Size? viewportSize}) {
    final size = viewportSize ?? const Size(800, 600);
    final screenCenter = Offset(size.width / 2, size.height / 2);
    final worldCenter = state.camera.screenToWorld(screenCenter);
    // Slight jitter so multiple adds don't stack directly on top of each other
    final count = state.objects.length % 5;
    return Offset(worldCenter.dx - 100 + (count * 20), worldCenter.dy - 60 + (count * 20));
  }

  Future<NoteObject> createNote({
    required String title,
    required String content,
    int colorIndex = 0,
    Offset? worldPos,
    Size? viewportSize,
  }) async {
    final rawPos = worldPos ?? _getSpawnPosition(viewportSize: viewportSize);
    final pos = _snapPosition(rawPos);
    final now = DateTime.now();

    final note = NoteObject(
      id: IdGenerator.generate(),
      boardId: state.boardId,
      title: title.trim().isEmpty ? 'New Note' : title.trim(),
      content: content.trim(),
      colorIndex: colorIndex,
      x: pos.dx,
      y: pos.dy,
      width: AppConstants.defaultNoteWidth,
      height: AppConstants.defaultNoteHeight,
      createdAt: now,
      updatedAt: now,
    );

    _recordCommand(CreateObjectCommand(note));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[note.id] = note;
    state = state.copyWith(
      objects: updatedMap,
      selectedObjectId: note.id,
    );

    _persistObject(note);
    return note;
  }

  Future<ImageObject> createImage({
    required String imageUrl,
    String? caption,
    Offset? worldPos,
    Size? viewportSize,
  }) async {
    final rawPos = worldPos ?? _getSpawnPosition(viewportSize: viewportSize);
    final pos = _snapPosition(rawPos);
    final now = DateTime.now();

    final img = ImageObject(
      id: IdGenerator.generate(),
      boardId: state.boardId,
      imageUrl: imageUrl,
      caption: caption?.trim().isEmpty == true ? null : caption?.trim(),
      x: pos.dx,
      y: pos.dy,
      width: AppConstants.defaultImageWidth,
      height: AppConstants.defaultImageHeight,
      createdAt: now,
      updatedAt: now,
    );

    _recordCommand(CreateObjectCommand(img));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[img.id] = img;
    state = state.copyWith(
      objects: updatedMap,
      selectedObjectId: img.id,
    );

    _persistObject(img);
    return img;
  }

  Future<GroupObject> createGroup({
    required String title,
    Offset? worldPos,
    Size? viewportSize,
  }) async {
    final rawPos = worldPos ?? _getSpawnPosition(viewportSize: viewportSize);
    final pos = _snapPosition(rawPos);
    final now = DateTime.now();

    final grp = GroupObject(
      id: IdGenerator.generate(),
      boardId: state.boardId,
      title: title.trim().isEmpty ? 'New Group' : title.trim(),
      x: pos.dx,
      y: pos.dy,
      width: AppConstants.defaultGroupWidth,
      height: AppConstants.defaultGroupHeight,
      createdAt: now,
      updatedAt: now,
    );

    _recordCommand(CreateObjectCommand(grp));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[grp.id] = grp;
    state = state.copyWith(
      objects: updatedMap,
      selectedObjectId: grp.id,
    );

    _persistObject(grp);
    return grp;
  }

  // ==========================================
  // OBJECT MOVEMENT & RESIZING (Immediate UI + Debounced Save)
  // ==========================================

  void toggleSnapToGrid({bool snapExisting = false}) {
    final nextState = !state.snapToGrid;
    state = state.copyWith(snapToGrid: nextState);
    if (nextState && snapExisting) {
      snapAllObjectsToGrid();
    }
  }

  /// Snaps all existing objects on the board to the grid spacing
  void snapAllObjectsToGrid() {
    const spacing = AppConstants.gridSpacing;
    final oldPositions = <String, Offset>{};
    final newPositions = <String, Offset>{};
    final updatedObjects = Map<String, BoardObject>.from(state.objects);

    for (final entry in state.objects.entries) {
      final obj = entry.value;
      final snappedX = (obj.x / spacing).round() * spacing;
      final snappedY = (obj.y / spacing).round() * spacing;

      if (snappedX != obj.x || snappedY != obj.y) {
        oldPositions[obj.id] = obj.position;
        newPositions[obj.id] = Offset(snappedX, snappedY);
        final updated = obj.copyWithPosition(x: snappedX, y: snappedY);
        updatedObjects[obj.id] = updated;
        _persistObject(updated);
      }
    }

    if (oldPositions.isNotEmpty) {
      _recordCommand(BatchMoveCommand(
        oldPositions: oldPositions,
        newPositions: newPositions,
      ));
      state = state.copyWith(objects: updatedObjects);
    }
  }

  Offset _snapPosition(Offset pos) {
    if (!state.snapToGrid) return pos;
    const spacing = AppConstants.gridSpacing;
    return Offset(
      (pos.dx / spacing).round() * spacing,
      (pos.dy / spacing).round() * spacing,
    );
  }

  Rect _snapRect(Rect rect) {
    if (!state.snapToGrid) return rect;
    const spacing = AppConstants.gridSpacing;
    final left = (rect.left / spacing).round() * spacing;
    final top = (rect.top / spacing).round() * spacing;
    final width = ((rect.width / spacing).round() * spacing).clamp(AppConstants.minNoteWidth, 2000.0);
    final height = ((rect.height / spacing).round() * spacing).clamp(AppConstants.minNoteHeight, 2000.0);
    return Rect.fromLTWH(left, top, width, height);
  }

  /// Continuous movement while pointer is dragging (immediate UI response)
  void updateObjectPosition(String id, Offset newPos) {
    final obj = state.objects[id];
    if (obj == null) return;

    final pos = _snapPosition(newPos);
    final dx = pos.dx - obj.x;
    final dy = pos.dy - obj.y;

    final updated = obj.copyWithPosition(x: pos.dx, y: pos.dy);
    final updatedMap = Map<String, BoardObject>.from(state.objects)..[id] = updated;

    // If moving a group, also translate all contained objects so they stay inside the group
    if (obj is GroupObject && (dx != 0 || dy != 0)) {
      for (final other in state.objects.values) {
        if (other is! GroupObject && AutoLayoutManager.isObjectInGroup(other, obj)) {
          final movedOther = other.copyWithPosition(x: other.x + dx, y: other.y + dy);
          updatedMap[other.id] = movedOther;
        }
      }
    }

    state = state.copyWith(objects: updatedMap);
    _debouncedSave(updated);
  }

  /// Called when pointer dragging finishes to record undo step and ensure persistence
  void commitObjectPosition(String id, Offset oldPos, Offset newPos) {
    final finalPos = _snapPosition(newPos);
    if (oldPos == finalPos) return;

    final dx = finalPos.dx - oldPos.dx;
    final dy = finalPos.dy - oldPos.dy;

    final obj = state.objects[id];
    if (obj == null) return;

    if (obj is GroupObject && (dx != 0 || dy != 0)) {
      // Find all objects that were in the group at old position
      final oldGroup = obj.copyWithPosition(x: oldPos.dx, y: oldPos.dy);
      final oldPositions = <String, Offset>{id: oldPos};
      final newPositions = <String, Offset>{id: finalPos};

      for (final other in state.objects.values) {
        if (other is! GroupObject && AutoLayoutManager.isObjectInGroup(other, oldGroup)) {
          oldPositions[other.id] = Offset(other.x - dx, other.y - dy);
          newPositions[other.id] = other.position;
          _persistObject(other);
        }
      }

      _recordCommand(BatchMoveCommand(
        oldPositions: oldPositions,
        newPositions: newPositions,
      ));
      _persistObject(obj);
      return;
    }

    _recordCommand(MoveObjectCommand(
      objectId: id,
      oldPosition: oldPos,
      newPosition: finalPos,
    ));

    final updated = obj.copyWithPosition(x: finalPos.dx, y: finalPos.dy);
    _persistObject(updated);
  }

  /// Continuous resize while handle is dragging
  void updateObjectRect(String id, Rect newRect) {
    final obj = state.objects[id];
    if (obj == null) return;

    final rect = _snapRect(newRect);
    final updated = obj
        .copyWithPosition(x: rect.left, y: rect.top)
        .copyWithSize(width: rect.width, height: rect.height);

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[id] = updated;

    state = state.copyWith(objects: updatedMap);
    _debouncedSave(updated);
  }

  /// Called when resize dragging finishes
  void commitObjectRect(String id, Rect oldRect, Rect newRect) {
    final finalRect = _snapRect(newRect);
    if (oldRect == finalRect) return;

    _recordCommand(ResizeObjectCommand(
      objectId: id,
      oldRect: oldRect,
      newRect: finalRect,
    ));

    final obj = state.objects[id];
    if (obj != null) {
      _persistObject(obj);
    }
  }

  // ==========================================
  // OBJECT EDITING & ACTIONS
  // ==========================================

  void editNote({
    required String noteId,
    required String newTitle,
    required String newContent,
    int? newColorIndex,
  }) {
    final obj = state.objects[noteId];
    if (obj is! NoteObject) return;

    final color = newColorIndex ?? obj.colorIndex;

    _recordCommand(EditNoteCommand(
      noteId: noteId,
      oldTitle: obj.title,
      oldContent: obj.content,
      oldColorIndex: obj.colorIndex,
      newTitle: newTitle,
      newContent: newContent,
      newColorIndex: color,
    ));

    final updated = obj.copyWith(
      title: newTitle,
      content: newContent,
      colorIndex: color,
      updatedAt: DateTime.now(),
    );

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[noteId] = updated;
    state = state.copyWith(objects: updatedMap);
    _persistObject(updated);
  }

  void editGroup({
    required String groupId,
    required String newTitle,
  }) {
    final obj = state.objects[groupId];
    if (obj is! GroupObject) return;

    final updated = obj.copyWith(
      title: newTitle,
      updatedAt: DateTime.now(),
    );

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[groupId] = updated;
    state = state.copyWith(objects: updatedMap);
    _persistObject(updated);
  }

  void setParentId(String childId, String? parentId) {
    final obj = state.objects[childId];
    if (obj == null) return;

    final updated = obj.copyWithParentId(parentId);
    final updatedMap = Map<String, BoardObject>.from(state.objects)..[childId] = updated;
    state = state.copyWith(objects: updatedMap);
    _persistObject(updated);
  }

  void duplicateObject(String id) {
    final obj = state.objects[id];
    if (obj == null) return;

    final now = DateTime.now();
    final newId = IdGenerator.generate();
    const offsetDelta = 30.0;
    final pos = _snapPosition(Offset(obj.x + offsetDelta, obj.y + offsetDelta));

    BoardObject copy;
    switch (obj) {
      case NoteObject note:
        copy = note.copyWith(
          id: newId,
          title: '${note.title} (Copy)',
          x: pos.dx,
          y: pos.dy,
          createdAt: now,
          updatedAt: now,
        );
        break;
      case ImageObject img:
        copy = img.copyWith(
          id: newId,
          caption: img.caption != null ? '${img.caption} (Copy)' : null,
          x: pos.dx,
          y: pos.dy,
          createdAt: now,
          updatedAt: now,
        );
        break;
      case GroupObject grp:
        copy = grp.copyWith(
          id: newId,
          title: '${grp.title} (Copy)',
          x: pos.dx,
          y: pos.dy,
          createdAt: now,
          updatedAt: now,
        );
        break;
    }

    _recordCommand(CreateObjectCommand(copy));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[copy.id] = copy;
    state = state.copyWith(
      objects: updatedMap,
      selectedObjectId: copy.id,
    );

    _persistObject(copy);
  }

  void deleteObject(String id) {
    final obj = state.objects[id];
    if (obj == null) return;

    final attachedConnections =
        ConnectionManager.findAttachedConnections(id, state.connections);

    _recordCommand(DeleteObjectCommand(
      object: obj,
      attachedConnections: attachedConnections,
    ));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..remove(id);
    final updatedConnections = state.connections
        .where((c) => c.fromObjectId != id && c.toObjectId != id)
        .toList();

    state = state.copyWith(
      objects: updatedMap,
      connections: updatedConnections,
      clearSelection: state.selectedObjectId == id,
    );

    _repository.deleteObject(id, obj.type);
  }

  // ==========================================
  // CONNECTIONS
  // ==========================================

  void startConnecting(String fromObjectId) {
    state = state.copyWith(connectingFromObjectId: fromObjectId);
  }

  void cancelConnecting() {
    state = state.copyWith(clearConnecting: true);
  }

  void completeConnecting(String toObjectId) {
    final fromId = state.connectingFromObjectId;
    if (fromId == null) return;

    if (!ConnectionManager.canConnect(
      fromId: fromId,
      toId: toObjectId,
      existingConnections: state.connections,
    )) {
      state = state.copyWith(clearConnecting: true);
      return;
    }

    final connection = BoardConnection(
      id: IdGenerator.generate(),
      boardId: state.boardId,
      fromObjectId: fromId,
      toObjectId: toObjectId,
      type: 'arrow',
      createdAt: DateTime.now(),
    );

    _recordCommand(CreateConnectionCommand(connection));

    final updatedConnections = [...state.connections, connection];
    state = state.copyWith(
      connections: updatedConnections,
      clearConnecting: true,
    );

    _repository.saveConnection(connection);
  }

  void deleteConnection(String id) {
    final conn = state.connections.firstWhere(
      (c) => c.id == id,
      orElse: () => throw Exception('Connection not found'),
    );

    _recordCommand(DeleteConnectionCommand(conn));

    final updated = state.connections.where((c) => c.id != id).toList();
    state = state.copyWith(connections: updated);

    _repository.deleteConnection(id);
  }

  void editConnection({
    required String connectionId,
    String? label,
    String? type,
  }) {
    final index = state.connections.indexWhere((c) => c.id == connectionId);
    if (index == -1) return;

    final existing = state.connections[index];
    final updatedLabel = label;
    final updatedType = type ?? existing.type;

    _recordCommand(EditConnectionCommand(
      connectionId: connectionId,
      oldLabel: existing.label,
      oldType: existing.type,
      newLabel: updatedLabel,
      newType: updatedType,
    ));

    final updatedConn = existing.copyWith(
      label: updatedLabel,
      clearLabel: updatedLabel == null,
      type: updatedType,
    );

    final updatedList = List<BoardConnection>.from(state.connections)..[index] = updatedConn;
    state = state.copyWith(connections: updatedList);
    _repository.saveConnection(updatedConn);
  }

  void branchChildNote({
    required String parentNoteId,
    String? title,
    String? content,
    int? colorIndex,
  }) {
    final parent = state.objects[parentNoteId];
    if (parent == null) return;

    // Find all direct children or outgoing connection targets from parent
    final childIds = <String>{};
    for (final conn in state.connections) {
      if (conn.fromObjectId == parentNoteId) {
        childIds.add(conn.toObjectId);
      }
    }
    for (final obj in state.objects.values) {
      if (obj.parentId == parentNoteId) {
        childIds.add(obj.id);
      }
    }

    final childObjects = childIds
        .map((id) => state.objects[id])
        .whereType<BoardObject>()
        .toList();

    double childX = parent.x + parent.width + 60.0;
    double childY = parent.y;

    if (childObjects.isNotEmpty) {
      double maxY = double.negativeInfinity;
      for (final c in childObjects) {
        if (c.y + c.height > maxY) {
          maxY = c.y + c.height;
        }
      }
      childY = maxY + 20.0;
    }

    final snapped = _snapPosition(Offset(childX, childY));
    childX = snapped.dx;
    childY = snapped.dy;

    final childId = IdGenerator.generate();
    final now = DateTime.now();

    final childNote = NoteObject(
      id: childId,
      boardId: state.boardId,
      x: childX,
      y: childY,
      width: 180,
      height: 110,
      createdAt: now,
      updatedAt: now,
      parentId: parentNoteId,
      title: title ?? 'Sub-topic',
      content: content ?? '',
      colorIndex: colorIndex ?? (parent is NoteObject ? parent.colorIndex : 0),
    );

    final connId = IdGenerator.generate();
    final connection = BoardConnection(
      id: connId,
      boardId: state.boardId,
      fromObjectId: parentNoteId,
      toObjectId: childId,
      type: 'arrow',
      createdAt: now,
    );

    _recordCommand(BranchNoteCommand(
      childNote: childNote,
      connection: connection,
    ));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[childId] = childNote;
    final updatedConns = [...state.connections, connection];

    state = state.copyWith(
      objects: updatedMap,
      connections: updatedConns,
      selectedObjectId: childId,
    );

    _persistObject(childNote);
    _repository.saveConnection(connection);
  }

  void branchSiblingNote({
    required String sourceNoteId,
    String? title,
    String? content,
    int? colorIndex,
  }) {
    final source = state.objects[sourceNoteId];
    if (source == null) return;

    final targetParentId = source.parentId ?? sourceNoteId;

    double childX;
    double childY;
    if (source.parentId != null) {
      childX = source.x;
      childY = source.y + source.height + 24.0;
    } else {
      childX = source.x;
      childY = source.y + source.height + 48.0;
    }

    final snapped = _snapPosition(Offset(childX, childY));
    childX = snapped.dx;
    childY = snapped.dy;

    final childId = IdGenerator.generate();
    final now = DateTime.now();

    final childNote = NoteObject(
      id: childId,
      boardId: state.boardId,
      x: childX,
      y: childY,
      width: 180,
      height: 110,
      createdAt: now,
      updatedAt: now,
      parentId: targetParentId,
      title: title ?? 'Sub-topic',
      content: content ?? '',
      colorIndex: colorIndex ?? (source is NoteObject ? source.colorIndex : 0),
    );

    final connId = IdGenerator.generate();
    final connection = BoardConnection(
      id: connId,
      boardId: state.boardId,
      fromObjectId: targetParentId,
      toObjectId: childId,
      type: 'arrow',
      createdAt: now,
    );

    _recordCommand(BranchNoteCommand(
      childNote: childNote,
      connection: connection,
    ));

    final updatedMap = Map<String, BoardObject>.from(state.objects)..[childId] = childNote;
    final updatedConns = [...state.connections, connection];

    state = state.copyWith(
      objects: updatedMap,
      connections: updatedConns,
      selectedObjectId: childId,
    );

    _persistObject(childNote);
    _repository.saveConnection(connection);
  }

  void toggleNoteChecklistItem({
    required String noteId,
    required int lineIndex,
  }) {
    final obj = state.objects[noteId];
    if (obj is! NoteObject) return;

    final lines = obj.content.split('\n');
    if (lineIndex < 0 || lineIndex >= lines.length) return;

    final line = lines[lineIndex];
    String updatedLine;
    if (line.trim().startsWith('- [ ] ')) {
      updatedLine = line.replaceFirst('- [ ] ', '- [x] ');
    } else if (line.trim().startsWith('- [x] ') || line.trim().startsWith('- [X] ')) {
      updatedLine = line.replaceFirst(RegExp(r'- \[[xX]\] '), '- [ ] ');
    } else if (line.trim().startsWith('[ ] ')) {
      updatedLine = line.replaceFirst('[ ] ', '[x] ');
    } else if (line.trim().startsWith('[x] ') || line.trim().startsWith('[X] ')) {
      updatedLine = line.replaceFirst(RegExp(r'\[[xX]\] '), '[ ] ');
    } else {
      return;
    }

    lines[lineIndex] = updatedLine;
    final newContent = lines.join('\n');
    editNote(
      noteId: noteId,
      newTitle: obj.title,
      newContent: newContent,
      newColorIndex: obj.colorIndex,
    );
  }

  void autoArrangeMap() {
    if (state.objects.isEmpty) return;

    // 1. If a group is selected or a note inside a group is selected, arrange ONLY that group!
    GroupObject? groupToArrange;
    if (state.selectedObject is GroupObject) {
      groupToArrange = state.selectedObject as GroupObject;
    } else if (state.selectedObject != null) {
      groupToArrange = AutoLayoutManager.findGroupForObject(state.selectedObject!, state.groups);
    }

    if (groupToArrange != null) {
      autoArrangeGrid(targetGroupId: groupToArrange.id);
      return;
    }

    // 2. If a selective note (or connected subtree) is selected, arrange only that connected cluster!
    if (state.selectedObject != null) {
      final selectedId = state.selectedObjectId!;
      final clusterIds = _findConnectedCluster(selectedId);
      if (clusterIds.length > 1) {
        final clusterObjects = {
          for (final id in clusterIds)
            if (state.objects.containsKey(id)) id: state.objects[id]!
        };
        final clusterConnections = state.connections
            .where((c) => clusterIds.contains(c.fromObjectId) && clusterIds.contains(c.toObjectId))
            .toList();

        final minX = clusterObjects.values.map((o) => o.x).reduce(math.min);
        final minY = clusterObjects.values.map((o) => o.y).reduce(math.min);

        final newPositions = AutoLayoutManager.computeLayout(
          objects: clusterObjects,
          connections: clusterConnections,
          horizontalSpacing: 120.0,
          verticalSpacing: 50.0,
          startX: minX,
          startY: minY,
        );
        _applyLayoutPositions(newPositions);
      }
      return;
    }

    // 3. Overall Canvas Auto-Arrange:
    _autoArrangeAllPreservingGroups(layoutType: 'horizontal');
  }

  void autoArrangeVerticalTree() {
    if (state.objects.isEmpty) return;

    GroupObject? groupToArrange;
    if (state.selectedObject is GroupObject) {
      groupToArrange = state.selectedObject as GroupObject;
    } else if (state.selectedObject != null) {
      groupToArrange = AutoLayoutManager.findGroupForObject(state.selectedObject!, state.groups);
    }

    if (groupToArrange != null) {
      autoArrangeGrid(targetGroupId: groupToArrange.id);
      return;
    }

    if (state.selectedObject != null) {
      final selectedId = state.selectedObjectId!;
      final clusterIds = _findConnectedCluster(selectedId);
      if (clusterIds.length > 1) {
        final clusterObjects = {
          for (final id in clusterIds)
            if (state.objects.containsKey(id)) id: state.objects[id]!
        };
        final clusterConnections = state.connections
            .where((c) => clusterIds.contains(c.fromObjectId) && clusterIds.contains(c.toObjectId))
            .toList();

        final minX = clusterObjects.values.map((o) => o.x).reduce(math.min);
        final minY = clusterObjects.values.map((o) => o.y).reduce(math.min);

        final newPositions = AutoLayoutManager.computeVerticalLayout(
          objects: clusterObjects,
          connections: clusterConnections,
          horizontalSpacing: 70.0,
          verticalSpacing: 100.0,
          startX: minX,
          startY: minY,
        );
        _applyLayoutPositions(newPositions);
      }
      return;
    }

    _autoArrangeAllPreservingGroups(layoutType: 'vertical');
  }

  void autoArrangeGrid({String? targetGroupId}) {
    if (state.objects.isEmpty) return;

    // Check if target group or currently selected object is a GroupObject,
    // OR if currently selected object is a note inside a group!
    GroupObject? groupToArrange;
    if (targetGroupId != null) {
      final obj = state.objects[targetGroupId];
      if (obj is GroupObject) groupToArrange = obj;
    } else if (state.selectedObject is GroupObject) {
      groupToArrange = state.selectedObject as GroupObject;
    } else if (state.selectedObject != null) {
      groupToArrange = AutoLayoutManager.findGroupForObject(state.selectedObject!, state.groups);
    }

    if (groupToArrange != null) {
      // 1. Target selected group: arrange ONLY objects inside this group!
      final contained = state.objects.values
          .where((o) => o is! GroupObject && AutoLayoutManager.isObjectInGroup(o, groupToArrange!))
          .toList();

      if (contained.isNotEmpty) {
        final result = AutoLayoutManager.computeGroupLayout(
          group: groupToArrange,
          containedObjects: contained,
          spacingX: 110.0,
          spacingY: 88.0,
          padding: 32.0,
          headerHeight: 48.0,
        );

        _applyLayoutPositions(result.positions);

        if (result.updatedGroup.width != groupToArrange.width ||
            result.updatedGroup.height != groupToArrange.height) {
          _resizeGroupDirectly(
            groupToArrange.id,
            result.updatedGroup.width,
            result.updatedGroup.height,
          );
        }
      }
      return;
    }

    // 2. If a selective note (or connected subtree) is selected, arrange only that connected cluster!
    if (state.selectedObject != null) {
      final selectedId = state.selectedObjectId!;
      final clusterIds = _findConnectedCluster(selectedId);
      if (clusterIds.length > 1) {
        final clusterObjects = {
          for (final id in clusterIds)
            if (state.objects.containsKey(id)) id: state.objects[id]!
        };
        final cols = math.max(1, math.sqrt(clusterObjects.length).ceil());
        final minX = clusterObjects.values.map((o) => o.x).reduce(math.min);
        final minY = clusterObjects.values.map((o) => o.y).reduce(math.min);
        final clusterPositions = AutoLayoutManager.computeGridLayout(
          objects: clusterObjects,
          columns: cols,
          spacingX: 110.0,
          spacingY: 88.0,
          startX: minX,
          startY: minY,
        );
        _applyLayoutPositions(clusterPositions);
      }
      return;
    }

    // 3. No specific group selected: arrange all objects cleanly while keeping group contents inside groups!
    _autoArrangeAllPreservingGroups(layoutType: 'grid');
  }

  Set<String> _findConnectedCluster(String rootId) {
    final clusterIds = <String>{rootId};
    final queue = <String>[rootId];
    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      for (final conn in state.connections) {
        if (conn.fromObjectId == curr && !clusterIds.contains(conn.toObjectId)) {
          clusterIds.add(conn.toObjectId);
          queue.add(conn.toObjectId);
        } else if (conn.toObjectId == curr && !clusterIds.contains(conn.fromObjectId)) {
          clusterIds.add(conn.fromObjectId);
          queue.add(conn.fromObjectId);
        }
      }
      for (final obj in state.objects.values) {
        if (obj.parentId == curr && !clusterIds.contains(obj.id)) {
          clusterIds.add(obj.id);
          queue.add(obj.id);
        }
      }
    }
    return clusterIds;
  }

  void _autoArrangeAllPreservingGroups({required String layoutType}) {
    final groups = state.groups;
    final allNewPositions = <String, Offset>{};
    final groupedObjectIds = <String>{};
    final updatedGroups = <String, GroupObject>{};

    for (final grp in groups) {
      final contained = state.objects.values
          .where((o) => o is! GroupObject && AutoLayoutManager.isObjectInGroup(o, grp))
          .toList();

      if (contained.isNotEmpty) {
        for (final c in contained) {
          groupedObjectIds.add(c.id);
        }
        final grpResult = AutoLayoutManager.computeGroupLayout(
          group: grp,
          containedObjects: contained,
          spacingX: 110.0,
          spacingY: 88.0,
          padding: 32.0,
          headerHeight: 48.0,
        );
        allNewPositions.addAll(grpResult.positions);
        updatedGroups[grp.id] = grpResult.updatedGroup;

        if (grpResult.updatedGroup.width != grp.width ||
            grpResult.updatedGroup.height != grp.height) {
          _resizeGroupDirectly(
            grp.id,
            grpResult.updatedGroup.width,
            grpResult.updatedGroup.height,
          );
        }
      }
    }

    // Top-level objects (groups and ungrouped notes/images)
    final topLevelObjects = <String, BoardObject>{};
    for (final obj in state.objects.values) {
      if (!groupedObjectIds.contains(obj.id)) {
        topLevelObjects[obj.id] = updatedGroups[obj.id] ?? obj;
      }
    }

    final topLevelConnections = state.connections.where((c) {
      return topLevelObjects.containsKey(c.fromObjectId) &&
          topLevelObjects.containsKey(c.toObjectId);
    }).toList();

    Map<String, Offset> topLevelPositions;
    if (layoutType == 'horizontal') {
      topLevelPositions = AutoLayoutManager.computeLayout(
        objects: topLevelObjects,
        connections: topLevelConnections,
        horizontalSpacing: 120.0,
        verticalSpacing: 60.0,
      );
    } else if (layoutType == 'vertical') {
      topLevelPositions = AutoLayoutManager.computeVerticalLayout(
        objects: topLevelObjects,
        connections: topLevelConnections,
        horizontalSpacing: 80.0,
        verticalSpacing: 110.0,
      );
    } else {
      topLevelPositions = AutoLayoutManager.computeGridLayout(
        objects: topLevelObjects,
        columns: 3,
        spacingX: 110.0,
        spacingY: 88.0,
      );
    }

    // If top-level groups were shifted, shift their internal notes by the same delta
    for (final grp in groups) {
      final newGrpPos = topLevelPositions[grp.id];
      if (newGrpPos != null) {
        final dx = newGrpPos.dx - grp.x;
        final dy = newGrpPos.dy - grp.y;

        final contained = state.objects.values
            .where((o) => o is! GroupObject && AutoLayoutManager.findGroupForObject(o, groups)?.id == grp.id)
            .toList();

        for (final c in contained) {
          final curPos = allNewPositions[c.id] ?? c.position;
          allNewPositions[c.id] = Offset(curPos.dx + dx, curPos.dy + dy);
        }
      }
    }

    allNewPositions.addAll(topLevelPositions);
    _applyLayoutPositions(allNewPositions);
  }

  void _resizeGroupDirectly(String id, double width, double height) {
    final obj = state.objects[id];
    if (obj == null) return;
    final oldRect = obj.rect;
    final updated = obj.copyWithSize(width: width, height: height);
    final updatedMap = Map<String, BoardObject>.from(state.objects)..[id] = updated;
    state = state.copyWith(objects: updatedMap);
    _recordCommand(ResizeObjectCommand(objectId: id, oldRect: oldRect, newRect: updated.rect));
    _persistObject(updated);
  }

  void _applyLayoutPositions(Map<String, Offset> newPositions) {
    if (newPositions.isEmpty) return;

    final oldPositions = <String, Offset>{};
    final updatedMap = Map<String, BoardObject>.from(state.objects);

    for (final entry in newPositions.entries) {
      final obj = updatedMap[entry.key];
      if (obj != null) {
        oldPositions[entry.key] = obj.position;
        final moved = obj.copyWithPosition(x: entry.value.dx, y: entry.value.dy);
        updatedMap[entry.key] = moved;
        _persistObject(moved);
      }
    }

    _recordCommand(BatchMoveCommand(
      oldPositions: oldPositions,
      newPositions: newPositions,
    ));

    state = state.copyWith(objects: updatedMap);
  }

  // ==========================================
  // UNDO / REDO
  // ==========================================

  void _recordCommand(CanvasCommand command) {
    _undoStack.add(command);
    _redoStack.clear();
  }

  void undo() {
    if (_undoStack.isEmpty) return;

    final command = _undoStack.removeLast();
    _redoStack.add(command);

    switch (command) {
      case CreateObjectCommand cmd:
        // Undo create = delete object
        final updatedMap = Map<String, BoardObject>.from(state.objects)
          ..remove(cmd.object.id);
        state = state.copyWith(
          objects: updatedMap,
          clearSelection: state.selectedObjectId == cmd.object.id,
        );
        _repository.deleteObject(cmd.object.id, cmd.object.type);
        break;

      case DeleteObjectCommand cmd:
        // Undo delete = restore object and connections
        final updatedMap = Map<String, BoardObject>.from(state.objects)
          ..[cmd.object.id] = cmd.object;
        final updatedConnections = [...state.connections, ...cmd.attachedConnections];
        state = state.copyWith(
          objects: updatedMap,
          connections: updatedConnections,
          selectedObjectId: cmd.object.id,
        );
        _persistObject(cmd.object);
        for (final conn in cmd.attachedConnections) {
          _repository.saveConnection(conn);
        }
        break;

      case MoveObjectCommand cmd:
        final obj = state.objects[cmd.objectId];
        if (obj != null) {
          final reverted =
              obj.copyWithPosition(x: cmd.oldPosition.dx, y: cmd.oldPosition.dy);
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.objectId] = reverted;
          state = state.copyWith(objects: updatedMap);
          _persistObject(reverted);
        }
        break;

      case ResizeObjectCommand cmd:
        final obj = state.objects[cmd.objectId];
        if (obj != null) {
          final reverted = obj
              .copyWithPosition(x: cmd.oldRect.left, y: cmd.oldRect.top)
              .copyWithSize(width: cmd.oldRect.width, height: cmd.oldRect.height);
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.objectId] = reverted;
          state = state.copyWith(objects: updatedMap);
          _persistObject(reverted);
        }
        break;

      case EditNoteCommand cmd:
        final obj = state.objects[cmd.noteId];
        if (obj is NoteObject) {
          final reverted = obj.copyWith(
            title: cmd.oldTitle,
            content: cmd.oldContent,
            colorIndex: cmd.oldColorIndex,
          );
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.noteId] = reverted;
          state = state.copyWith(objects: updatedMap);
          _persistObject(reverted);
        }
        break;

      case CreateConnectionCommand cmd:
        final updated = state.connections.where((c) => c.id != cmd.connection.id).toList();
        state = state.copyWith(connections: updated);
        _repository.deleteConnection(cmd.connection.id);
        break;

      case DeleteConnectionCommand cmd:
        final updated = [...state.connections, cmd.connection];
        state = state.copyWith(connections: updated);
        _repository.saveConnection(cmd.connection);
        break;

      case EditConnectionCommand cmd:
        final index = state.connections.indexWhere((c) => c.id == cmd.connectionId);
        if (index != -1) {
          final reverted = state.connections[index].copyWith(
            label: cmd.oldLabel,
            clearLabel: cmd.oldLabel == null,
            type: cmd.oldType,
          );
          final updated = List<BoardConnection>.from(state.connections)..[index] = reverted;
          state = state.copyWith(connections: updated);
          _repository.saveConnection(reverted);
        }
        break;

      case BatchMoveCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects);
        for (final entry in cmd.oldPositions.entries) {
          final obj = updatedMap[entry.key];
          if (obj != null) {
            final reverted = obj.copyWithPosition(x: entry.value.dx, y: entry.value.dy);
            updatedMap[entry.key] = reverted;
            _persistObject(reverted);
          }
        }
        state = state.copyWith(objects: updatedMap);
        break;

      case BranchNoteCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects)..remove(cmd.childNote.id);
        final updatedConnections = state.connections.where((c) => c.id != cmd.connection.id).toList();
        state = state.copyWith(
          objects: updatedMap,
          connections: updatedConnections,
          clearSelection: state.selectedObjectId == cmd.childNote.id,
        );
        _repository.deleteObject(cmd.childNote.id, cmd.childNote.type);
        _repository.deleteConnection(cmd.connection.id);
        break;
    }
  }

  void redo() {
    if (_redoStack.isEmpty) return;

    final command = _redoStack.removeLast();
    _undoStack.add(command);

    switch (command) {
      case CreateObjectCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects)
          ..[cmd.object.id] = cmd.object;
        state = state.copyWith(
          objects: updatedMap,
          selectedObjectId: cmd.object.id,
        );
        _persistObject(cmd.object);
        break;

      case DeleteObjectCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects)
          ..remove(cmd.object.id);
        final updatedConnections = state.connections
            .where((c) =>
                c.fromObjectId != cmd.object.id && c.toObjectId != cmd.object.id)
            .toList();
        state = state.copyWith(
          objects: updatedMap,
          connections: updatedConnections,
          clearSelection: state.selectedObjectId == cmd.object.id,
        );
        _repository.deleteObject(cmd.object.id, cmd.object.type);
        break;

      case MoveObjectCommand cmd:
        final obj = state.objects[cmd.objectId];
        if (obj != null) {
          final moved =
              obj.copyWithPosition(x: cmd.newPosition.dx, y: cmd.newPosition.dy);
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.objectId] = moved;
          state = state.copyWith(objects: updatedMap);
          _persistObject(moved);
        }
        break;

      case ResizeObjectCommand cmd:
        final obj = state.objects[cmd.objectId];
        if (obj != null) {
          final resized = obj
              .copyWithPosition(x: cmd.newRect.left, y: cmd.newRect.top)
              .copyWithSize(width: cmd.newRect.width, height: cmd.newRect.height);
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.objectId] = resized;
          state = state.copyWith(objects: updatedMap);
          _persistObject(resized);
        }
        break;

      case EditNoteCommand cmd:
        final obj = state.objects[cmd.noteId];
        if (obj is NoteObject) {
          final edited = obj.copyWith(
            title: cmd.newTitle,
            content: cmd.newContent,
            colorIndex: cmd.newColorIndex,
          );
          final updatedMap = Map<String, BoardObject>.from(state.objects)
            ..[cmd.noteId] = edited;
          state = state.copyWith(objects: updatedMap);
          _persistObject(edited);
        }
        break;

      case CreateConnectionCommand cmd:
        final updated = [...state.connections, cmd.connection];
        state = state.copyWith(connections: updated);
        _repository.saveConnection(cmd.connection);
        break;

      case DeleteConnectionCommand cmd:
        final updated = state.connections.where((c) => c.id != cmd.connection.id).toList();
        state = state.copyWith(connections: updated);
        _repository.deleteConnection(cmd.connection.id);
        break;

      case EditConnectionCommand cmd:
        final index = state.connections.indexWhere((c) => c.id == cmd.connectionId);
        if (index != -1) {
          final edited = state.connections[index].copyWith(
            label: cmd.newLabel,
            clearLabel: cmd.newLabel == null,
            type: cmd.newType,
          );
          final updated = List<BoardConnection>.from(state.connections)..[index] = edited;
          state = state.copyWith(connections: updated);
          _repository.saveConnection(edited);
        }
        break;

      case BatchMoveCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects);
        for (final entry in cmd.newPositions.entries) {
          final obj = updatedMap[entry.key];
          if (obj != null) {
            final moved = obj.copyWithPosition(x: entry.value.dx, y: entry.value.dy);
            updatedMap[entry.key] = moved;
            _persistObject(moved);
          }
        }
        state = state.copyWith(objects: updatedMap);
        break;

      case BranchNoteCommand cmd:
        final updatedMap = Map<String, BoardObject>.from(state.objects)..[cmd.childNote.id] = cmd.childNote;
        final updatedConnections = [...state.connections, cmd.connection];
        state = state.copyWith(
          objects: updatedMap,
          connections: updatedConnections,
          selectedObjectId: cmd.childNote.id,
        );
        _persistObject(cmd.childNote);
        _repository.saveConnection(cmd.connection);
        break;
    }
  }

  // ==========================================
  // PERSISTENCE HELPERS
  // ==========================================

  void _debouncedSave(BoardObject object) {
    _autosaveDebouncer.run(() {
      _repository.saveObject(object);
    });
  }

  void _persistObject(BoardObject object) {
    _repository.saveObject(object);
  }
}

/// Provider for CanvasController parameterized by boardId
final canvasControllerProvider =
    StateNotifierProvider.family<CanvasController, CanvasState, String>((ref, boardId) {
  final repository = ref.watch(canvasRepositoryProvider);
  return CanvasController(boardId: boardId, repository: repository);
});
