import 'package:flutter_bloc/flutter_bloc.dart';

import '../../Viewmodels/AddCategory.dart';
import '../../repositories/salon_repository.dart';

part 'category_state.dart';

class CategoryCubit extends Cubit<CategoryState> {
  CategoryCubit(this._repository) : super(const CategoryState());

  final SalonRepository _repository;

  Future<bool> loadCategories(int salonId) async {
    emit(state.copyWith(status: CategoryStatus.loading, clearMessage: true));

    try {
      final response = await _repository.fetchSalonCatalog(salonId);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load categories');
      }

      final data = response['data'] as Map<String, dynamic>?;
      final categories = (data?['categories'] as List?) ?? [];

      emit(
        state.copyWith(
          status: CategoryStatus.success,
          categories: categories.cast<dynamic>(),
          clearMessage: true,
        ),
      );
      return true;
    } catch (error) {
      emit(
        state.copyWith(
          status: CategoryStatus.failure,
          message: error.toString(),
        ),
      );
      return false;
    }
  }

  Future<void> addCategory(int salonId, AddCategoryRequest request) async {
    await _performMutation(
      salonId,
      () => _repository.addCategory(salonId: salonId, request: request),
      fallbackMessage: 'Category added successfully',
    );
  }

  Future<void> updateCategory(
    int salonId,
    int categoryId,
    AddCategoryRequest request,
  ) async {
    await _performMutation(
      salonId,
      () => _repository.updateCategory(
        salonId: salonId,
        categoryId: categoryId,
        request: request,
      ),
      fallbackMessage: 'Category updated successfully',
    );
  }

  Future<void> deleteCategory(int salonId, int categoryId) async {
    await _performMutation(
      salonId,
      () => _repository.deleteCategory(
        salonId: salonId,
        categoryId: categoryId,
      ),
      fallbackMessage: 'Category deleted successfully',
    );
  }

  Future<void> addSubCategory(int salonId, int categoryId, String name) async {
    await _performMutation(
      salonId,
      () => _repository.addSubCategory(
        salonId: salonId,
        categoryId: categoryId,
        name: name,
      ),
      fallbackMessage: 'Subcategory added successfully',
    );
  }

  Future<void> updateSubCategory(int salonId, int subCategoryId, String name) async {
    await _performMutation(
      salonId,
      () => _repository.updateSubCategory(
        salonId: salonId,
        subCategoryId: subCategoryId,
        name: name,
      ),
      fallbackMessage: 'Subcategory updated successfully',
    );
  }

  Future<void> deleteSubCategory(int salonId, int subCategoryId) async {
    await _performMutation(
      salonId,
      () => _repository.deleteSubCategory(
        salonId: salonId,
        subCategoryId: subCategoryId,
      ),
      fallbackMessage: 'Subcategory deleted successfully',
    );
  }

  Future<void> deleteService(int salonId, int serviceId) async {
    await _performMutation(
      salonId,
      () => _repository.deleteService(
        salonId: salonId,
        serviceId: serviceId,
      ),
      fallbackMessage: 'Service deleted successfully',
    );
  }

  void clearMessage() {
    if (!state.hasMessage) return;
    final normalizedStatus = state.status == CategoryStatus.actionSuccess ||
            state.status == CategoryStatus.actionFailure
        ? CategoryStatus.success
        : state.status;

    emit(
      state.copyWith(
        status: normalizedStatus,
        clearMessage: true,
      ),
    );
  }

  Future<void> _performMutation(
    int salonId,
    Future<Map<String, dynamic>> Function() action, {
    required String fallbackMessage,
  }) async {
    emit(state.copyWith(status: CategoryStatus.submitting, clearMessage: true));

    try {
      final result = await action();
      if (result['success'] != true) {
        throw Exception(result['message'] ?? 'Request failed');
      }

      final loaded = await loadCategories(salonId);
      if (loaded) {
        emit(
          state.copyWith(
            status: CategoryStatus.actionSuccess,
            message: (result['message'] as String?) ?? fallbackMessage,
          ),
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          status: CategoryStatus.actionFailure,
          message: error.toString(),
        ),
      );
    }
  }
}
