import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_text_styles.dart';
import '../domain/search_result.dart';
import 'search_provider.dart';

class SearchScreen extends ConsumerWidget {
  const SearchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final query = ref.watch(searchQueryProvider);
    final resultsAsync = ref.watch(searchResultsProvider);

    return Scaffold(
      backgroundColor: AppColors.canvasBackground,
      appBar: AppBar(
        title: const Text('Search'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            ref.read(searchQueryProvider.notifier).state = '';
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/boards');
            }
          },
        ),
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                children: [
                  // Search Input
                  TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                      hintText: 'Search board names, note titles, or content...',
                      prefixIcon: const Icon(Icons.search_rounded, size: 22),
                      suffixIcon: query.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear, size: 18),
                              onPressed: () =>
                                  ref.read(searchQueryProvider.notifier).state = '',
                            )
                          : null,
                    ),
                    onChanged: (val) =>
                        ref.read(searchQueryProvider.notifier).state = val,
                  ),
                  const SizedBox(height: 20),

                  // Results List
                  Expanded(
                    child: query.trim().isEmpty
                        ? _buildInitialState()
                        : resultsAsync.when(
                            data: (results) {
                              if (results.isEmpty) {
                                return _buildNoResultsState(query);
                              }
                              return ListView.separated(
                                itemCount: results.length,
                                separatorBuilder: (_, __) => const SizedBox(height: 8),
                                itemBuilder: (context, index) {
                                  final item = results[index];
                                  return _buildResultTile(context, item);
                                },
                              );
                            },
                            loading: () =>
                                const Center(child: CircularProgressIndicator()),
                            error: (e, _) => Center(child: Text('Search error: $e')),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildResultTile(BuildContext context, SearchResult item) {
    final isBoard = item.type == SearchResultType.board;

    return ListTile(
      tileColor: AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppColors.border),
      ),
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isBoard ? AppColors.primaryMuted : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          isBoard ? Icons.dashboard_outlined : Icons.sticky_note_2_outlined,
          color: isBoard ? AppColors.primary : AppColors.textSecondary,
          size: 20,
        ),
      ),
      title: Text(item.title, style: AppTextStyles.titleMedium),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(
            item.snippet,
            style: AppTextStyles.bodySmall,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(Icons.folder_outlined, size: 12, color: AppColors.textMuted),
              const SizedBox(width: 4),
              Text(
                item.boardName,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
      onTap: () {
        context.go(
          '/boards/${item.boardId}?name=${Uri.encodeComponent(item.boardName)}',
        );
      },
    );
  }

  Widget _buildInitialState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_rounded, size: 48, color: AppColors.textMuted),
          SizedBox(height: 12),
          Text('Search Notesboard', style: AppTextStyles.titleLarge),
          SizedBox(height: 4),
          Text(
            'Type above to search through your boards and note contents.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState(String query) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.search_off_rounded, size: 48, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text('No results found for "$query"', style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          const Text(
            'Check for typos or try a different search phrase.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}
