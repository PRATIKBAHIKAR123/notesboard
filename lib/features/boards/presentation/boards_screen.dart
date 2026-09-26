import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../../../core/utils/responsive.dart';
import '../domain/board.dart';
import 'boards_provider.dart';
import 'create_board_dialog.dart';
import 'export_import_dialogs.dart';
import 'widgets/board_card.dart';

class BoardsScreen extends ConsumerWidget {
  const BoardsScreen({super.key});

  Future<void> _handleCreateBoard(BuildContext context, WidgetRef ref) async {
    final result = await CreateBoardDialog.show(context);
    if (result == null) return;

    final controller = ref.read(boardsControllerProvider.notifier);
    final board = await controller.createBoard(
      name: result.name,
      description: result.description,
    );

    if (board != null && context.mounted) {
      context.go('/boards/${board.id}?name=${Uri.encodeComponent(board.name)}');
    }
  }

  Future<void> _handleRenameBoard(
    BuildContext context,
    WidgetRef ref,
    Board board,
  ) async {
    final result = await CreateBoardDialog.show(
      context,
      initialName: board.name,
      initialDescription: board.description,
      titleText: 'Rename Board',
      confirmText: 'Save',
    );
    if (result == null) return;

    final controller = ref.read(boardsControllerProvider.notifier);
    await controller.renameBoard(id: board.id, newName: result.name);
  }

  Future<void> _handleDeleteBoard(
    BuildContext context,
    WidgetRef ref,
    Board board,
  ) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Board?'),
        content: Text('Are you sure you want to delete "${board.name}"? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final controller = ref.read(boardsControllerProvider.notifier);
      await controller.deleteBoard(board.id);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final boardsAsync = ref.watch(boardsListProvider);
    final isMobile = ResponsiveLayout.isMobile(context);

    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: isMobile
          ? AppBar(
              title: const Row(
                children: [
                  Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 22),
                  SizedBox(width: 8),
                  Text('Notesboard', style: AppTextStyles.titleLarge),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.file_open_outlined),
                  tooltip: 'Import Board Backup',
                  onPressed: () => ImportBoardDialog.show(context, ref),
                ),
                IconButton(
                  icon: const Icon(Icons.search_rounded),
                  tooltip: 'Search',
                  onPressed: () => context.go('/search'),
                ),
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Settings',
                  onPressed: () => context.go('/settings'),
                ),
              ],
            )
          : null,
      floatingActionButton: isMobile
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              onPressed: () => _handleCreateBoard(context, ref),
              child: const Icon(Icons.add),
            )
          : null,
      body: SafeArea(
        child: ResponsiveLayout(
          mobile: _buildMobileContent(context, ref, boardsAsync),
          desktop: _buildDesktopContent(context, ref, boardsAsync),
        ),
      ),
    );
  }

  Widget _buildDesktopContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Board>> boardsAsync,
  ) {
    return Column(
      children: [
        // Top Global Bar
        Container(
          height: 64,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: const BoxDecoration(
            color: AppColors.surface,
            border: Border(bottom: BorderSide(color: AppColors.border, width: 1)),
          ),
          child: Row(
            children: [
              const Icon(Icons.dashboard_rounded, color: AppColors.primary, size: 26),
              const SizedBox(width: 10),
              const Text('Notesboard', style: AppTextStyles.displayMedium),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: () => context.go('/search'),
                icon: const Icon(Icons.search, size: 16),
                label: const Text('Search'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                icon: const Icon(Icons.settings_outlined, size: 20),
                tooltip: 'Settings',
                onPressed: () => context.go('/settings'),
              ),
            ],
          ),
        ),

        // Main Area with Left Sidebar and Board Grid
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Sidebar
              Container(
                width: 240,
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(right: BorderSide(color: AppColors.border, width: 1)),
                ),
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () => _handleCreateBoard(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('New Board'),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () => ImportBoardDialog.show(context, ref),
                      icon: const Icon(Icons.file_open_outlined, size: 16),
                      label: const Text('Import Board'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text('BOARDS', style: AppTextStyles.labelMedium),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppColors.primaryMuted,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.folder_outlined,
                              size: 18, color: AppColors.primary),
                          const SizedBox(width: 10),
                          Text(
                            'All Boards',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontSize: 13,
                              color: AppColors.primaryDark,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Board Cards Content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          boardsAsync.when(
                            data: (boards) => Text(
                              'My Boards (${boards.length})',
                              style: AppTextStyles.displayMedium,
                            ),
                            loading: () => const Text('My Boards', style: AppTextStyles.displayMedium),
                            error: (_, __) => const Text('My Boards', style: AppTextStyles.displayMedium),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Expanded(
                        child: boardsAsync.when(
                          data: (boards) {
                            if (boards.isEmpty) {
                              return _buildEmptyBoardsState(context, ref);
                            }
                            return LayoutBuilder(
                              builder: (context, constraints) {
                                final crossAxisCount = constraints.maxWidth > 1100
                                    ? 4
                                    : (constraints.maxWidth > 800 ? 3 : 2);
                                return GridView.builder(
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisSpacing: 20,
                                    crossAxisSpacing: 20,
                                    childAspectRatio: 1.35,
                                  ),
                                  itemCount: boards.length,
                                  itemBuilder: (context, index) {
                                    final board = boards[index];
                                    return BoardCard(
                                      board: board,
                                      onTap: () => context.go(
                                        '/boards/${board.id}?name=${Uri.encodeComponent(board.name)}',
                                      ),
                                      onRename: () => _handleRenameBoard(context, ref, board),
                                      onDelete: () => _handleDeleteBoard(context, ref, board),
                                      onExport: () => ExportBoardDialog.show(context, ref, board),
                                    );
                                  },
                                );
                              },
                            );
                          },
                          loading: () => const Center(child: CircularProgressIndicator()),
                          error: (e, _) => Center(child: Text('Error loading boards: $e')),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMobileContent(
    BuildContext context,
    WidgetRef ref,
    AsyncValue<List<Board>> boardsAsync,
  ) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          boardsAsync.when(
            data: (boards) => Text(
              'My Boards (${boards.length})',
              style: AppTextStyles.displayMedium.copyWith(fontSize: 20),
            ),
            loading: () => const Text('My Boards', style: AppTextStyles.displayMedium),
            error: (_, __) => const Text('My Boards', style: AppTextStyles.displayMedium),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: boardsAsync.when(
              data: (boards) {
                if (boards.isEmpty) {
                  return _buildEmptyBoardsState(context, ref);
                }
                return ListView.separated(
                  itemCount: boards.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final board = boards[index];
                    return SizedBox(
                      height: 140,
                      child: BoardCard(
                        board: board,
                        onTap: () => context.go(
                          '/boards/${board.id}?name=${Uri.encodeComponent(board.name)}',
                        ),
                        onRename: () => _handleRenameBoard(context, ref, board),
                        onDelete: () => _handleDeleteBoard(context, ref, board),
                        onExport: () => ExportBoardDialog.show(context, ref, board),
                      ),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyBoardsState(BuildContext context, WidgetRef ref) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.dashboard_customize_outlined,
                size: 48, color: AppColors.primary),
            const SizedBox(height: 16),
            const Text('No boards created yet', style: AppTextStyles.titleLarge),
            const SizedBox(height: 6),
            const Text(
              'Create your first board to start taking visual notes and connecting ideas.',
              style: AppTextStyles.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () => _handleCreateBoard(context, ref),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Create New Board'),
            ),
          ],
        ),
      ),
    );
  }
}
