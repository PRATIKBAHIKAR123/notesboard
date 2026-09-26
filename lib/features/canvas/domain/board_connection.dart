/// Connection between two visual objects on the canvas
class BoardConnection {
  final String id;
  final String boardId;
  final String fromObjectId;
  final String toObjectId;
  final String type; // e.g. 'arrow', 'line'
  final String? label;
  final DateTime createdAt;

  const BoardConnection({
    required this.id,
    required this.boardId,
    required this.fromObjectId,
    required this.toObjectId,
    this.type = 'arrow',
    this.label,
    required this.createdAt,
  });

  BoardConnection copyWith({
    String? id,
    String? boardId,
    String? fromObjectId,
    String? toObjectId,
    String? type,
    String? label,
    bool clearLabel = false,
    DateTime? createdAt,
  }) {
    return BoardConnection(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      fromObjectId: fromObjectId ?? this.fromObjectId,
      toObjectId: toObjectId ?? this.toObjectId,
      type: type ?? this.type,
      label: clearLabel ? null : (label ?? this.label),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'fromObjectId': fromObjectId,
      'toObjectId': toObjectId,
      'type': type,
      'label': label,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory BoardConnection.fromJson(Map<String, dynamic> json) {
    return BoardConnection(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      fromObjectId: json['fromObjectId'] as String,
      toObjectId: json['toObjectId'] as String,
      type: json['type'] as String? ?? 'arrow',
      label: json['label'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BoardConnection &&
          runtimeType == other.runtimeType &&
          id == other.id &&
          boardId == other.boardId &&
          fromObjectId == other.fromObjectId &&
          toObjectId == other.toObjectId &&
          type == other.type &&
          label == other.label;

  @override
  int get hashCode =>
      id.hashCode ^
      boardId.hashCode ^
      fromObjectId.hashCode ^
      toObjectId.hashCode ^
      type.hashCode ^
      (label?.hashCode ?? 0);
}
