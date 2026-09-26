import '../domain/board_connection.dart';

/// Helper for connection queries and validation
class ConnectionManager {
  ConnectionManager._();

  /// Validates whether a connection can be established from [fromId] to [toId]
  static bool canConnect({
    required String fromId,
    required String toId,
    required List<BoardConnection> existingConnections,
  }) {
    if (fromId == toId) return false;

    // Check if an identical connection already exists in either direction
    final exists = existingConnections.any(
      (c) =>
          (c.fromObjectId == fromId && c.toObjectId == toId) ||
          (c.fromObjectId == toId && c.toObjectId == fromId),
    );

    return !exists;
  }

  /// Finds all connections attached to a specific object
  static List<BoardConnection> findAttachedConnections(
    String objectId,
    List<BoardConnection> connections,
  ) {
    return connections
        .where((c) => c.fromObjectId == objectId || c.toObjectId == objectId)
        .toList();
  }
}
