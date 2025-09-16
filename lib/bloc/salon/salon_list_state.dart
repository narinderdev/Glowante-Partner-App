part of 'salon_list_cubit.dart';

enum SalonListStatus { initial, loading, success, failure }

class SalonListState {
  const SalonListState({
    this.status = SalonListStatus.initial,
    this.salons = const [],
    this.expandedSalonId,
    this.errorMessage,
  });

  final SalonListStatus status;
  final List<Map<String, dynamic>> salons;
  final int? expandedSalonId;
  final String? errorMessage;

  bool get isLoading => status == SalonListStatus.loading;
  bool get hasError => status == SalonListStatus.failure;

  SalonListState copyWith({
    SalonListStatus? status,
    List<Map<String, dynamic>>? salons,
    int? expandedSalonId,
    bool clearExpandedSalon = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return SalonListState(
      status: status ?? this.status,
      salons: salons ?? this.salons,
      expandedSalonId: clearExpandedSalon ? null : (expandedSalonId ?? this.expandedSalonId),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
