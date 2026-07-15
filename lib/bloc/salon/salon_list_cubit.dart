import 'package:flutter_bloc/flutter_bloc.dart';

import '../../repositories/salon_repository.dart';
import '../../utils/error_parser.dart';

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
          errorMessage: _friendlySalonLoadError(error),
        ),
      );
    }
  }

  String _friendlySalonLoadError(Object error) {
    final message = extractErrorMessage(
      error,
      fallback:
          'Unable to load salons right now. Please check your internet and try again.',
    );
    final lowerMessage = message.toLowerCase();

    if (lowerMessage.contains('temporarily unreachable') ||
        lowerMessage.contains('gateway') ||
        lowerMessage.contains('service unavailable') ||
        lowerMessage.contains('503') ||
        lowerMessage.contains('504')) {
      return 'A required service is temporarily unreachable. Please try again in a few minutes.';
    }

    if (lowerMessage.contains('socketexception') ||
        lowerMessage.contains('failed host lookup') ||
        lowerMessage.contains('connection refused') ||
        lowerMessage.contains('connection reset') ||
        lowerMessage.contains('network is unreachable') ||
        lowerMessage.contains('timed out') ||
        lowerMessage.contains('timeout') ||
        lowerMessage.contains('time-out')) {
      return 'Your internet connection looks slow or unavailable. Please check your connection and try again.';
    }

    return message;
  }

  void toggleExpanded(int salonId) {
    if (state.expandedSalonId == salonId) {
      emit(state.copyWith(clearExpandedSalon: true));
    } else {
      emit(state.copyWith(expandedSalonId: salonId));
    }
  }

  void clear() {
    emit(const SalonListState());
  }

  void setSelectedSalon(Map<String, dynamic> salon) {
    emit(state.copyWith(selectedSalon: salon));
  }

  void clearSelectedSalon() {
    emit(state.copyWith(clearSelectedSalon: true));
  }
}
