import 'package:flutter/material.dart';

final class AppShell extends StatefulWidget {
  const AppShell({
    required this.initialIndex,
    required this.home,
    required this.training,
    required this.calendar,
    super.key,
  });

  final int initialIndex;
  final Widget home;
  final Widget training;
  final Widget calendar;

  @override
  State<AppShell> createState() => _AppShellState();
}

final class _AppShellState extends State<AppShell> {
  late int _index;

  @override
  void initState() {
    super.initState();
    _index = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [widget.home, widget.training, widget.calendar],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            label: 'Training',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            label: 'Calendar',
          ),
        ],
      ),
    );
  }
}
