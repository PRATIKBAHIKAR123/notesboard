import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/database/database_provider.dart';
import '../domain/search_result.dart';

final searchQueryProvider = StateProvider<String>((ref) => '');

final searchResultsProvider = FutureProvider<List<SearchResult>>((ref) async {
  final query = ref.watch(searchQueryProvider).trim().toLowerCase();
  if (query.isEmpty) return [];

  final db = ref.watch(appDatabaseProvider);
  final results = <SearchResult>[];

  // 1. Search Boards
  final boards = await db.select(db.boardsTable).get();
  for (final b in boards) {
    if (b.name.toLowerCase().contains(query) ||
        (b.description != null && b.description!.toLowerCase().contains(query))) {
      results.add(
        SearchResult(
          boardId: b.id,
          boardName: b.name,
          type: SearchResultType.board,
          title: b.name,
          snippet: b.description ?? 'Board',
        ),
      );
    }
  }

  // 2. Search Notes
  final notes = await db.select(db.notesTable).get();
  for (final n in notes) {
    if (n.title.toLowerCase().contains(query) ||
        n.content.toLowerCase().contains(query)) {
      // Find parent board name
      final board = boards.firstWhere(
        (b) => b.id == n.boardId,
        orElse: () => boards.first,
      );

      results.add(
        SearchResult(
          boardId: n.boardId,
          boardName: board.name,
          objectId: n.id,
          type: SearchResultType.note,
          title: n.title.isNotEmpty ? n.title : 'Note',
          snippet: n.content.isNotEmpty ? n.content : 'Empty note content',
        ),
      );
    }
  }

  return results;
});
