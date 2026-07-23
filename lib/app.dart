import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'flavors.dart';
import 'src/core/navigation/app_shell.dart';
import 'src/core/theme/app_theme.dart';
import 'src/features/sync/data/wger_repository.dart';
import 'src/features/sync/presentation/sync_screen.dart';
import 'src/features/training/presentation/training_destination.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSyncedAsync = ref.watch(isSyncedProvider);

    return MaterialApp(
      title: F.title,
      theme: AppTheme.darkTheme,
      home: _flavorBanner(
        child: isSyncedAsync.when(
          data: (isSynced) {
            if (isSynced) {
              return const AppShell(
                initialIndex: 1,
                home: Center(child: Text('Home is not available yet')),
                training: TrainingDestination(),
                calendar: Center(child: Text('Calendar is not available yet')),
              );
            } else {
              return const SyncScreen();
            }
          },
          loading: () => const _AppLoadingSkeleton(),
          error: (err, stack) =>
              Scaffold(body: Center(child: Text('Error: $err'))),
        ),
        show: kDebugMode,
      ),
    );
  }

  Widget _flavorBanner({required Widget child, bool show = true}) => show
      ? Banner(
          location: BannerLocation.topStart,
          message: F.name,
          color: Colors.green.withAlpha(150),
          textStyle: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 12.0,
            letterSpacing: 1.0,
          ),
          textDirection: TextDirection.ltr,
          child: child,
        )
      : Container(child: child);
}

final class _AppLoadingSkeleton extends StatelessWidget {
  const _AppLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.surfaceContainerHighest;
    return Scaffold(
      body: Semantics(
        container: true,
        liveRegion: true,
        label: 'Loading Iron Heritage',
        child: ExcludeSemantics(
          child: Center(
            child: SizedBox(
              key: const Key('app-loading-skeleton'),
              width: 240,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 180, height: 28, color: color),
                  const SizedBox(height: 20),
                  Container(width: 240, height: 16, color: color),
                  const SizedBox(height: 10),
                  Container(width: 200, height: 16, color: color),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
