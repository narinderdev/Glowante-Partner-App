import 'package:flutter_bloc/flutter_bloc.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  HomeBloc() : super(HomeInitial()) {
    on<HomeTabChangedEvent>((event, emit) {
      emit(HomeTabChangedState(tabIndex: event.tabIndex));
    });
  }
}
