part of 'category_cubit.dart';

enum CategoryStatus {
  initial,
  loading,
  success,
  failure,
  submitting,
  actionSuccess,
  actionFailure,
}

class CategoryState {
  const CategoryState({
    this.status = CategoryStatus.initial,
    this.categories = const [],
    this.message,
  });

  final CategoryStatus status;
  final List<dynamic> categories;
  final String? message;

  bool get isLoading => status == CategoryStatus.loading;
  bool get isSubmitting => status == CategoryStatus.submitting;
  bool get hasMessage => message != null && message!.isNotEmpty;

  CategoryState copyWith({
    CategoryStatus? status,
    List<dynamic>? categories,
    String? message,
    bool clearMessage = false,
  }) {
    return CategoryState(
      status: status ?? this.status,
      categories: categories ?? this.categories,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}
