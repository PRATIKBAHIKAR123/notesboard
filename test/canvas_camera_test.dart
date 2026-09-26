import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:notesboard/features/canvas/domain/canvas_camera.dart';

void main() {
  group('CanvasCamera Coordinate & Zoom Tests', () {
    test('Default camera identity transform', () {
      const camera = CanvasCamera();
      expect(camera.zoom, 1.0);
      expect(camera.pan, Offset.zero);

      const worldPoint = Offset(150, 250);
      expect(camera.worldToScreen(worldPoint), worldPoint);
      expect(camera.screenToWorld(worldPoint), worldPoint);
    });

    test('Pan transform', () {
      const camera = CanvasCamera(pan: Offset(100, 50), zoom: 1.0);
      const worldPoint = Offset(50, 50);

      // screen = world * zoom + pan = (50, 50) + (100, 50) = (150, 100)
      expect(camera.worldToScreen(worldPoint), const Offset(150, 100));
      expect(camera.screenToWorld(const Offset(150, 100)), worldPoint);
    });

    test('Zoom transform', () {
      const camera = CanvasCamera(pan: Offset.zero, zoom: 2.0);
      const worldPoint = Offset(50, 50);

      // screen = world * zoom = (100, 100)
      expect(camera.worldToScreen(worldPoint), const Offset(100, 100));
      expect(camera.screenToWorld(const Offset(100, 100)), worldPoint);
    });

    test('zoomAt keeps focal point stationary in world space', () {
      const camera = CanvasCamera(pan: Offset(20, 20), zoom: 1.0);
      const focalScreenPoint = Offset(200, 150);

      // 1. World point under focal point before zoom
      final worldFocalBefore = camera.screenToWorld(focalScreenPoint);

      // 2. Zoom in to 1.5x at focalScreenPoint
      final zoomedCamera = camera.zoomAt(focalScreenPoint, 1.5);
      expect(zoomedCamera.zoom, 1.5);

      // 3. World point under same screen focal point after zoom MUST match exactly
      final worldFocalAfter = zoomedCamera.screenToWorld(focalScreenPoint);
      expect(worldFocalAfter.dx, closeTo(worldFocalBefore.dx, 0.001));
      expect(worldFocalAfter.dy, closeTo(worldFocalBefore.dy, 0.001));
    });

    test('fitBounds frames bounds inside viewport', () {
      const camera = CanvasCamera();
      const worldBounds = Rect.fromLTWH(0, 0, 1000, 800);
      const viewportSize = Size(800, 600);

      final fitted = camera.fitBounds(worldBounds, viewportSize, padding: 50);
      expect(fitted.zoom, lessThan(1.0));
      expect(fitted.zoom, greaterThanOrEqualTo(0.15));

      // Center of world bounds should project close to center of viewport
      final screenCenter = fitted.worldToScreen(worldBounds.center);
      expect(screenCenter.dx, closeTo(viewportSize.width / 2, 0.1));
      expect(screenCenter.dy, closeTo(viewportSize.height / 2, 0.1));
    });
  });
}
