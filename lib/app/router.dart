import 'package:go_router/go_router.dart';
import '../features/boards/presentation/boards_screen.dart';
import '../features/canvas/presentation/board_canvas.dart';
import '../features/search/presentation/search_screen.dart';
import '../features/settings/presentation/settings_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/boards',
  routes: [
    GoRoute(
      path: '/boards',
      builder: (context, state) => const BoardsScreen(),
      routes: [
        GoRoute(
          path: ':boardId',
          builder: (context, state) {
            final boardId = state.pathParameters['boardId']!;
            final boardName = state.uri.queryParameters['name'] ?? 'Board';
            return BoardCanvas(
              boardId: boardId,
              boardName: boardName,
            );
          },
        ),
      ],
    ),
    GoRoute(
      path: '/search',
      builder: (context, state) => const SearchScreen(),
    ),
    GoRoute(
      path: '/settings',
      builder: (context, state) => const SettingsScreen(),
    ),
  ],
);
