import 'package:drift/drift.dart';

class BoardsTable extends Table {
  TextColumn get id => text()();
  TextColumn get name => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get thumbnail => text().nullable()();
  TextColumn get description => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class NotesTable extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get title => text()();
  TextColumn get content => text()();
  IntColumn get colorIndex => integer().withDefault(const Constant(0))();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class ImagesTable extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get imageUrl => text()();
  TextColumn get caption => text().nullable()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  TextColumn get parentId => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

class GroupsTable extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get title => text()();
  RealColumn get x => real()();
  RealColumn get y => real()();
  RealColumn get width => real()();
  RealColumn get height => real()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}

class ConnectionsTable extends Table {
  TextColumn get id => text()();
  TextColumn get boardId => text()();
  TextColumn get fromObjectId => text()();
  TextColumn get toObjectId => text()();
  TextColumn get type => text().withDefault(const Constant('arrow'))();
  TextColumn get label => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column> get primaryKey => {id};
}
