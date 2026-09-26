import 'package:flutter/material.dart';
import '../../../app/theme/app_colors.dart';
import '../domain/board_object.dart';
import '../domain/canvas_camera.dart';
import '../engine/gesture_manager.dart';

/// Overlay drawn on top of the currently selected canvas object.
/// Provides visible selection outline and corner resize handles.
class CanvasSelectionOverlay extends StatelessWidget {
  final BoardObject object;
  final CanvasCamera camera;
  final VoidCallback? onPointerDown;
  final void Function(ResizeHandle handle, Offset screenDelta)? onResizeStart;
  final void Function(ResizeHandle handle, Offset screenDelta)? onResizeUpdate;
  final VoidCallback? onResizeEnd;
  final VoidCallback? onBranchRight;
  final VoidCallback? onBranchBottom;

  const CanvasSelectionOverlay({
    super.key,
    required this.object,
    required this.camera,
    this.onPointerDown,
    this.onResizeStart,
    this.onResizeUpdate,
    this.onResizeEnd,
    this.onBranchRight,
    this.onBranchBottom,
  });

  @override
  Widget build(BuildContext context) {
    // Screen bounds of the object
    final screenRect = camera.worldToScreenRect(object.rect);
    const handleSize = 12.0;
    const margin = 80.0;
    final totalW = screenRect.width + 2 * margin;
    final totalH = screenRect.height + 2 * margin;

    return Positioned(
      left: screenRect.left - margin,
      top: screenRect.top - margin,
      width: totalW,
      height: totalH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Bounding Box (IgnorePointer so inner clicks pass to the card below)
          Positioned(
            left: margin - 6,
            top: margin - 6,
            width: screenRect.width + 12,
            height: screenRect.height + 12,
            child: IgnorePointer(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.primary,
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ),

          // Top-Left Handle
          Positioned(
            left: margin - 6,
            top: margin - 6,
            child: _buildResizeHandle(ResizeHandle.topLeft, handleSize),
          ),

          // Top-Right Handle
          Positioned(
            left: margin + screenRect.width + 6 - handleSize,
            top: margin - 6,
            child: _buildResizeHandle(ResizeHandle.topRight, handleSize),
          ),

          // Bottom-Left Handle
          Positioned(
            left: margin - 6,
            top: margin + screenRect.height + 6 - handleSize,
            child: _buildResizeHandle(ResizeHandle.bottomLeft, handleSize),
          ),

          // Bottom-Right Handle
          Positioned(
            left: margin + screenRect.width + 6 - handleSize,
            top: margin + screenRect.height + 6 - handleSize,
            child: _buildResizeHandle(ResizeHandle.bottomRight, handleSize),
          ),

          // Quick Branch Handle: Right (Child note)
          if (object is NoteObject && onBranchRight != null && camera.zoom >= 0.45)
            Positioned(
              left: margin + screenRect.width + 8,
              top: (totalH / 2) - 18,
              child: _buildBranchButton(
                icon: Icons.add_rounded,
                label: 'Child',
                tooltip: 'Branch Child note (Tab)',
                onTap: onBranchRight!,
              ),
            ),

          // Quick Branch Handle: Bottom (Sibling note)
          if (object is NoteObject && onBranchBottom != null && camera.zoom >= 0.45)
            Positioned(
              left: (totalW / 2) - 40,
              top: margin + screenRect.height + 8,
              child: _buildBranchButton(
                icon: Icons.subdirectory_arrow_right_rounded,
                label: 'Sibling',
                tooltip: 'Branch Sibling note (Down / Enter)',
                onTap: onBranchBottom!,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBranchButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    String? label,
  }) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerDown?.call(),
      child: Tooltip(
        message: tooltip,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16),
            hoverColor: AppColors.primaryMuted,
            child: Container(
              padding: const EdgeInsets.all(4),
              child: Container(
                height: 30,
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.45),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(icon, size: 15, color: Colors.white),
                    if (label != null) ...[
                      const SizedBox(width: 4),
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResizeHandle(ResizeHandle handle, double size) {
    return Listener(
      behavior: HitTestBehavior.opaque,
      onPointerDown: (_) => onPointerDown?.call(),
      child: GestureDetector(
        onPanStart: (details) => onResizeStart?.call(handle, details.localPosition),
        onPanUpdate: (details) => onResizeUpdate?.call(handle, details.delta),
        onPanEnd: (_) => onResizeEnd?.call(),
        child: MouseRegion(
          cursor: _getCursorForHandle(handle),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.primary, width: 2),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x20000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  MouseCursor _getCursorForHandle(ResizeHandle handle) {
    switch (handle) {
      case ResizeHandle.topLeft:
      case ResizeHandle.bottomRight:
        return SystemMouseCursors.resizeUpLeftDownRight;
      case ResizeHandle.topRight:
      case ResizeHandle.bottomLeft:
        return SystemMouseCursors.resizeUpRightDownLeft;
    }
  }
}

/// Floating action bar positioned above the currently selected object.
/// Provides quick actions: Edit, Connect, Set Parent, Duplicate, Delete.
class CanvasActionBar extends StatelessWidget {
  final BoardObject object;
  final CanvasCamera camera;
  final VoidCallback? onPointerDown;
  final VoidCallback? onBranch;
  final VoidCallback? onBranchSibling;
  final VoidCallback? onEdit;
  final VoidCallback? onConnect;
  final VoidCallback? onSetParent;
  final VoidCallback? onDuplicate;
  final VoidCallback? onDelete;
  final int connectionCount;
  final VoidCallback? onManageConnections;
  final VoidCallback? onArrangeGroupGrid;

  const CanvasActionBar({
    super.key,
    required this.object,
    required this.camera,
    this.onPointerDown,
    this.onBranch,
    this.onBranchSibling,
    this.onEdit,
    this.onConnect,
    this.onSetParent,
    this.onDuplicate,
    this.onDelete,
    this.connectionCount = 0,
    this.onManageConnections,
    this.onArrangeGroupGrid,
  });

  @override
  Widget build(BuildContext context) {
    final screenRect = camera.worldToScreenRect(object.rect);
    const barHeight = 40.0;

    // Place above card if there is space, otherwise place below card
    final barTop = (screenRect.top - barHeight - 8) >= 8
        ? screenRect.top - barHeight - 8
        : screenRect.bottom + 8;

    // Center horizontally over the object
    final viewportWidth = MediaQuery.sizeOf(context).width;
    const estimatedBarWidth = 280.0;
    final idealLeft = screenRect.center.dx - (estimatedBarWidth / 2);
    final isCardVisible =
        screenRect.right > 40 && screenRect.left < (viewportWidth - 40);
    final barLeft = isCardVisible
        ? idealLeft.clamp(
            12.0,
            (viewportWidth - estimatedBarWidth - 12.0).clamp(12.0, double.infinity),
          )
        : idealLeft;

    return Positioned(
      left: barLeft,
      top: barTop,
      child: Listener(
        behavior: HitTestBehavior.opaque,
        onPointerDown: (_) => onPointerDown?.call(),
        child: _buildQuickActionBar(),
      ),
    );
  }

  Widget _buildQuickActionBar() {
    return Material(
      color: AppColors.surface,
      elevation: 3,
      borderRadius: BorderRadius.circular(8),
      shadowColor: const Color(0x180F172A),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border, width: 1),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if ((object is NoteObject || object is GroupObject) && onEdit != null)
              _buildActionIcon(
                icon: Icons.edit_outlined,
                tooltip: object is GroupObject ? 'Rename group' : 'Edit note',
                onTap: onEdit!,
              ),
            if (object is GroupObject && onArrangeGroupGrid != null)
              _buildActionIcon(
                icon: Icons.grid_view_rounded,
                tooltip: 'Auto-arrange group grid',
                color: AppColors.primary,
                onTap: onArrangeGroupGrid!,
              ),
            if (connectionCount > 0 && onManageConnections != null)
              _buildActionIcon(
                icon: Icons.hub_outlined,
                tooltip: 'Manage connections ($connectionCount)',
                color: AppColors.primary,
                onTap: onManageConnections!,
              ),
            if (object is NoteObject && onBranch != null)
              _buildActionIcon(
                icon: Icons.call_split_rounded,
                tooltip: 'Branch child note (Tab)',
                color: AppColors.primary,
                onTap: onBranch!,
              ),
            if (object is NoteObject && onBranchSibling != null)
              _buildActionIcon(
                icon: Icons.subdirectory_arrow_right_rounded,
                tooltip: 'Branch sibling note (Enter)',
                color: AppColors.primary,
                onTap: onBranchSibling!,
              ),
            if (onConnect != null)
              _buildActionIcon(
                icon: Icons.alt_route_rounded,
                tooltip: 'Connect',
                onTap: onConnect!,
              ),
            if (onSetParent != null && object is! GroupObject)
              _buildActionIcon(
                icon: Icons.account_tree_outlined,
                tooltip: 'Set parent hierarchy',
                onTap: onSetParent!,
              ),
            if (onDuplicate != null)
              _buildActionIcon(
                icon: Icons.copy_rounded,
                tooltip: 'Duplicate',
                onTap: onDuplicate!,
              ),
            if (onDelete != null)
              _buildActionIcon(
                icon: Icons.delete_outline_rounded,
                tooltip: 'Delete',
                color: AppColors.error,
                onTap: onDelete!,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionIcon({
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? color,
  }) {
    return IconButton(
      icon: Icon(
        icon,
        size: 16,
        color: color ?? AppColors.textSecondary,
      ),
      tooltip: tooltip,
      onPressed: onTap,
      splashRadius: 16,
      constraints: const BoxConstraints(minWidth: 34, minHeight: 34),
      padding: EdgeInsets.zero,
    );
  }
}
