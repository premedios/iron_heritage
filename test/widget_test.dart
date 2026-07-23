import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:iron_heritage/app.dart';
import 'package:iron_heritage/flavors.dart';
import 'package:iron_heritage/src/features/sync/data/wger_repository.dart';
import 'package:iron_heritage/src/features/training/presentation/training_providers.dart';

import 'support/fake_training_repository.dart';

void main() {
  setUpAll(() => F.appFlavor = Flavor.dev);

  testWidgets('sync wait uses an accessible skeleton without a spinner', (
    tester,
  ) async {
    final syncResult = Completer<bool>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [isSyncedProvider.overrideWith((ref) => syncResult.future)],
        child: const App(),
      ),
    );
    await tester.pump();

    expect(find.bySemanticsLabel('Loading Iron Heritage'), findsOneWidget);
    expect(find.byKey(const Key('app-loading-skeleton')), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('synced app starts on Training with incremental destinations', (
    WidgetTester tester,
  ) async {
    final repository = FakeTrainingRepository();
    addTearDown(repository.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          isSyncedProvider.overrideWith((ref) async => true),
          trainingRepositoryProvider.overrideWithValue(repository),
        ],
        child: const App(),
      ),
    );

    await tester.pumpAndSettle();

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.selectedIndex, 1);
    expect(find.text('Training'), findsWidgets);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Home'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Home is not available yet'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Calendar'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Calendar is not available yet'), findsOneWidget);
  });
}
