import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Utilities for canvas coordinate conversions, hit testing, and geometry
class CoordinateTransform {
  CoordinateTransform._();

  /// Calculates the point on the boundary of [rect] that intersects the line
  /// pointing from [rect.center] towards [targetCenter].
  static Offset getEdgeAnchor(Rect rect, Offset targetCenter) {
    final center = rect.center;
    final dx = targetCenter.dx - center.dx;
    final dy = targetCenter.dy - center.dy;

    if (dx.abs() < 0.0001 && dy.abs() < 0.0001) {
      return center;
    }

    final halfW = rect.width / 2;
    final halfH = rect.height / 2;

    // Check intersection with vertical edges (x = ±halfW)
    final slope = dy / (dx == 0 ? 0.00001 : dx);

    // Test right/left edge
    final double edgeX = dx > 0 ? halfW : -halfW;
    final double edgeY = edgeX * slope;

    if (edgeY.abs() <= halfH) {
      return Offset(center.dx + edgeX, center.dy + edgeY);
    }

    // Test bottom/top edge
    final double edgeY2 = dy > 0 ? halfH : -halfH;
    final double edgeX2 = edgeY2 / slope;

    return Offset(center.dx + edgeX2, center.dy + edgeY2);
  }

  /// Checks if a world point is inside a world rectangle
  static bool hitTest(Offset worldPoint, Rect worldRect) {
    return worldRect.contains(worldPoint);
  }

  /// Helper to calculate distance between two points
  static double distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }
}
