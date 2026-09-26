import 'dart:async';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../../boards/data/board_repository.dart';
import '../../boards/presentation/export_import_dialogs.dart';
import '../../images/presentation/image_card.dart';
import '../../images/presentation/image_picker_dialog.dart';
import '../../notes/presentation/note_card.dart';
import '../../notes/presentation/note_editor_dialog.dart';
import '../domain/board_object.dart';
import '../domain/canvas_state.dart';
import '../engine/canvas_controller.dart';
import '../engine/gesture_manager.dart';
import '../engine/selection_manager.dart';
import 'canvas_toolbar.dart';
import 'selection_overlay.dart';
import 'widgets/add_menu_widget.dart';
import 'widgets/canvas_background_painter.dart';
import 'widgets/canvas_search_dialog.dart';
import 'widgets/connections_painter.dart';
import '../domain/board_connection.dart';
import '../engine/coordinate_transform.dart';
import 'widgets/connection_editor_dialog.dart';
import 'widgets/group_card.dart';
import 'widgets/group_dialog.dart';
import 'widgets/object_action_sheet.dart';
import 'widgets/parent_hierarchy_dialog.dart';

class BoardCanvas extends ConsumerStatefulWidget {
  final String boardId;
  final String boardName;

  const BoardCanvas({
    super.key,
    required this.boardId,
    required this.boardName,
  });

  @override
  ConsumerState<BoardCanvas> createState() => _BoardCanvasState();
}

class _BoardCanvasState extends ConsumerState<BoardCanvas> {
  final FocusNode _keyboardFocusNode = FocusNode();

  // Gesture state
  CanvasGestureMode _gestureMode = CanvasGestureMode.none;
  String? _draggingObjectId;
  Offset _dragInitialWorldPos = Offset.zero;
  Offset _dragCurrentWorldPos = Offset.zero;

  // Resize state
  ResizeHandle? _activeResizeHandle;
  Rect _resizeInitialRect = Rect.zero;
  Offset _resizeAccumulatedWorldDelta = Offset.zero;

  // Track if interaction started on selection overlay or action bar
  bool _pointerOnOverlay = false;

  // Pointer position for live connection preview
  Offset? _currentPointerScreenPos;

  // Track two-finger pinch zoom
  double _pinchInitialZoom = 1.0;

  // Desktop Add Menu toggle
  bool _showDesktopAddMenu = false;

  @override
  void initState() {
    super.initState();
    // Request keyboard focus for desktop shortcuts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _keyboardFocusNode.requestFocus();
      // Auto-fit to existing objects after short load delay
      _tryInitialFit();
    });
  }

  Timer? _initFitTimer;

  void _tryInitialFit() {
    _initFitTimer?.cancel();
    _initFitTimer = Timer(const Duration(milliseconds: 300), () {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
      controller.fitToViewport(size);
    });
  }

  @override
  void dispose() {
    _initFitTimer?.cancel();
    _keyboardFocusNode.dispose();
    super.dispose();
  }

  // ==========================================
  // KEYBOARD SHORTCUTS (Section 36)
  // ==========================================

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent) return KeyEventResult.ignored;

    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final state = ref.read(canvasControllerProvider(widget.boardId));

    final isControlOrCmd = HardwareKeyboard.instance.isControlPressed ||
        HardwareKeyboard.instance.isMetaPressed;
    final isShift = HardwareKeyboard.instance.isShiftPressed;

    // Delete / Backspace: Delete selected object
    if (event.logicalKey == LogicalKeyboardKey.delete ||
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (state.selectedObjectId != null) {
        controller.deleteObject(state.selectedObjectId!);
        return KeyEventResult.handled;
      }
    }

    // Escape: Clear selection / cancel connection
    if (event.logicalKey == LogicalKeyboardKey.escape) {
      controller.clearSelection();
      return KeyEventResult.handled;
    }

    // Ctrl+Z: Undo
    if (isControlOrCmd && !isShift && event.logicalKey == LogicalKeyboardKey.keyZ) {
      if (controller.canUndo) {
        controller.undo();
        return KeyEventResult.handled;
      }
    }

    // Ctrl+Shift+Z or Ctrl+Y: Redo
    if ((isControlOrCmd && isShift && event.logicalKey == LogicalKeyboardKey.keyZ) ||
        (isControlOrCmd && event.logicalKey == LogicalKeyboardKey.keyY)) {
      if (controller.canRedo) {
        controller.redo();
        return KeyEventResult.handled;
      }
    }

    // Ctrl+G: Toggle snap to grid
    if (isControlOrCmd && event.logicalKey == LogicalKeyboardKey.keyG) {
      controller.toggleSnapToGrid();
      _showSnapFeedback(!state.snapToGrid);
      return KeyEventResult.handled;
    }

    // Ctrl+D: Duplicate selected object
    if (isControlOrCmd && event.logicalKey == LogicalKeyboardKey.keyD) {
      if (state.selectedObjectId != null) {
        controller.duplicateObject(state.selectedObjectId!);
        return KeyEventResult.handled;
      }
    }

    // Ctrl+F: Open Canvas Search
    if (isControlOrCmd && event.logicalKey == LogicalKeyboardKey.keyF) {
      _openCanvasSearch();
      return KeyEventResult.handled;
    }

    // Tab: Branch child note to right
    if (!isControlOrCmd && !isShift && event.logicalKey == LogicalKeyboardKey.tab) {
      if (state.selectedObjectId != null && state.selectedObject is NoteObject) {
        controller.branchChildNote(parentNoteId: state.selectedObjectId!);
        return KeyEventResult.handled;
      }
    }

    // Enter: Branch sibling note downwards
    if (!isControlOrCmd && !isShift && event.logicalKey == LogicalKeyboardKey.enter) {
      if (state.selectedObjectId != null && state.selectedObject is NoteObject) {
        controller.branchSiblingNote(sourceNoteId: state.selectedObjectId!);
        return KeyEventResult.handled;
      }
    }

    return KeyEventResult.ignored;
  }

  // ==========================================
  // POINTER & MOUSE SCROLL ZOOM / PAN
  // ==========================================

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is PointerScrollEvent) {
      final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
      final state = ref.read(canvasControllerProvider(widget.boardId));

      final isShift = HardwareKeyboard.instance.isShiftPressed;

      // 1. Shift+Scroll: Pan horizontally!
      if (isShift) {
        final deltaX = event.scrollDelta.dy != 0 ? -event.scrollDelta.dy : -event.scrollDelta.dx;
        controller.panBy(Offset(deltaX, 0));
        return;
      }

      // 2. Trackpad two-finger horizontal swipe without Shift
      if (event.scrollDelta.dx != 0 && event.scrollDelta.dy == 0) {
        controller.panBy(Offset(-event.scrollDelta.dx, 0));
        return;
      }

      // 3. Normal wheel scroll zooms at pointer position
      final scrollDelta = event.scrollDelta.dy;
      final zoomFactor = scrollDelta > 0 ? 0.90 : 1.10;
      final targetZoom = state.camera.zoom * zoomFactor;

      controller.zoomAt(event.localPosition, targetZoom);
    }
  }

  // ==========================================
  // SCALE / PAN GESTURES
  // ==========================================

  void _onScaleStart(ScaleStartDetails details) {
    // If pointer interacted with the selection overlay or its action bar,
    // do not clear selection or initiate canvas panning/dragging.
    if (_pointerOnOverlay) {
      _pointerOnOverlay = false;
      return;
    }

    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    // Secondary check: if an object is selected, check if click was on its action bar or handles
    if (state.selectedObject != null) {
      final screenRect = state.camera.worldToScreenRect(state.selectedObject!.rect);
      const barHeight = 40.0;
      final isBarAbove = (screenRect.top - barHeight - 8) >= 8;
      final barTop = isBarAbove ? screenRect.top - barHeight - 8 : screenRect.bottom + 8;

      // Protect action bar and the bridge area connecting it to the card
      final barRect = isBarAbove
          ? Rect.fromLTRB(
              screenRect.center.dx - 130,
              barTop - 6,
              screenRect.center.dx + 130,
              screenRect.top + 6,
            )
          : Rect.fromLTRB(
              screenRect.center.dx - 130,
              screenRect.bottom - 6,
              screenRect.center.dx + 130,
              barTop + barHeight + 6,
            );

      if (barRect.contains(details.localFocalPoint)) {
        return;
      }

      // Protect branch buttons (right edge and bottom edge)
      if (state.selectedObject is NoteObject) {
        final branchChildCenter = Offset(screenRect.right + 30, screenRect.center.dy);
        final branchSiblingCenter = Offset(screenRect.center.dx, screenRect.bottom + 30);
        if ((details.localFocalPoint - branchChildCenter).distance <= 45.0 ||
            (details.localFocalPoint - branchSiblingCenter).distance <= 45.0) {
          return;
        }
      }

      // Protect corner resize handles (hit radius 20px)
      const handleHitRadius = 20.0;
      final corners = [
        screenRect.topLeft,
        screenRect.topRight,
        screenRect.bottomLeft,
        screenRect.bottomRight,
      ];
      for (final corner in corners) {
        if ((details.localFocalPoint - corner).distance <= handleHitRadius) {
          return;
        }
      }
    }

    if (details.pointerCount >= 2) {
      // Pinch to zoom
      _gestureMode = CanvasGestureMode.panning;
      _pinchInitialZoom = state.camera.zoom;
      return;
    }

    // 1 pointer touch/click: Hit test to see if an object was clicked
    final worldPoint = state.camera.screenToWorld(details.localFocalPoint);
    final hitObject = SelectionManager.findObjectAt(worldPoint, state.objects.values);

    if (state.isConnecting) {
      // We are in connecting mode
      if (hitObject != null) {
        controller.completeConnecting(hitObject.id);
      } else {
        controller.cancelConnecting();
      }
      return;
    }

    if (hitObject != null) {
      // Hit an object
      controller.selectObject(hitObject.id);
      _gestureMode = CanvasGestureMode.movingObject;
      _draggingObjectId = hitObject.id;
      _dragInitialWorldPos = hitObject.position;
      _dragCurrentWorldPos = hitObject.position;
    } else {
      // Check if clicked on a connection line or label
      for (final conn in state.connections) {
        final fromObj = state.objects[conn.fromObjectId];
        final toObj = state.objects[conn.toObjectId];
        if (fromObj == null || toObj == null) continue;

        final p1 = state.camera.worldToScreen(CoordinateTransform.getEdgeAnchor(fromObj.rect, toObj.center));
        final p2 = state.camera.worldToScreen(CoordinateTransform.getEdgeAnchor(toObj.rect, fromObj.center));

        // Check label rect if present
        if (conn.label != null && conn.label!.isNotEmpty) {
          final mid = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
          final labelRect = Rect.fromCenter(center: mid, width: 90, height: 28);
          if (labelRect.contains(details.localFocalPoint)) {
            _handleEditConnection(conn);
            return;
          }
        }

        // Check line proximity
        final dist = _distToSegment(details.localFocalPoint, p1, p2);
        if (dist <= 14.0) {
          _handleEditConnection(conn);
          return;
        }
      }

      // Clicked on empty canvas background: deselect and start pan
      controller.clearSelection();
      _gestureMode = CanvasGestureMode.panning;
    }
  }

  double _distToSegment(Offset p, Offset v, Offset w) {
    final l2 = (w - v).distanceSquared;
    if (l2 == 0) return (p - v).distance;
    final t = ((p.dx - v.dx) * (w.dx - v.dx) + (p.dy - v.dy) * (w.dy - v.dy)) / l2;
    final clampedT = t.clamp(0.0, 1.0);
    final projection = Offset(v.dx + clampedT * (w.dx - v.dx), v.dy + clampedT * (w.dy - v.dy));
    return (p - projection).distance;
  }

  Future<void> _handleEditConnection(BoardConnection connection) async {
    final result = await ConnectionEditorDialog.show(context, connection: connection);
    if (result != null) {
      final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
      if (result.delete) {
        controller.deleteConnection(connection.id);
      } else {
        controller.editConnection(
          connectionId: connection.id,
          label: result.label,
          type: result.type,
        );
      }
    }
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    setState(() {
      _currentPointerScreenPos = details.localFocalPoint;
    });

    if (details.pointerCount >= 2) {
      // Pinch zoom
      final targetZoom = _pinchInitialZoom * details.scale;
      controller.zoomAt(details.localFocalPoint, targetZoom);
      return;
    }

    if (_gestureMode == CanvasGestureMode.panning) {
      controller.panBy(details.focalPointDelta);
    } else if (_gestureMode == CanvasGestureMode.movingObject && _draggingObjectId != null) {
      // Translate in world coordinates
      final worldDelta = details.focalPointDelta / state.camera.zoom;
      _dragCurrentWorldPos += worldDelta;
      controller.updateObjectPosition(_draggingObjectId!, _dragCurrentWorldPos);
    }
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    if (_gestureMode == CanvasGestureMode.movingObject && _draggingObjectId != null) {
      controller.commitObjectPosition(
        _draggingObjectId!,
        _dragInitialWorldPos,
        _dragCurrentWorldPos,
      );
    }

    setState(() {
      _gestureMode = CanvasGestureMode.none;
      _draggingObjectId = null;
    });
  }

  // ==========================================
  // OBJECT RESIZING
  // ==========================================

  void _onResizeStart(ResizeHandle handle, Offset screenDelta) {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final selected = state.selectedObject;
    if (selected == null) return;

    _gestureMode = CanvasGestureMode.resizingObject;
    _activeResizeHandle = handle;
    _resizeInitialRect = selected.rect;
    _resizeAccumulatedWorldDelta = Offset.zero;
  }

  void _onResizeUpdate(ResizeHandle handle, Offset screenDelta) {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final selected = state.selectedObject;
    if (selected == null || _activeResizeHandle == null) return;

    final worldDelta = screenDelta / state.camera.zoom;
    _resizeAccumulatedWorldDelta += worldDelta;

    final newRect = GestureManager.computeResizedRect(
      initialRect: _resizeInitialRect,
      handle: _activeResizeHandle!,
      worldDelta: _resizeAccumulatedWorldDelta,
      type: selected.type,
    );

    controller.updateObjectRect(selected.id, newRect);
  }

  void _onResizeEnd() {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final selected = state.selectedObject;

    if (selected != null && _activeResizeHandle != null) {
      controller.commitObjectRect(selected.id, _resizeInitialRect, selected.rect);
    }

    setState(() {
      _gestureMode = CanvasGestureMode.none;
      _activeResizeHandle = null;
    });
  }

  // ==========================================
  // OBJECT ACTIONS (Edit, Connect, Parent, etc.)
  // ==========================================

  Future<void> _handleEditObject(BoardObject object) async {
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    if (object is NoteObject) {
      final result = await NoteEditorDialog.show(
        context,
        initialTitle: object.title,
        initialContent: object.content,
        initialColorIndex: object.colorIndex,
        titleText: 'Edit Note',
      );
      if (result != null) {
        controller.editNote(
          noteId: object.id,
          newTitle: result.title,
          newContent: result.content,
          newColorIndex: result.colorIndex,
        );
      }
    } else if (object is GroupObject) {
      final newTitle = await GroupDialog.show(
        context,
        initialTitle: object.title,
        titleText: 'Rename Group',
        confirmText: 'Save',
      );
      if (newTitle != null) {
        controller.editGroup(groupId: object.id, newTitle: newTitle);
      }
    }
  }

  Future<void> _handleSetParent(BoardObject object) async {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    final selectedParentId = await ParentHierarchyDialog.show(
      context,
      currentObject: object,
      allObjects: state.objects.values.toList(),
    );

    if (selectedParentId == '__CLEAR__') {
      controller.setParentId(object.id, null);
    } else if (selectedParentId != null) {
      controller.setParentId(object.id, selectedParentId);
    }
  }

  Future<void> _handleAddObject(AddObjectType type) async {
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final viewportSize = MediaQuery.sizeOf(context);

    setState(() => _showDesktopAddMenu = false);

    switch (type) {
      case AddObjectType.note:
        final result = await NoteEditorDialog.show(
          context,
          titleText: 'New Note',
        );
        if (result != null) {
          controller.createNote(
            title: result.title,
            content: result.content,
            colorIndex: result.colorIndex,
            viewportSize: viewportSize,
          );
        }
        break;

      case AddObjectType.image:
        final result = await ImagePickerDialog.show(context);
        if (result != null) {
          controller.createImage(
            imageUrl: result.imageUrl,
            caption: result.caption,
            viewportSize: viewportSize,
          );
        }
        break;

      case AddObjectType.group:
        final title = await GroupDialog.show(context);
        if (title != null) {
          controller.createGroup(
            title: title,
            viewportSize: viewportSize,
          );
        }
        break;
    }
  }

  void _showMobileObjectSheet(BoardObject object) async {
    final action = await ObjectActionSheet.show(context, object);
    if (action == null) return;

    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);

    switch (action) {
      case ObjectActionType.edit:
        _handleEditObject(object);
        break;
      case ObjectActionType.connect:
        controller.startConnecting(object.id);
        break;
      case ObjectActionType.setParent:
        _handleSetParent(object);
        break;
      case ObjectActionType.duplicate:
        controller.duplicateObject(object.id);
        break;
      case ObjectActionType.delete:
        controller.deleteObject(object.id);
        break;
    }
  }

  void _openCanvasSearch() {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final viewportSize = MediaQuery.sizeOf(context);

    CanvasSearchDialog.show(
      context,
      objects: state.objects.values.toList(),
      onSelectObject: (obj) {
        controller.selectObject(obj.id);
        controller.centerOnObject(obj.id, viewportSize);
      },
    );
  }

  void _showSnapFeedback(bool enabled) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.grid_4x4_rounded : Icons.grid_off_rounded,
              size: 16,
              color: Colors.white,
            ),
            const SizedBox(width: 8),
            Text(enabled ? 'Snap to Grid: ON (24px)' : 'Snap to Grid: OFF'),
          ],
        ),
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
        width: 230,
        backgroundColor: enabled ? AppColors.primaryDark : const Color(0xFF334155),
      ),
    );
  }

  Future<void> _handleExportCurrentBoard() async {
    final boardRepo = ref.read(boardRepositoryProvider);
    final board = await boardRepo.getBoardById(widget.boardId);
    if (board != null && mounted) {
      ExportBoardDialog.show(context, ref, board);
    }
  }

  void _showManageConnectionsDialog(BoardObject obj) {
    final state = ref.read(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final related = state.connections
        .where((c) => c.fromObjectId == obj.id || c.toObjectId == obj.id)
        .toList();

    if (related.isEmpty) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.hub_outlined, color: AppColors.primary, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Connections (${related.length})',
                style: AppTextStyles.titleMedium,
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: related.map((conn) {
                final fromObj = state.objects[conn.fromObjectId];
                final toObj = state.objects[conn.toObjectId];
                final fromTitle = fromObj is NoteObject
                    ? fromObj.title
                    : (fromObj is GroupObject ? fromObj.title : 'Image');
                final toTitle = toObj is NoteObject
                    ? toObj.title
                    : (toObj is GroupObject ? toObj.title : 'Image');
                final isOutgoing = conn.fromObjectId == obj.id;
                final connColor = _resolveConnectionColor(conn.type);
                final baseStyle = conn.type.split(':')[0];

                return Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isOutgoing ? Icons.arrow_forward_rounded : Icons.arrow_back_rounded,
                        size: 16,
                        color: connColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOutgoing ? 'To: $toTitle' : 'From: $fromTitle',
                              style: AppTextStyles.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: connColor.withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    baseStyle.toUpperCase(),
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                      color: connColor,
                                    ),
                                  ),
                                ),
                                if (conn.label != null && conn.label!.isNotEmpty) ...[
                                  const SizedBox(width: 6),
                                  Flexible(
                                    child: Text(
                                      '"${conn.label}"',
                                      style: AppTextStyles.connectionLabel.copyWith(
                                        fontStyle: FontStyle.italic,
                                        color: AppColors.textSecondary,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        tooltip: 'Edit connection settings',
                        color: AppColors.primary,
                        onPressed: () {
                          Navigator.of(ctx).pop();
                          _handleEditConnection(conn);
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline_rounded, size: 18),
                        tooltip: 'Delete connection',
                        color: AppColors.error,
                        onPressed: () {
                          controller.deleteConnection(conn.id);
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildInteractiveConnectionBadge(BoardConnection conn, CanvasState state) {
    // Only display badge if connection has an actual user-defined label!
    // Connection type (e.g. arrow, curved, step) is never shown on a connection.
    if (conn.label == null || conn.label!.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    final fromObj = state.objects[conn.fromObjectId];
    final toObj = state.objects[conn.toObjectId];
    if (fromObj == null || toObj == null) return const SizedBox.shrink();

    final p1 = state.camera.worldToScreen(CoordinateTransform.getEdgeAnchor(fromObj.rect, toObj.center));
    final p2 = state.camera.worldToScreen(CoordinateTransform.getEdgeAnchor(toObj.rect, fromObj.center));

    final midScreen = _computeConnectionMidpoint(conn.type, p1, p2);
    final connColor = _resolveConnectionColor(conn.type);
    final scale = (state.camera.zoom).clamp(0.70, 1.05);

    return Positioned(
      left: midScreen.dx,
      top: midScreen.dy,
      child: FractionalTranslation(
        translation: const Offset(-0.5, -0.5),
        child: Transform.scale(
          scale: scale,
          child: Material(
            color: Colors.transparent,
            child: Tooltip(
              message: 'Connection: ${conn.label!} (Click to edit)',
              child: InkWell(
                onTap: () => _handleEditConnection(conn),
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 130),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: connColor.withOpacity(0.55), width: 1.0),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x14000000),
                        blurRadius: 3,
                        offset: Offset(0, 1),
                      ),
                    ],
                  ),
                  child: Text(
                    conn.label!,
                    style: TextStyle(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w500,
                      color: connColor == AppColors.connectionLine
                          ? AppColors.textSecondary
                          : connColor,
                      letterSpacing: 0.1,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Offset _computeConnectionMidpoint(String type, Offset p1, Offset p2) {
    final baseType = type.split(':')[0];
    if (baseType == 'curved') {
      final dx = p2.dx - p1.dx;
      final c1 = Offset(p1.dx + dx * 0.5, p1.dy);
      final c2 = Offset(p1.dx + dx * 0.5, p2.dy);
      return Offset(
        0.125 * p1.dx + 0.375 * c1.dx + 0.375 * c2.dx + 0.125 * p2.dx,
        0.125 * p1.dy + 0.375 * c1.dy + 0.375 * c2.dy + 0.125 * p2.dy,
      );
    } else if (baseType == 'step') {
      final midX = (p1.dx + p2.dx) / 2;
      return Offset(midX, (p1.dy + p2.dy) / 2);
    } else {
      return Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
    }
  }

  Color _resolveConnectionColor(String type) {
    if (type.contains(':')) {
      final colorKey = type.split(':')[1];
      switch (colorKey) {
        case 'blue':
          return const Color(0xFF3B82F6);
        case 'green':
          return const Color(0xFF10B981);
        case 'amber':
          return const Color(0xFFF59E0B);
        case 'purple':
          return const Color(0xFF8B5CF6);
        case 'rose':
          return const Color(0xFFEF4444);
        case 'slate':
          return const Color(0xFF64748B);
      }
    }
    return AppColors.connectionLine;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(canvasControllerProvider(widget.boardId));
    final controller = ref.read(canvasControllerProvider(widget.boardId).notifier);
    final isMobile = ResponsiveLayout.isMobile(context);
    final viewportSize = MediaQuery.sizeOf(context);

    return Focus(
      focusNode: _keyboardFocusNode,
      onKeyEvent: _handleKeyEvent,
      child: Scaffold(
        backgroundColor: AppColors.canvasBackground,
        body: SafeArea(
          child: Column(
            children: [
              // Top Toolbar
              CanvasToolbar(
                boardTitle: widget.boardName,
                state: state,
                controller: controller,
                onFit: () => controller.fitToViewport(viewportSize),
                onAutoArrange: () => controller.autoArrangeMap(),
                onOpenSearch: _openCanvasSearch,
                onExportBoard: _handleExportCurrentBoard,
              ),

              // Interactive Canvas Area
              Expanded(
                child: Listener(
                  onPointerSignal: _handlePointerSignal,
                  onPointerHover: (event) {
                    if (state.isConnecting) {
                      setState(() {
                        _currentPointerScreenPos = event.localPosition;
                      });
                    }
                  },
                  child: GestureDetector(
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    onScaleEnd: _onScaleEnd,
                    behavior: HitTestBehavior.opaque,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        // 1. Infinite Dotted Grid Background
                        Positioned.fill(
                          child: CustomPaint(
                            painter: CanvasBackgroundPainter(
                              camera: state.camera,
                              snapToGrid: state.snapToGrid,
                            ),
                          ),
                        ),

                        // 2. Connections Layer (rendered behind objects)
                        Positioned.fill(
                          child: IgnorePointer(
                            child: CustomPaint(
                              painter: ConnectionsPainter(
                                camera: state.camera,
                                connections: state.connections,
                                objects: state.objects,
                                connectingFromObjectId: state.connectingFromObjectId,
                                currentPointerScreenPos: _currentPointerScreenPos,
                              ),
                            ),
                          ),
                        ),

                        // 2.5 Interactive Connection Badges Layer (rendered on top of connection lines)
                        // Connection style/type is NEVER shown on canvas. Only user-authored labels appear.
                        if (state.camera.zoom >= 0.35)
                          ...state.connections
                              .where((conn) => conn.label != null && conn.label!.trim().isNotEmpty)
                              .map((conn) => _buildInteractiveConnectionBadge(conn, state)),

                        // 3. Groups Layer (rendered below cards)
                        ...state.groups.map((group) => _buildTransformedObject(
                              group,
                              state,
                              controller,
                              GroupCard(
                                group: group,
                                isSelected: state.selectedObjectId == group.id,
                                onTap: () => _handleObjectTap(group, state, controller),
                                onRename: () => _handleEditObject(group),
                                onArrange: () => controller.autoArrangeGrid(targetGroupId: group.id),
                              ),
                            )),

                        // 4. Images Layer
                        ...state.images.map((image) => _buildTransformedObject(
                              image,
                              state,
                              controller,
                              ImageCard(
                                image: image,
                                isSelected: state.selectedObjectId == image.id,
                                isConnectingSource:
                                    state.connectingFromObjectId == image.id,
                                onTap: () => _handleObjectTap(image, state, controller),
                              ),
                            )),

                        // 5. Notes Layer (rendered on top of images)
                        ...state.notes.map((note) => _buildTransformedObject(
                              note,
                              state,
                              controller,
                              NoteCard(
                                note: note,
                                isSelected: state.selectedObjectId == note.id,
                                isConnectingSource:
                                    state.connectingFromObjectId == note.id,
                                onTap: () => _handleObjectTap(note, state, controller),
                                onDoubleTap: () => _handleEditObject(note),
                                onToggleChecklist: (lineIdx) =>
                                    controller.toggleNoteChecklistItem(
                                  noteId: note.id,
                                  lineIndex: lineIdx,
                                ),
                              ),
                            )),

                        // 6. Selection Overlay with Corner Resize Handles & Action Bar
                        if (state.selectedObject != null && !state.isConnecting) ...[
                          CanvasSelectionOverlay(
                            object: state.selectedObject!,
                            camera: state.camera,
                            onPointerDown: () => _pointerOnOverlay = true,
                            onResizeStart: _onResizeStart,
                            onResizeUpdate: _onResizeUpdate,
                            onResizeEnd: _onResizeEnd,
                            onBranchRight: () =>
                                controller.branchChildNote(parentNoteId: state.selectedObjectId!),
                            onBranchBottom: () =>
                                controller.branchSiblingNote(sourceNoteId: state.selectedObjectId!),
                          ),
                          if (state.camera.zoom >= 0.4)
                            CanvasActionBar(
                              object: state.selectedObject!,
                              camera: state.camera,
                              onPointerDown: () => _pointerOnOverlay = true,
                              onBranch: () =>
                                  controller.branchChildNote(parentNoteId: state.selectedObjectId!),
                              onBranchSibling: () =>
                                  controller.branchSiblingNote(sourceNoteId: state.selectedObjectId!),
                              onEdit: () => _handleEditObject(state.selectedObject!),
                              onConnect: () =>
                                  controller.startConnecting(state.selectedObjectId!),
                              onSetParent: () => _handleSetParent(state.selectedObject!),
                              onDuplicate: () =>
                                  controller.duplicateObject(state.selectedObjectId!),
                              onDelete: () =>
                                  controller.deleteObject(state.selectedObjectId!),
                              connectionCount: state.connections
                                  .where((c) =>
                                      c.fromObjectId == state.selectedObjectId ||
                                      c.toObjectId == state.selectedObjectId)
                                  .length,
                              onManageConnections: () =>
                                  _showManageConnectionsDialog(state.selectedObject!),
                              onArrangeGroupGrid: () =>
                                  controller.autoArrangeGrid(targetGroupId: state.selectedObjectId),
                            ),
                        ],

                        // 7. Empty Canvas Guidance (Section 25)
                        if (state.objects.isEmpty && !state.isLoading)
                          Center(
                            child: _buildEmptyState(context, isMobile),
                          ),

                        // Desktop Floating Add Menu Popup
                        if (!isMobile && _showDesktopAddMenu)
                          Positioned(
                            bottom: 80,
                            right: 24,
                            child: AddMenuWidget(
                              onSelectType: _handleAddObject,
                            ),
                          ),

                        // Desktop Bottom-Right Floating Controls
                        if (!isMobile)
                          Positioned(
                            bottom: 24,
                            right: 24,
                            child: _buildDesktopFloatingBar(controller, viewportSize),
                          ),
                      ],
                    ),
                  ),
                ),
              ),

              // Mobile Bottom Navigation Bar (Section 18)
              if (isMobile)
                _buildMobileBottomBar(context, controller, viewportSize),
            ],
          ),
        ),
      ),
    );
  }

  void _handleObjectTap(
    BoardObject object,
    CanvasState state,
    CanvasController controller,
  ) {
    if (state.isConnecting) {
      controller.completeConnecting(object.id);
    } else {
      controller.selectObject(object.id);
      if (ResponsiveLayout.isMobile(context)) {
        _showMobileObjectSheet(object);
      }
    }
  }

  Widget _buildTransformedObject(
    BoardObject object,
    CanvasState state,
    CanvasController controller,
    Widget child,
  ) {
    final screenPos = state.camera.worldToScreen(object.position);

    return Positioned(
      left: screenPos.dx,
      top: screenPos.dy,
      child: Transform.scale(
        scale: state.camera.zoom,
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: object.width,
          height: object.height,
          child: child,
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, bool isMobile) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x100F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dashboard_customize_outlined, size: 40, color: AppColors.primary),
          const SizedBox(height: 12),
          const Text('Start building your board', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Add notes, images, or groups and arrange them visually.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ElevatedButton.icon(
                onPressed: () => _handleAddObject(AddObjectType.note),
                icon: const Icon(Icons.sticky_note_2_outlined, size: 16),
                label: const Text('Add Note'),
              ),
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => _handleAddObject(AddObjectType.image),
                icon: const Icon(Icons.image_outlined, size: 16),
                label: const Text('Add Image'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopFloatingBar(CanvasController controller, Size viewportSize) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
        boxShadow: const [
          BoxShadow(
            color: Color(0x180F172A),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ElevatedButton.icon(
            onPressed: () => setState(() => _showDesktopAddMenu = !_showDesktopAddMenu),
            icon: Icon(_showDesktopAddMenu ? Icons.close : Icons.add, size: 18),
            label: const Text('Add'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            ),
          ),
          const SizedBox(width: 6),
          Tooltip(
            message: 'Fit all objects',
            child: IconButton(
              icon: const Icon(Icons.crop_free_rounded, size: 18),
              onPressed: () => controller.fitToViewport(viewportSize),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMobileBottomBar(
    BuildContext context,
    CanvasController controller,
    Size viewportSize,
  ) {
    return Container(
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border, width: 1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          TextButton.icon(
            onPressed: () async {
              final type = await AddMenuWidget.showBottomSheet(context);
              if (type != null) _handleAddObject(type);
            },
            icon: const Icon(Icons.add_rounded, size: 20),
            label: const Text('Add'),
          ),
          TextButton.icon(
            onPressed: () => controller.fitToViewport(viewportSize),
            icon: const Icon(Icons.crop_free_rounded, size: 18),
            label: const Text('Fit'),
          ),
          TextButton.icon(
            onPressed: () => controller.resetZoom(viewportSize),
            icon: const Icon(Icons.center_focus_strong_rounded, size: 18),
            label: const Text('Zoom'),
          ),
        ],
      ),
    );
  }
}
