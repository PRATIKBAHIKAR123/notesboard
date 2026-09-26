import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../domain/canvas_camera.dart';

/// CustomPainter rendering an infinite dotted background grid.
/// The dots align strictly to world coordinates and scale/pan seamlessly with the camera.
class CanvasBackgroundPainter extends CustomPainter {
  final CanvasCamera camera;
  final bool snapToGrid;

  const CanvasBackgroundPainter({
    required this.camera,
    this.snapToGrid = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Fill base canvas background
    final bgPaint = Paint()..color = AppColors.canvasBackground;
    canvas.drawRect(Offset.zero & size, bgPaint);

    // 2. Adaptive grid dot sizing based on zoom
    final double zoom = camera.zoom;
    if (zoom < 0.25) return; // Skip rendering tiny dots when zoomed extremely far out

    double spacing = AppConstants.gridSpacing;
    if (zoom < 0.5) {
      spacing *= 2; // Reduce density at distant zoom
    }

    final dotColor = snapToGrid
        ? AppColors.primary.withOpacity((0.55 * (zoom.clamp(0.25, 1.0))).clamp(0.25, 0.75))
        : AppColors.canvasDot.withOpacity((0.6 * (zoom.clamp(0.25, 1.0))).clamp(0.15, 0.7));

    final dotPaint = Paint()
      ..color = dotColor
      ..isAntiAlias = true;

    final worldTopLeft = camera.screenToWorld(Offset.zero);
    final worldBottomRight = camera.screenToWorld(Offset(size.width, size.height));

    final startX = (worldTopLeft.dx / spacing).floor() * spacing;
    final endX = (worldBottomRight.dx / spacing).ceil() * spacing;
    final startY = (worldTopLeft.dy / spacing).floor() * spacing;
    final endY = (worldBottomRight.dy / spacing).ceil() * spacing;

    final radius = snapToGrid
        ? (AppConstants.gridDotRadius * zoom * 1.3).clamp(1.1, 2.2)
        : (AppConstants.gridDotRadius * zoom).clamp(0.8, 1.6);

    for (double wx = startX; wx <= endX; wx += spacing) {
      for (double wy = startY; wy <= endY; wy += spacing) {
        final screenPos = camera.worldToScreen(Offset(wx, wy));
        canvas.drawCircle(screenPos, radius, dotPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CanvasBackgroundPainter oldDelegate) {
    return oldDelegate.camera != camera || oldDelegate.snapToGrid != snapToGrid;
  }
}
