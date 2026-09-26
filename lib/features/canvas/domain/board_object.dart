import 'package:flutter/material.dart';

enum BoardObjectType {
  note,
  image,
  group,
}

/// Base abstract class for any visual object positioned on the infinite canvas.
sealed class BoardObject {
  final String id;
  final String boardId;
  final double x;
  final double y;
  final double width;
  final double height;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? parentId; // Logical hierarchy (does NOT control visual position)

  const BoardObject({
    required this.id,
    required this.boardId,
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.createdAt,
    required this.updatedAt,
    this.parentId,
  });

  BoardObjectType get type;

  Rect get rect => Rect.fromLTWH(x, y, width, height);
  Offset get position => Offset(x, y);
  Offset get center => Offset(x + width / 2, y + height / 2);

  BoardObject copyWithPosition({required double x, required double y, DateTime? updatedAt});
  BoardObject copyWithSize({required double width, required double height, DateTime? updatedAt});
  BoardObject copyWithParentId(String? parentId, {DateTime? updatedAt});

  Map<String, dynamic> toJson();
}

/// Note Object on the canvas
class NoteObject extends BoardObject {
  final String title;
  final String content;
  final int colorIndex; // 0 = default white, 1 = yellow, 2 = blue, 3 = green, 4 = purple, 5 = rose

  const NoteObject({
    required super.id,
    required super.boardId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.createdAt,
    required super.updatedAt,
    super.parentId,
    required this.title,
    required this.content,
    this.colorIndex = 0,
  });

  @override
  BoardObjectType get type => BoardObjectType.note;

  NoteObject copyWith({
    String? id,
    String? boardId,
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentId,
    bool clearParentId = false,
    String? title,
    String? content,
    int? colorIndex,
  }) {
    return NoteObject(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      title: title ?? this.title,
      content: content ?? this.content,
      colorIndex: colorIndex ?? this.colorIndex,
    );
  }

  @override
  NoteObject copyWithPosition({required double x, required double y, DateTime? updatedAt}) {
    return copyWith(x: x, y: y, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  NoteObject copyWithSize({required double width, required double height, DateTime? updatedAt}) {
    return copyWith(width: width, height: height, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  NoteObject copyWithParentId(String? parentId, {DateTime? updatedAt}) {
    return copyWith(
      parentId: parentId,
      clearParentId: parentId == null,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'type': 'note',
      'title': title,
      'content': content,
      'colorIndex': colorIndex,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'parentId': parentId,
    };
  }

  factory NoteObject.fromJson(Map<String, dynamic> json) {
    return NoteObject(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      colorIndex: json['colorIndex'] as int? ?? 0,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      parentId: json['parentId'] as String?,
    );
  }
}

/// Image Object on the canvas
class ImageObject extends BoardObject {
  final String imageUrl; // Network URL, asset identifier, or local file path
  final String? caption;

  const ImageObject({
    required super.id,
    required super.boardId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.createdAt,
    required super.updatedAt,
    super.parentId,
    required this.imageUrl,
    this.caption,
  });

  @override
  BoardObjectType get type => BoardObjectType.image;

  ImageObject copyWith({
    String? id,
    String? boardId,
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? parentId,
    bool clearParentId = false,
    String? imageUrl,
    String? caption,
  }) {
    return ImageObject(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      parentId: clearParentId ? null : (parentId ?? this.parentId),
      imageUrl: imageUrl ?? this.imageUrl,
      caption: caption ?? this.caption,
    );
  }

  @override
  ImageObject copyWithPosition({required double x, required double y, DateTime? updatedAt}) {
    return copyWith(x: x, y: y, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  ImageObject copyWithSize({required double width, required double height, DateTime? updatedAt}) {
    return copyWith(width: width, height: height, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  ImageObject copyWithParentId(String? parentId, {DateTime? updatedAt}) {
    return copyWith(
      parentId: parentId,
      clearParentId: parentId == null,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'type': 'image',
      'imageUrl': imageUrl,
      'caption': caption,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'parentId': parentId,
    };
  }

  factory ImageObject.fromJson(Map<String, dynamic> json) {
    return ImageObject(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      imageUrl: json['imageUrl'] as String,
      caption: json['caption'] as String?,
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
      parentId: json['parentId'] as String?,
    );
  }
}

/// Group Object on the canvas
class GroupObject extends BoardObject {
  final String title;

  const GroupObject({
    required super.id,
    required super.boardId,
    required super.x,
    required super.y,
    required super.width,
    required super.height,
    required super.createdAt,
    required super.updatedAt,
    required this.title,
  }) : super(parentId: null);

  @override
  BoardObjectType get type => BoardObjectType.group;

  GroupObject copyWith({
    String? id,
    String? boardId,
    double? x,
    double? y,
    double? width,
    double? height,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? title,
  }) {
    return GroupObject(
      id: id ?? this.id,
      boardId: boardId ?? this.boardId,
      x: x ?? this.x,
      y: y ?? this.y,
      width: width ?? this.width,
      height: height ?? this.height,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      title: title ?? this.title,
    );
  }

  @override
  GroupObject copyWithPosition({required double x, required double y, DateTime? updatedAt}) {
    return copyWith(x: x, y: y, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  GroupObject copyWithSize({required double width, required double height, DateTime? updatedAt}) {
    return copyWith(width: width, height: height, updatedAt: updatedAt ?? DateTime.now());
  }

  @override
  GroupObject copyWithParentId(String? parentId, {DateTime? updatedAt}) {
    return this; // Groups do not have parentId
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'boardId': boardId,
      'type': 'group',
      'title': title,
      'x': x,
      'y': y,
      'width': width,
      'height': height,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory GroupObject.fromJson(Map<String, dynamic> json) {
    return GroupObject(
      id: json['id'] as String,
      boardId: json['boardId'] as String,
      title: json['title'] as String? ?? 'Group',
      x: (json['x'] as num).toDouble(),
      y: (json['y'] as num).toDouble(),
      width: (json['width'] as num).toDouble(),
      height: (json['height'] as num).toDouble(),
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: DateTime.parse(json['updatedAt'] as String),
    );
  }
}
