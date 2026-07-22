import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iron_heritage/app.dart';
import 'package:iron_heritage/flavors.dart';
import 'package:iron_heritage/src/features/sync/data/wger_repository.dart';

void main() {
  testWidgets('App opens the Home tab after synchronization', (
    WidgetTester tester,
  ) async {
    F.appFlavor = Flavor.dev;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSyncedProvider.overrideWith((ref) async => true)],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('TODAY'), findsOneWidget);
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Dashboard Placeholder'), findsNothing);
  });
}
