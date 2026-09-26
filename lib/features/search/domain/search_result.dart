enum SearchResultType { board, note }

class SearchResult {
  final String boardId;
  final String boardName;
  final String? objectId;
  final SearchResultType type;
  final String title;
  final String snippet;

  const SearchResult({
    required this.boardId,
    required this.boardName,
    this.objectId,
    required this.type,
    required this.title,
    required this.snippet,
  });
}
