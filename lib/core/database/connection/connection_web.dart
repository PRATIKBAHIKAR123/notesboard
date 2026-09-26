import 'package:drift/drift.dart';
import 'package:drift/web.dart';

DatabaseConnection connect() {
  return DatabaseConnection(
    WebDatabase.withStorage(
      DriftWebStorage.indexedDb('notesboard_db'),
    ),
  );
}
