import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'home_view_state.dart';

final homeViewStateProvider = Provider<HomeViewState>((ref) {
  return HomeViewState.resolve();
});

class HomeActionEvent {
  const HomeActionEvent({required this.sequence, required this.action});

  final int sequence;
  final HomeAction action;
}

class HomeActionController extends Notifier<HomeActionEvent?> {
  var _sequence = 0;

  @override
  HomeActionEvent? build() => null;

  void dispatch(HomeAction action) {
    state = HomeActionEvent(sequence: ++_sequence, action: action);
  }
}

final homeActionEventProvider =
    NotifierProvider<HomeActionController, HomeActionEvent?>(
      HomeActionController.new,
    );
