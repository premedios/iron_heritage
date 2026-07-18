import 'package:flutter_test/flutter_test.dart';

import 'package:iron_heritage/app.dart';
import 'package:iron_heritage/flavors.dart';

void main() {
  testWidgets('App renders the active flavor title', (
    WidgetTester tester,
  ) async {
    // main() normally sets this from the --flavor build argument; tests run
    // without one, so pick a flavor explicitly. F.appFlavor is late final, so
    // it can only be assigned once per test process.
    F.appFlavor = Flavor.dev;

    await tester.pumpWidget(const App());

    expect(find.text('Iron Heritage Dev'), findsWidgets);
  });
}
