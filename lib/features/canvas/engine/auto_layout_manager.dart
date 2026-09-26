import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../domain/board_connection.dart';
import '../domain/board_object.dart';

/// Result of calculating a group's internal layout
class GroupLayoutResult {
  final Map<String, Offset> positions;
  final GroupObject updatedGroup;

  const GroupLayoutResult({
    required this.positions,
    required this.updatedGroup,
  });
}

/// Calculates clean hierarchical tree and mind-map layouts for visual notes.
class AutoLayoutManager {
  /// Computes updated world positions for all objects to organize them into a clean map.
  static Map<String, Offset> computeLayout({
    required Map<String, BoardObject> objects,
    required List<BoardConnection> connections,
    double horizontalSpacing = 120.0,
    double verticalSpacing = 50.0,
    double startX = 60.0,
    double startY = 60.0,
  }) {
    if (objects.isEmpty) return {};

    // 1. Build adjacency list of children: parentId -> [childId]
    final childrenMap = <String, List<String>>{};
    final incomingCount = <String, int>{};

    for (final id in objects.keys) {
      childrenMap[id] = [];
      incomingCount[id] = 0;
    }

    // Add edges from connections
    for (final conn in connections) {
      if (objects.containsKey(conn.fromObjectId) && objects.containsKey(conn.toObjectId)) {
        if (conn.fromObjectId != conn.toObjectId) {
          childrenMap[conn.fromObjectId]?.add(conn.toObjectId);
          incomingCount[conn.toObjectId] = (incomingCount[conn.toObjectId] ?? 0) + 1;
        }
      }
    }

    // Add edges from logical parentId
    for (final obj in objects.values) {
      if (obj.parentId != null && objects.containsKey(obj.parentId)) {
        if (!childrenMap[obj.parentId!]!.contains(obj.id)) {
          childrenMap[obj.parentId!]?.add(obj.id);
          incomingCount[obj.id] = (incomingCount[obj.id] ?? 0) + 1;
        }
      }
    }

    // 2. Identify root nodes (nodes with 0 incoming connections)
    final rootIds = objects.keys.where((id) => (incomingCount[id] ?? 0) == 0).toList();

    // If all nodes have incoming (cycle), pick the first one as root
    if (rootIds.isEmpty && objects.isNotEmpty) {
      rootIds.add(objects.keys.first);
    }

    final newPositions = <String, Offset>{};
    final visited = <String>{};

    double currentTreeY = startY;
    final treeStartX = startX;

    // 3. Layout each tree/connected component
    for (final rootId in rootIds) {
      if (visited.contains(rootId)) continue;

      final rootObj = objects[rootId]!;
      // Calculate subtree required heights
      final subtreeHeights = <String, double>{};
      _measureSubtree(
        nodeId: rootId,
        objects: objects,
        childrenMap: childrenMap,
        subtreeHeights: subtreeHeights,
        visited: {},
        verticalSpacing: verticalSpacing,
      );

      // Position subtree nodes recursively
      _positionSubtree(
        nodeId: rootId,
        x: treeStartX,
        y: currentTreeY,
        objects: objects,
        childrenMap: childrenMap,
        subtreeHeights: subtreeHeights,
        newPositions: newPositions,
        visited: visited,
        horizontalSpacing: horizontalSpacing,
        verticalSpacing: verticalSpacing,
      );

      final rootHeight = subtreeHeights[rootId] ?? (rootObj.height + verticalSpacing);
      currentTreeY += rootHeight + 50.0; // Spacing between distinct trees
    }

    // 4. Any leftover unconnected objects are placed in a clean, aligned grid alongside
    final unplaced = objects.keys.where((id) => !newPositions.containsKey(id)).toList();
    if (unplaced.isNotEmpty) {
      final unplacedObjects = {for (final id in unplaced) id: objects[id]!};
      final gridPositions = computeGridLayout(
        objects: unplacedObjects,
        columns: 3,
        spacingX: 110.0,
        spacingY: 88.0,
        startX: treeStartX,
        startY: currentTreeY + 20.0,
      );
      newPositions.addAll(gridPositions);
    }

    return newPositions;
  }

  /// Computes top-down vertical tree hierarchy layout
  static Map<String, Offset> computeVerticalLayout({
    required Map<String, BoardObject> objects,
    required List<BoardConnection> connections,
    double horizontalSpacing = 70.0,
    double verticalSpacing = 100.0,
    double startX = 60.0,
    double startY = 60.0,
  }) {
    if (objects.isEmpty) return {};

    final childrenMap = <String, List<String>>{};
    final incomingCount = <String, int>{};

    for (final id in objects.keys) {
      childrenMap[id] = [];
      incomingCount[id] = 0;
    }

    for (final conn in connections) {
      if (objects.containsKey(conn.fromObjectId) && objects.containsKey(conn.toObjectId)) {
        if (conn.fromObjectId != conn.toObjectId) {
          childrenMap[conn.fromObjectId]?.add(conn.toObjectId);
          incomingCount[conn.toObjectId] = (incomingCount[conn.toObjectId] ?? 0) + 1;
        }
      }
    }

    for (final obj in objects.values) {
      if (obj.parentId != null && objects.containsKey(obj.parentId)) {
        if (!childrenMap[obj.parentId!]!.contains(obj.id)) {
          childrenMap[obj.parentId!]?.add(obj.id);
          incomingCount[obj.id] = (incomingCount[obj.id] ?? 0) + 1;
        }
      }
    }

    final rootIds = objects.keys.where((id) => (incomingCount[id] ?? 0) == 0).toList();
    if (rootIds.isEmpty && objects.isNotEmpty) {
      rootIds.add(objects.keys.first);
    }

    final newPositions = <String, Offset>{};
    final visited = <String>{};

    double currentTreeX = startX;
    final treeStartY = startY;

    for (final rootId in rootIds) {
      if (visited.contains(rootId)) continue;

      final rootObj = objects[rootId]!;
      final subtreeWidths = <String, double>{};
      _measureSubtreeWidth(
        nodeId: rootId,
        objects: objects,
        childrenMap: childrenMap,
        subtreeWidths: subtreeWidths,
        visited: {},
        horizontalSpacing: horizontalSpacing,
      );

      _positionSubtreeVertical(
        nodeId: rootId,
        x: currentTreeX,
        y: treeStartY,
        objects: objects,
        childrenMap: childrenMap,
        subtreeWidths: subtreeWidths,
        newPositions: newPositions,
        visited: visited,
        horizontalSpacing: horizontalSpacing,
        verticalSpacing: verticalSpacing,
      );

      final rootWidth = subtreeWidths[rootId] ?? (rootObj.width + horizontalSpacing);
      currentTreeX += rootWidth + 60.0;
    }

    // Place any remaining unplaced objects in a clean grid below
    final unplaced = objects.keys.where((id) => !newPositions.containsKey(id)).toList();
    if (unplaced.isNotEmpty) {
      double maxY = 0;
      for (final entry in newPositions.entries) {
        final obj = objects[entry.key];
        final bottom = entry.value.dy + (obj?.height ?? 140.0);
        if (bottom > maxY) maxY = bottom;
      }
      final unplacedObjects = {for (final id in unplaced) id: objects[id]!};
      final gridPositions = computeGridLayout(
        objects: unplacedObjects,
        columns: 3,
        spacingX: 110.0,
        spacingY: 88.0,
        startX: 60.0,
        startY: maxY + 60.0,
      );
      newPositions.addAll(gridPositions);
    }

    return newPositions;
  }

  static double _measureSubtreeWidth({
    required String nodeId,
    required Map<String, BoardObject> objects,
    required Map<String, List<String>> childrenMap,
    required Map<String, double> subtreeWidths,
    required Set<String> visited,
    required double horizontalSpacing,
  }) {
    visited.add(nodeId);
    final obj = objects[nodeId];
    if (obj == null) return 0;

    final children = (childrenMap[nodeId] ?? [])
        .where((c) => !visited.contains(c))
        .toList();

    if (children.isEmpty) {
      final w = obj.width + horizontalSpacing;
      subtreeWidths[nodeId] = w;
      return w;
    }

    double totalChildWidth = 0;
    for (final childId in children) {
      totalChildWidth += _measureSubtreeWidth(
        nodeId: childId,
        objects: objects,
        childrenMap: childrenMap,
        subtreeWidths: subtreeWidths,
        visited: visited,
        horizontalSpacing: horizontalSpacing,
      );
    }

    final w = math.max(obj.width + horizontalSpacing, totalChildWidth);
    subtreeWidths[nodeId] = w;
    return w;
  }

  static void _positionSubtreeVertical({
    required String nodeId,
    required double x,
    required double y,
    required Map<String, BoardObject> objects,
    required Map<String, List<String>> childrenMap,
    required Map<String, double> subtreeWidths,
    required Map<String, Offset> newPositions,
    required Set<String> visited,
    required double horizontalSpacing,
    required double verticalSpacing,
  }) {
    visited.add(nodeId);
    final obj = objects[nodeId];
    if (obj == null) return;

    final nodeSubtreeWidth = subtreeWidths[nodeId] ?? (obj.width + horizontalSpacing);
    final nodeX = x + (nodeSubtreeWidth / 2) - (obj.width / 2);
    newPositions[nodeId] = Offset(nodeX, y);

    final children = (childrenMap[nodeId] ?? [])
        .where((c) => !visited.contains(c))
        .toList();

    if (children.isEmpty) return;

    double childX = x;
    final childY = y + obj.height + verticalSpacing;

    for (final childId in children) {
      final childSubtreeWidth = subtreeWidths[childId] ?? 100.0;
      _positionSubtreeVertical(
        nodeId: childId,
        x: childX,
        y: childY,
        objects: objects,
        childrenMap: childrenMap,
        subtreeWidths: subtreeWidths,
        newPositions: newPositions,
        visited: visited,
        horizontalSpacing: horizontalSpacing,
        verticalSpacing: verticalSpacing,
      );
      childX += childSubtreeWidth;
    }
  }

  /// Checks whether an object is geometrically positioned inside a group
  static bool isObjectInGroup(BoardObject obj, GroupObject group) {
    if (obj.id == group.id) return false;
    final groupRect = group.rect;
    if (groupRect.contains(obj.center)) return true;
    if (groupRect.overlaps(obj.rect)) {
      final intersection = groupRect.intersect(obj.rect);
      return (intersection.width * intersection.height) >= (obj.width * obj.height * 0.25);
    }
    return false;
  }

  /// Returns the group that contains or overlaps this object the most, or null
  static GroupObject? findGroupForObject(BoardObject obj, Iterable<GroupObject> groups) {
    if (obj is GroupObject) return null;
    GroupObject? bestGroup;
    double maxOverlapArea = 0;

    for (final grp in groups) {
      if (grp.rect.contains(obj.center)) {
        return grp;
      }
      if (grp.rect.overlaps(obj.rect)) {
        final intersection = grp.rect.intersect(obj.rect);
        final area = intersection.width * intersection.height;
        if (area > maxOverlapArea && area >= (obj.width * obj.height * 0.25)) {
          maxOverlapArea = area;
          bestGroup = grp;
        }
      }
    }
    return bestGroup;
  }

  /// Organizes objects belonging to a specific group neatly inside that group,
  /// with true column-and-row alignment, generous spacing, and automatic bounds expansion.
  static GroupLayoutResult computeGroupLayout({
    required GroupObject group,
    required List<BoardObject> containedObjects,
    int? columns,
    double spacingX = 110.0,
    double spacingY = 88.0,
    double padding = 32.0,
    double headerHeight = 48.0,
  }) {
    if (containedObjects.isEmpty) {
      return GroupLayoutResult(positions: {}, updatedGroup: group);
    }

    final rawList = List<BoardObject>.from(containedObjects);
    // Sort items logically into visual rows (stable row clustering, left to right)
    rawList.sort((a, b) => a.y.compareTo(b.y));
    final rowBuckets = <List<BoardObject>>[];
    for (final item in rawList) {
      if (rowBuckets.isEmpty) {
        rowBuckets.add([item]);
      } else {
        final lastRow = rowBuckets.last;
        final avgY = lastRow.fold<double>(0.0, (sum, o) => sum + o.y) / lastRow.length;
        if ((item.y - avgY).abs() <= 70.0) {
          lastRow.add(item);
        } else {
          rowBuckets.add([item]);
        }
      }
    }
    final list = <BoardObject>[];
    for (final r in rowBuckets) {
      r.sort((a, b) => a.x.compareTo(b.x));
      list.addAll(r);
    }

    final cols = math.max(1, math.min(columns ??
        (list.length <= 2
            ? list.length
            : (list.length <= 4 ? 2 : 3)), list.length));
    final rows = (list.length / cols).ceil();

    final colWidths = List<double>.filled(cols, 0.0);
    final rowHeights = List<double>.filled(rows, 0.0);

    for (int i = 0; i < list.length; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      colWidths[c] = math.max(colWidths[c], list[i].width);
      rowHeights[r] = math.max(rowHeights[r], list[i].height);
    }

    final colX = <double>[];
    double runningX = group.x + padding;
    for (int c = 0; c < cols; c++) {
      colX.add(runningX);
      runningX += colWidths[c] + spacingX;
    }

    final rowY = <double>[];
    double runningY = group.y + headerHeight + padding;
    for (int r = 0; r < rows; r++) {
      rowY.add(runningY);
      runningY += rowHeights[r] + spacingY;
    }

    final positions = <String, Offset>{};
    for (int i = 0; i < list.length; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      positions[list[i].id] = Offset(colX[c], rowY[r]);
    }

    final neededWidth = (runningX - spacingX - group.x) + padding;
    final neededHeight = (runningY - spacingY - group.y) + padding;

    final updatedGroup = group.copyWithSize(
      width: math.max(340.0, neededWidth),
      height: math.max(220.0, neededHeight),
    );

    return GroupLayoutResult(
      positions: positions,
      updatedGroup: updatedGroup,
    );
  }

  /// Organizes objects into a clean, perfectly aligned grid with generous spacing
  static Map<String, Offset> computeGridLayout({
    required Map<String, BoardObject> objects,
    int columns = 3,
    double spacingX = 110.0,
    double spacingY = 88.0,
    double startX = 72.0,
    double startY = 72.0,
  }) {
    if (objects.isEmpty) return {};

    final rawList = objects.values.toList();
    // Sort logically into visual rows (stable row clustering, left to right)
    rawList.sort((a, b) => a.y.compareTo(b.y));
    final rowBuckets = <List<BoardObject>>[];
    for (final item in rawList) {
      if (rowBuckets.isEmpty) {
        rowBuckets.add([item]);
      } else {
        final lastRow = rowBuckets.last;
        final avgY = lastRow.fold<double>(0.0, (sum, o) => sum + o.y) / lastRow.length;
        if ((item.y - avgY).abs() <= 70.0) {
          lastRow.add(item);
        } else {
          rowBuckets.add([item]);
        }
      }
    }
    final list = <BoardObject>[];
    for (final r in rowBuckets) {
      r.sort((a, b) => a.x.compareTo(b.x));
      list.addAll(r);
    }

    final cols = math.max(1, math.min(columns, list.length));
    final rows = (list.length / cols).ceil();

    final colWidths = List<double>.filled(cols, 0.0);
    final rowHeights = List<double>.filled(rows, 0.0);

    for (int i = 0; i < list.length; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      colWidths[c] = math.max(colWidths[c], list[i].width);
      rowHeights[r] = math.max(rowHeights[r], list[i].height);
    }

    final colX = <double>[];
    double runningX = startX;
    for (int c = 0; c < cols; c++) {
      colX.add(runningX);
      runningX += colWidths[c] + spacingX;
    }

    final rowY = <double>[];
    double runningY = startY;
    for (int r = 0; r < rows; r++) {
      rowY.add(runningY);
      runningY += rowHeights[r] + spacingY;
    }

    final positions = <String, Offset>{};
    for (int i = 0; i < list.length; i++) {
      final c = i % cols;
      final r = i ~/ cols;
      positions[list[i].id] = Offset(colX[c], rowY[r]);
    }

    return positions;
  }

  static double _measureSubtree({
    required String nodeId,
    required Map<String, BoardObject> objects,
    required Map<String, List<String>> childrenMap,
    required Map<String, double> subtreeHeights,
    required Set<String> visited,
    required double verticalSpacing,
  }) {
    visited.add(nodeId);
    final obj = objects[nodeId];
    if (obj == null) return 0;

    final children = (childrenMap[nodeId] ?? [])
        .where((c) => !visited.contains(c))
        .toList();

    if (children.isEmpty) {
      final h = obj.height + verticalSpacing;
      subtreeHeights[nodeId] = h;
      return h;
    }

    double totalChildHeight = 0;
    for (final childId in children) {
      totalChildHeight += _measureSubtree(
        nodeId: childId,
        objects: objects,
        childrenMap: childrenMap,
        subtreeHeights: subtreeHeights,
        visited: visited,
        verticalSpacing: verticalSpacing,
      );
    }

    final h = math.max(obj.height + verticalSpacing, totalChildHeight);
    subtreeHeights[nodeId] = h;
    return h;
  }

  static void _positionSubtree({
    required String nodeId,
    required double x,
    required double y,
    required Map<String, BoardObject> objects,
    required Map<String, List<String>> childrenMap,
    required Map<String, double> subtreeHeights,
    required Map<String, Offset> newPositions,
    required Set<String> visited,
    required double horizontalSpacing,
    required double verticalSpacing,
  }) {
    visited.add(nodeId);
    final obj = objects[nodeId];
    if (obj == null) return;

    final nodeSubtreeHeight = subtreeHeights[nodeId] ?? (obj.height + verticalSpacing);
    // Center node vertically within its subtree allocation
    final nodeY = y + (nodeSubtreeHeight / 2) - (obj.height / 2);
    newPositions[nodeId] = Offset(x, nodeY);

    final children = (childrenMap[nodeId] ?? [])
        .where((c) => !visited.contains(c))
        .toList();

    if (children.isEmpty) return;

    double childY = y;
    final childX = x + obj.width + horizontalSpacing;

    for (final childId in children) {
      final childSubtreeHeight = subtreeHeights[childId] ?? 100.0;
      _positionSubtree(
        nodeId: childId,
        x: childX,
        y: childY,
        objects: objects,
        childrenMap: childrenMap,
        subtreeHeights: subtreeHeights,
        newPositions: newPositions,
        visited: visited,
        horizontalSpacing: horizontalSpacing,
        verticalSpacing: verticalSpacing,
      );
      childY += childSubtreeHeight;
    }
  }
}
