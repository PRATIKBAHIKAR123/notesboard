import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../domain/board_object.dart';
import '../domain/canvas_state.dart';
import '../engine/canvas_controller.dart';

class CanvasToolbar extends StatelessWidget {
  final String boardTitle;
  final CanvasState state;
  final CanvasController controller;
  final VoidCallback? onRenameBoard;
  final VoidCallback? onOpenSearch;
  final VoidCallback? onFit;
  final VoidCallback? onAutoArrange;
  final VoidCallback? onExportBoard;

  const CanvasToolbar({
    super.key,
    required this.boardTitle,
    required this.state,
    required this.controller,
    this.onRenameBoard,
    this.onOpenSearch,
    this.onFit,
    this.onAutoArrange,
    this.onExportBoard,
  });

  @override
  Widget build(BuildContext context) {
    final isMobile = ResponsiveLayout.isMobile(context);
    final zoomPercentage = (state.camera.zoom * 100).round();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Toolbar Container
        Container(
          height: isMobile ? 54 : 60,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              // Back Button
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                tooltip: 'Back to Boards',
                onPressed: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/boards');
                  }
                },
              ),
              const SizedBox(width: 4),

              // Board Title (Tappable to rename)
              InkWell(
                onTap: onRenameBoard,
                borderRadius: BorderRadius.circular(6),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      ConstrainedBox(
                        constraints: BoxConstraints(
                          maxWidth: isMobile ? 140 : 260,
                        ),
                        child: Text(
                          boardTitle,
                          style: AppTextStyles.titleMedium,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.edit_outlined, size: 14, color: AppColors.textMuted),
                    ],
                  ),
                ),
              ),

              const Spacer(),

              // Desktop Controls
              if (!isMobile) ...[
                // Search
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  tooltip: 'Search in Board (Ctrl+F)',
                  onPressed: onOpenSearch,
                ),
                const SizedBox(width: 4),

                // Undo
                IconButton(
                  icon: const Icon(Icons.undo_rounded, size: 20),
                  tooltip: 'Undo (Ctrl+Z)',
                  onPressed: controller.canUndo ? () => controller.undo() : null,
                  color: controller.canUndo ? AppColors.textPrimary : AppColors.textMuted,
                ),

                // Redo
                IconButton(
                  icon: const Icon(Icons.redo_rounded, size: 20),
                  tooltip: 'Redo (Ctrl+Shift+Z)',
                  onPressed: controller.canRedo ? () => controller.redo() : null,
                  color: controller.canRedo ? AppColors.textPrimary : AppColors.textMuted,
                ),

                const SizedBox(width: 8),
                const VerticalDivider(indent: 14, endIndent: 14),
                const SizedBox(width: 8),

                // Zoom Out
                IconButton(
                  icon: const Icon(Icons.remove_rounded, size: 18),
                  tooltip: 'Zoom Out',
                  onPressed: () => controller.zoomStep(zoomIn: false),
                ),

                // Zoom Percentage
                InkWell(
                  onTap: () => controller.resetZoom(MediaQuery.sizeOf(context)),
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Text(
                      '$zoomPercentage%',
                      style: AppTextStyles.labelMedium.copyWith(fontSize: 12),
                    ),
                  ),
                ),

                // Zoom In
                IconButton(
                  icon: const Icon(Icons.add_rounded, size: 18),
                  tooltip: 'Zoom In',
                  onPressed: () => controller.zoomStep(zoomIn: true),
                ),

                // Fit Button
                IconButton(
                  icon: const Icon(Icons.crop_free_rounded, size: 18),
                  tooltip: 'Fit to Viewport',
                  onPressed: onFit,
                ),

                // Snap to Grid Toggle
                IconButton(
                  icon: Icon(
                    Icons.grid_4x4_rounded,
                    size: 18,
                    color: state.snapToGrid ? AppColors.primary : AppColors.textSecondary,
                  ),
                  tooltip: state.snapToGrid ? 'Snap to Grid: ON (Ctrl+G)' : 'Snap to Grid: OFF (Ctrl+G)',
                  style: state.snapToGrid
                      ? IconButton.styleFrom(backgroundColor: AppColors.primaryMuted)
                      : null,
                  onPressed: () => controller.toggleSnapToGrid(),
                ),

                // Auto-Arrange Layouts Dropdown
                PopupMenuButton<String>(
                  icon: const Icon(Icons.auto_awesome_mosaic_outlined, size: 18),
                  tooltip: 'Auto-Arrange & Grid Layouts',
                  onSelected: (val) {
                    if (val == 'horizontal') controller.autoArrangeMap();
                    if (val == 'vertical') controller.autoArrangeVerticalTree();
                    if (val == 'grid') controller.autoArrangeGrid();
                    if (val == 'snapAll') controller.snapAllObjectsToGrid();
                  },
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'horizontal',
                      child: Row(
                        children: [
                          Icon(Icons.alt_route_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Mind Map (Horizontal)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'vertical',
                      child: Row(
                        children: [
                          Icon(Icons.account_tree_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Hierarchy (Vertical)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'grid',
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text(state.selectedObject is GroupObject
                              ? 'Grid Layout (Selected Group)'
                              : (state.selectedObject != null
                                  ? 'Grid Layout (Selective Notes)'
                                  : 'Grid Tile Layout (All)')),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(),
                    const PopupMenuItem(
                      value: 'snapAll',
                      child: Row(
                        children: [
                          Icon(Icons.grid_4x4_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Snap All to Grid (24px)'),
                        ],
                      ),
                    ),
                  ],
                ),

                // Export Board
                if (onExportBoard != null)
                  IconButton(
                    icon: const Icon(Icons.download_rounded, size: 18),
                    tooltip: 'Export Board (JSON / Markdown)',
                    onPressed: onExportBoard,
                  ),
              ] else ...[
                // Mobile compact actions
                IconButton(
                  icon: const Icon(Icons.search_rounded, size: 20),
                  tooltip: 'Search',
                  onPressed: onOpenSearch,
                ),
                PopupMenuButton<String>(
                  icon: const Icon(Icons.more_vert_rounded, size: 20),
                  onSelected: (val) {
                    if (val == 'undo' && controller.canUndo) controller.undo();
                    if (val == 'redo' && controller.canRedo) controller.redo();
                    if (val == 'fit') onFit?.call();
                    if (val == 'autoArrange') controller.autoArrangeMap();
                    if (val == 'autoArrangeVertical') controller.autoArrangeVerticalTree();
                    if (val == 'autoArrangeGrid') controller.autoArrangeGrid();
                    if (val == 'snap') controller.toggleSnapToGrid();
                    if (val == 'snapAll') controller.snapAllObjectsToGrid();
                    if (val == 'export') onExportBoard?.call();
                    if (val == 'rename') onRenameBoard?.call();
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'undo',
                      enabled: controller.canUndo,
                      child: const Row(
                        children: [
                          Icon(Icons.undo_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Undo'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'redo',
                      enabled: controller.canRedo,
                      child: const Row(
                        children: [
                          Icon(Icons.redo_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Redo'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'fit',
                      child: Row(
                        children: [
                          Icon(Icons.crop_free_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Fit Objects'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'autoArrange',
                      child: Row(
                        children: [
                          Icon(Icons.alt_route_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Mind Map (Horizontal)'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'autoArrangeVertical',
                      child: Row(
                        children: [
                          Icon(Icons.account_tree_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Hierarchy (Vertical)'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'autoArrangeGrid',
                      child: Row(
                        children: [
                          const Icon(Icons.grid_view_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text(state.selectedObject is GroupObject
                              ? 'Grid Layout (Selected Group)'
                              : 'Grid Tile Layout'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'snap',
                      child: Row(
                        children: [
                          const Icon(Icons.grid_4x4_rounded, size: 18),
                          const SizedBox(width: 10),
                          Text(state.snapToGrid ? 'Snap to Grid: ON' : 'Snap to Grid: OFF'),
                        ],
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'snapAll',
                      child: Row(
                        children: [
                          Icon(Icons.straighten_rounded, size: 18),
                          SizedBox(width: 10),
                          Text('Snap All to Grid'),
                        ],
                      ),
                    ),
                    if (onExportBoard != null)
                      const PopupMenuItem(
                        value: 'export',
                        child: Row(
                          children: [
                            Icon(Icons.download_rounded, size: 18),
                            SizedBox(width: 10),
                            Text('Export Board (JSON)'),
                          ],
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, size: 18),
                          SizedBox(width: 10),
                          Text('Rename Board'),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),

        // Live Connecting Status Banner
        if (state.isConnecting)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            color: AppColors.primaryDark,
            child: Row(
              children: [
                const Icon(Icons.alt_route_rounded, size: 16, color: Colors.white),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Click on another object to connect, or click Cancel.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => controller.cancelConnecting(),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  ),
                  child: const Text('Cancel'),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
