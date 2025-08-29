abstract class HomeEvent {}

class HomeTabChangedEvent extends HomeEvent {
  final int tabIndex;

  HomeTabChangedEvent({required this.tabIndex});
}
