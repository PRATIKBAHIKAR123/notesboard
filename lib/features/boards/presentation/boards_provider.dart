import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/id_generator.dart';
import '../../canvas/data/canvas_repository.dart';
import '../data/board_repository.dart';
import '../domain/board.dart';

/// Provider for watching all boards in the database (with auto demo seed on first load)
final boardsListProvider = StreamProvider<List<Board>>((ref) async* {
  final canvasRepo = ref.watch(canvasRepositoryProvider);
  await canvasRepo.seedDemoDataIfEmpty();

  final boardRepo = ref.watch(boardRepositoryProvider);
  yield* boardRepo.watchBoards();
});

/// FutureProvider for getting object count of a specific board
final boardObjectCountProvider = FutureProvider.family<int, String>((ref, boardId) async {
  final boardRepo = ref.watch(boardRepositoryProvider);
  return boardRepo.getBoardObjectCount(boardId);
});

/// Controller for board CRUD operations
class BoardsController extends StateNotifier<AsyncValue<void>> {
  final BoardRepository _boardRepo;

  BoardsController(this._boardRepo) : super(const AsyncValue.data(null));

  Future<Board?> createBoard({required String name, String? description}) async {
    state = const AsyncValue.loading();
    try {
      final now = DateTime.now();
      final board = Board(
        id: IdGenerator.generate(),
        name: name.trim().isEmpty ? 'Untitled Board' : name.trim(),
        description: description?.trim().isEmpty == true ? null : description?.trim(),
        createdAt: now,
        updatedAt: now,
      );
      await _boardRepo.createBoard(board);
      state = const AsyncValue.data(null);
      return board;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return null;
    }
  }

  Future<bool> renameBoard({required String id, required String newName}) async {
    try {
      final existing = await _boardRepo.getBoardById(id);
      if (existing == null) return false;

      final updated = existing.copyWith(
        name: newName.trim().isEmpty ? existing.name : newName.trim(),
        updatedAt: DateTime.now(),
      );
      await _boardRepo.updateBoard(updated);
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteBoard(String id) async {
    try {
      await _boardRepo.deleteBoard(id);
      return true;
    } catch (e) {
      return false;
    }
  }
}

final boardsControllerProvider =
    StateNotifierProvider<BoardsController, AsyncValue<void>>((ref) {
  final repo = ref.watch(boardRepositoryProvider);
  return BoardsController(repo);
});
