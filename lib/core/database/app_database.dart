import 'package:drift/drift.dart';
import 'connection/connection.dart' as impl;
import 'tables.dart';

part 'app_database.g.dart';

@DriftDatabase(tables: [
  BoardsTable,
  NotesTable,
  ImagesTable,
  GroupsTable,
  ConnectionsTable,
])
class AppDatabase extends _$AppDatabase {
  AppDatabase() : super(impl.connect());
  AppDatabase.forTesting(super.connection);

  @override
  int get schemaVersion => 1;
}
