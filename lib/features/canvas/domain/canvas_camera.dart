import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';

/// Camera representing the user's viewport on the infinite canvas.
///
/// World coordinates are transformed to screen coordinates via:
/// screenPoint = (worldPoint * zoom) + pan
class CanvasCamera {
  final Offset pan;
  final double zoom;

  const CanvasCamera({
    this.pan = Offset.zero,
    this.zoom = AppConstants.defaultZoom,
  });

  double get cameraX => pan.dx;
  double get cameraY => pan.dy;

  CanvasCamera copyWith({
    Offset? pan,
    double? zoom,
  }) {
    return CanvasCamera(
      pan: pan ?? this.pan,
      zoom: (zoom ?? this.zoom).clamp(AppConstants.minZoom, AppConstants.maxZoom),
    );
  }

  /// Convert world position to viewport screen position
  Offset worldToScreen(Offset world) {
    return (world * zoom) + pan;
  }

  /// Convert viewport screen position to infinite canvas world position
  Offset screenToWorld(Offset screen) {
    return (screen - pan) / zoom;
  }

  /// Convert world rectangle to screen rectangle
  Rect worldToScreenRect(Rect worldRect) {
    return Rect.fromLTWH(
      worldRect.left * zoom + pan.dx,
      worldRect.top * zoom + pan.dy,
      worldRect.width * zoom,
      worldRect.height * zoom,
    );
  }

  /// Pan by a screen offset delta (e.g. dragging empty canvas space)
  CanvasCamera panBy(Offset delta) {
    return copyWith(pan: pan + delta);
  }

  /// Zoom in or out anchored at a specific screen focal point
  /// The world coordinate under [screenFocalPoint] remains motionless under that screen point.
  CanvasCamera zoomAt(Offset screenFocalPoint, double targetZoom) {
    final clampedZoom = targetZoom.clamp(AppConstants.minZoom, AppConstants.maxZoom);
    if (clampedZoom == zoom) return this;

    final worldFocal = screenToWorld(screenFocalPoint);
    // newPan = screenFocalPoint - (worldFocal * clampedZoom)
    final newPan = screenFocalPoint - (worldFocal * clampedZoom);

    return CanvasCamera(
      pan: newPan,
      zoom: clampedZoom,
    );
  }

  /// Step zoom at viewport center
  CanvasCamera zoomStep({required bool zoomIn, Size? viewportSize}) {
    final center = viewportSize != null
        ? Offset(viewportSize.width / 2, viewportSize.height / 2)
        : Offset.zero;
    final nextZoom = zoomIn
        ? (zoom + AppConstants.zoomStep)
        : (zoom - AppConstants.zoomStep);
    return zoomAt(center, nextZoom);
  }

  /// Reset or adjust camera to fit all objects within the viewport
  CanvasCamera fitBounds(Rect worldBounds, Size viewportSize, {double padding = 80.0}) {
    if (worldBounds.isEmpty || viewportSize.isEmpty) {
      return const CanvasCamera(pan: Offset.zero, zoom: 1.0);
    }

    final availableWidth = math.max(viewportSize.width - (padding * 2), 100.0);
    final availableHeight = math.max(viewportSize.height - (padding * 2), 100.0);

    final scaleX = availableWidth / worldBounds.width;
    final scaleY = availableHeight / worldBounds.height;
    final targetZoom = math.min(scaleX, scaleY).clamp(AppConstants.minZoom, 1.25);

    // Center worldBounds in viewport
    final worldCenter = worldBounds.center;
    final screenCenter = Offset(viewportSize.width / 2, viewportSize.height / 2);
    final targetPan = screenCenter - (worldCenter * targetZoom);

    return CanvasCamera(pan: targetPan, zoom: targetZoom);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CanvasCamera &&
          runtimeType == other.runtimeType &&
          pan == other.pan &&
          zoom == other.zoom;

  @override
  int get hashCode => pan.hashCode ^ zoom.hashCode;
}
