import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:notesboard/app/app.dart';

void main() {
  testWidgets('Notesboard app smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: NotesboardApp(),
      ),
    );

    // Initial pump
    await tester.pump();

    // Verify Notesboard title renders
    expect(find.text('Notesboard'), findsWidgets);
  });
}
