import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../app/theme/app_colors.dart';
import '../../domain/board_connection.dart';
import '../../domain/board_object.dart';
import '../../domain/canvas_camera.dart';
import '../../engine/coordinate_transform.dart';

/// CustomPainter rendering connections between objects on the canvas.
/// Supports straight arrows, smooth Bezier curves, dashed lines, and labeled badges.
class ConnectionsPainter extends CustomPainter {
  final CanvasCamera camera;
  final List<BoardConnection> connections;
  final Map<String, BoardObject> objects;
  final String? connectingFromObjectId;
  final Offset? currentPointerScreenPos;
  final bool drawLabels;

  const ConnectionsPainter({
    required this.camera,
    required this.connections,
    required this.objects,
    this.connectingFromObjectId,
    this.currentPointerScreenPos,
    this.drawLabels = false,
  });

  Color _resolveColor(String type) {
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
  void paint(Canvas canvas, Size size) {
    // 1. Draw existing connections
    for (final conn in connections) {
      final fromObj = objects[conn.fromObjectId];
      final toObj = objects[conn.toObjectId];

      if (fromObj == null || toObj == null) continue;

      final connColor = _resolveColor(conn.type);
      final linePaint = Paint()
        ..color = connColor
        ..strokeWidth = (2.0 * camera.zoom).clamp(1.2, 3.5)
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final arrowPaint = Paint()
        ..color = connColor
        ..style = PaintingStyle.fill;

      // Calculate edge anchor points in world coordinates
      final fromAnchorWorld = CoordinateTransform.getEdgeAnchor(fromObj.rect, toObj.center);
      final toAnchorWorld = CoordinateTransform.getEdgeAnchor(toObj.rect, fromObj.center);

      // Convert to screen coordinates
      final p1 = camera.worldToScreen(fromAnchorWorld);
      final p2 = camera.worldToScreen(toAnchorWorld);

      final baseType = conn.type.split(':')[0];
      final isCurved = baseType == 'curved';
      final isDashed = baseType == 'dashed';
      final isStep = baseType == 'step';
      final isBidirectional = baseType == 'bidirectional';
      final isPlainLine = baseType == 'line';

      Offset labelPoint;
      double endAngle;
      double startAngle = math.atan2(p1.dy - p2.dy, p1.dx - p2.dx);

      if (isCurved) {
        // Cubic Bezier curve
        final dx = p2.dx - p1.dx;
        final c1 = Offset(p1.dx + dx * 0.5, p1.dy);
        final c2 = Offset(p1.dx + dx * 0.5, p2.dy);

        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);

        canvas.drawPath(path, linePaint);

        labelPoint = Offset(
          0.125 * p1.dx + 0.375 * c1.dx + 0.375 * c2.dx + 0.125 * p2.dx,
          0.125 * p1.dy + 0.375 * c1.dy + 0.375 * c2.dy + 0.125 * p2.dy,
        );
        endAngle = math.atan2(p2.dy - c2.dy, p2.dx - c2.dx);
      } else if (isStep) {
        // Orthogonal stepped elbow connector
        final midX = (p1.dx + p2.dx) / 2;
        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(midX, p1.dy)
          ..lineTo(midX, p2.dy)
          ..lineTo(p2.dx, p2.dy);

        canvas.drawPath(path, linePaint);
        labelPoint = Offset(midX, (p1.dy + p2.dy) / 2);
        endAngle = math.atan2(0, p2.dx - midX);
        startAngle = math.atan2(0, p1.dx - midX);
      } else if (isDashed) {
        // Dashed line
        final path = Path()
          ..moveTo(p1.dx, p1.dy)
          ..lineTo(p2.dx, p2.dy);

        final dashedPath = _createDashedPath(path, 8.0 * camera.zoom, 5.0 * camera.zoom);
        canvas.drawPath(dashedPath, linePaint);

        labelPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        endAngle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      } else {
        // Straight line / Arrow (default)
        canvas.drawLine(p1, p2, linePaint);
        labelPoint = Offset((p1.dx + p2.dx) / 2, (p1.dy + p2.dy) / 2);
        endAngle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
      }

      // Draw arrowheads based on style
      if (!isPlainLine) {
        _drawArrowheadAt(canvas, p2, endAngle, arrowPaint);
        if (isBidirectional) {
          _drawArrowheadAt(canvas, p1, startAngle, arrowPaint);
        }
      }

      // Draw label if requested and present
      if (drawLabels && conn.label != null && conn.label!.isNotEmpty && camera.zoom >= 0.45) {
        _drawConnectionLabel(canvas, labelPoint, conn.label!);
      }
    }

    // 2. Draw live preview connecting line if user is in "Connect" mode
    if (connectingFromObjectId != null && currentPointerScreenPos != null) {
      final sourceObj = objects[connectingFromObjectId];
      if (sourceObj != null) {
        final p1 = camera.worldToScreen(sourceObj.center);
        final p2 = currentPointerScreenPos!;

        final previewPaint = Paint()
          ..color = AppColors.primary
          ..strokeWidth = (2.0 * camera.zoom).clamp(1.5, 3.0)
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round;

        canvas.drawLine(p1, p2, previewPaint);
        final angle = math.atan2(p2.dy - p1.dy, p2.dx - p1.dx);
        _drawArrowheadAt(canvas, p2, angle, Paint()..color = AppColors.primary);
      }
    }
  }

  Path _createDashedPath(Path source, double dashLength, double dashGap) {
    final dest = Path();
    for (final metric in source.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final len = math.min(dashLength, metric.length - distance);
        dest.addPath(
          metric.extractPath(distance, distance + len),
          Offset.zero,
        );
        distance += dashLength + dashGap;
      }
    }
    return dest;
  }

  void _drawArrowheadAt(Canvas canvas, Offset tip, double angle, Paint paint) {
    final arrowLength = (10.0 * camera.zoom).clamp(7.0, 14.0);
    const arrowAngle = 28 * math.pi / 180;

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(
        tip.dx - arrowLength * math.cos(angle - arrowAngle),
        tip.dy - arrowLength * math.sin(angle - arrowAngle),
      )
      ..lineTo(
        tip.dx - arrowLength * math.cos(angle + arrowAngle),
        tip.dy - arrowLength * math.sin(angle + arrowAngle),
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  void _drawConnectionLabel(Canvas canvas, Offset center, String label) {
    final textSpan = TextSpan(
      text: label,
      style: TextStyle(
        fontSize: (11.0 * camera.zoom).clamp(9.0, 13.0),
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textDirection: TextDirection.ltr,
    )..layout();

    final bgRect = Rect.fromCenter(
      center: center,
      width: textPainter.width + 14,
      height: textPainter.height + 6,
    );

    final rrect = RRect.fromRectAndRadius(bgRect, const Radius.circular(6));
    final bgPaint = Paint()..color = Colors.white;
    final shadowPaint = Paint()
      ..color = const Color(0x150F172A)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    final borderPaint = Paint()
      ..color = AppColors.border
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawRRect(rrect.shift(const Offset(0, 1)), shadowPaint);
    canvas.drawRRect(rrect, bgPaint);
    canvas.drawRRect(rrect, borderPaint);

    textPainter.paint(
      canvas,
      Offset(center.dx - textPainter.width / 2, center.dy - textPainter.height / 2),
    );
  }

  @override
  bool shouldRepaint(covariant ConnectionsPainter oldDelegate) {
    return oldDelegate.camera != camera ||
        oldDelegate.connections != connections ||
        oldDelegate.objects != objects ||
        oldDelegate.connectingFromObjectId != connectingFromObjectId ||
        oldDelegate.currentPointerScreenPos != currentPointerScreenPos;
  }
}
