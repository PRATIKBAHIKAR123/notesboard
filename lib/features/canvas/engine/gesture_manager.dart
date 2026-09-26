import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../core/constants/app_constants.dart';
import '../domain/board_object.dart';

enum CanvasGestureMode {
  none,
  panning,
  movingObject,
  resizingObject,
}

enum ResizeHandle {
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// Helper class to compute new object geometries during dragging and resizing.
class GestureManager {
  GestureManager._();

  /// Computes the new Rect for an object when resizing via [handle] given a world delta.
  static Rect computeResizedRect({
    required Rect initialRect,
    required ResizeHandle handle,
    required Offset worldDelta,
    required BoardObjectType type,
  }) {
    double minW;
    double minH;

    switch (type) {
      case BoardObjectType.note:
        minW = AppConstants.minNoteWidth;
        minH = AppConstants.minNoteHeight;
        break;
      case BoardObjectType.image:
        minW = AppConstants.minImageWidth;
        minH = AppConstants.minImageHeight;
        break;
      case BoardObjectType.group:
        minW = AppConstants.minGroupWidth;
        minH = AppConstants.minGroupHeight;
        break;
    }

    double left = initialRect.left;
    double top = initialRect.top;
    double right = initialRect.right;
    double bottom = initialRect.bottom;

    switch (handle) {
      case ResizeHandle.bottomRight:
        right = math.max(left + minW, initialRect.right + worldDelta.dx);
        bottom = math.max(top + minH, initialRect.bottom + worldDelta.dy);
        break;

      case ResizeHandle.bottomLeft:
        left = math.min(right - minW, initialRect.left + worldDelta.dx);
        bottom = math.max(top + minH, initialRect.bottom + worldDelta.dy);
        break;

      case ResizeHandle.topRight:
        right = math.max(left + minW, initialRect.right + worldDelta.dx);
        top = math.min(bottom - minH, initialRect.top + worldDelta.dy);
        break;

      case ResizeHandle.topLeft:
        left = math.min(right - minW, initialRect.left + worldDelta.dx);
        top = math.min(bottom - minH, initialRect.top + worldDelta.dy);
        break;
    }

    return Rect.fromLTRB(left, top, right, bottom);
  }
}
