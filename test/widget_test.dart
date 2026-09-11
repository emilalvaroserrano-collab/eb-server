import 'package:eburon_hub/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  testWidgets('Eburon Hub renders the mobile shell', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(child: EburonHubApp()),
    );
    await tester.pumpAndSettle();

    expect(find.text('Eburon Hub'), findsWidgets);
    expect(find.text('Chat'), findsWidgets);
    expect(find.text('Voice'), findsWidgets);
    expect(find.text('Images'), findsWidgets);
    expect(find.text('Models'), findsWidgets);
    expect(find.text('Server'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });
}
