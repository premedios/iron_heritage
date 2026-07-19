import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'flavors.dart';


import 'src/core/theme/app_theme.dart';
import 'src/features/sync/data/wger_repository.dart';
import 'src/features/sync/presentation/sync_screen.dart';
import 'src/features/dashboard/presentation/dashboard_screen.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
              return const DashboardScreen();
            } else {
              return const SyncScreen();
            }
          },
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, stack) => Scaffold(
            body: Center(child: Text('Error: $err')),
          ),
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
