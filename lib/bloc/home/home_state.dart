abstract class HomeState {}

class HomeInitial extends HomeState {}

class HomeTabChangedState extends HomeState {
  final int tabIndex;

  HomeTabChangedState({required this.tabIndex});
}
