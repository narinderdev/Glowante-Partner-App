import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/salon_repository.dart';

part 'salon_list_state.dart';

class SalonListCubit extends Cubit<SalonListState> {
  SalonListCubit(this._repository) : super(const SalonListState());

  final SalonRepository _repository;

  Future<void> loadSalons() async {
    emit(state.copyWith(status: SalonListStatus.loading, clearError: true));

    try {
      final salons = await _repository.fetchSalons();
      emit(
        state.copyWith(
          status: SalonListStatus.success,
          salons: salons,
          clearError: true,
          clearExpandedSalon: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: SalonListStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void toggleExpanded(int salonId) {
    if (state.expandedSalonId == salonId) {
      emit(state.copyWith(clearExpandedSalon: true));
    } else {
      emit(state.copyWith(expandedSalonId: salonId));
    }
  }
}
