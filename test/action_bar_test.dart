import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesboard/features/canvas/engine/canvas_controller.dart';
import 'package:notesboard/features/canvas/presentation/board_canvas.dart';
import 'package:notesboard/features/canvas/presentation/selection_overlay.dart';

void main() {
  testWidgets('Selecting note shows action bar and clicking Edit opens dialog', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    const testBoardId = 'test-board-123';

    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: BoardCanvas(
            boardId: testBoardId,
            boardName: 'Test Board',
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Access the controller and add a test note
    final element = tester.element(find.byType(BoardCanvas));
    final container = ProviderScope.containerOf(element);
    final controller = container.read(canvasControllerProvider(testBoardId).notifier);

    controller.createNote(
      title: 'Sample Card',
      content: 'Sample Content',
      viewportSize: const Size(1200, 800),
    );

    await tester.pumpAndSettle();

    // Verify Sample Card is rendered
    expect(find.text('Sample Card'), findsOneWidget);

    // Tap on the card to select it
    await tester.tap(find.text('Sample Card'));
    await tester.pumpAndSettle();

    // Verify selection: Action bar icons should be visible
    final editIcon = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.edit_outlined),
    );
    final copyIcon = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.copy_rounded),
    );
    final deleteIcon = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.delete_outline_rounded),
    );

    expect(editIcon, findsOneWidget);
    expect(copyIcon, findsOneWidget);
    expect(deleteIcon, findsOneWidget);

    // Tap the Edit button
    await tester.tap(editIcon);
    await tester.pumpAndSettle();

    // Verify Edit Note dialog opens
    expect(find.text('Edit Note'), findsOneWidget);

    // Cancel the dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Re-verify Sample Card is selected
    final copyIconAfter = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.copy_rounded),
    );
    expect(copyIconAfter, findsOneWidget);

    // Tap Duplicate button
    await tester.tap(copyIconAfter);
    await tester.pumpAndSettle();

    // There should now be two notes with "Sample Card" or "(Copy)"
    expect(find.textContaining('Sample Card'), findsNWidgets(2));

    // Tap Delete button on the newly duplicated note
    final deleteIconAfter = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.delete_outline_rounded),
    );
    await tester.tap(deleteIconAfter);
    await tester.pumpAndSettle();

    // Now only one note remains
    expect(find.textContaining('Sample Card'), findsOneWidget);

    // Re-select remaining card
    await tester.tap(find.text('Sample Card'));
    await tester.pump(const Duration(milliseconds: 350));
    await tester.pumpAndSettle();

    // Tap Connect button
    final connectIcon = find.descendant(
      of: find.byType(CanvasActionBar),
      matching: find.byIcon(Icons.alt_route_rounded),
    );
    await tester.tap(connectIcon);
    await tester.pumpAndSettle();

    // Verify canvas is now in connecting mode
    final stateAfterConnect = container.read(canvasControllerProvider(testBoardId));
    expect(stateAfterConnect.isConnecting, isTrue);
  });
}
