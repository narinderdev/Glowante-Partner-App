import 'dart:convert';
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
          message: _extractErrorMessage(error),
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
      () =>
          _repository.deleteCategory(salonId: salonId, categoryId: categoryId),
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

  Future<void> updateSubCategory(
    int salonId,
    int subCategoryId,
    String name,
  ) async {
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
      () => _repository.deleteService(salonId: salonId, serviceId: serviceId),
      fallbackMessage: 'Service deleted successfully',
    );
  }

  Future<void> updateService(
    int salonId,
    int serviceId,
    Map<String, dynamic> body,
  ) async {
    emit(state.copyWith(status: CategoryStatus.submitting, clearMessage: true));

    try {
      await _repository.updateService(salonId, serviceId, body);
      await loadCategories(salonId);

      emit(
        state.copyWith(
          status: CategoryStatus.actionSuccess,
          message: 'Service updated successfully',
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: CategoryStatus.actionFailure,
          message: _extractErrorMessage(error),
        ),
      );
    }
  }

  void clearMessage() {
    if (!state.hasMessage) return;
    final normalizedStatus =
        state.status == CategoryStatus.actionSuccess ||
            state.status == CategoryStatus.actionFailure
        ? CategoryStatus.success
        : state.status;

    emit(state.copyWith(status: normalizedStatus, clearMessage: true));
  }

  Future<void> _performMutation(
    int salonId,
    Future<Map<String, dynamic>> Function() action, {
    required String fallbackMessage,
  }) async {
    emit(state.copyWith(status: CategoryStatus.submitting, clearMessage: true));

    try {
      final result = await action();
      final success =
          result['success'] == true || !result.containsKey('success');
      if (!success) {
        final reason = _messageFromPayload(result) ?? 'Request failed';
        throw Exception(reason);
      }

      final loaded = await loadCategories(salonId);
      if (loaded) {
        emit(
          state.copyWith(
            status: CategoryStatus.actionSuccess,
            message: _messageFromPayload(result) ?? fallbackMessage,
          ),
        );
      }
    } catch (error) {
      emit(
        state.copyWith(
          status: CategoryStatus.actionFailure,
          message: _extractErrorMessage(error),
        ),
      );
    }
  }

  String? _messageFromPayload(Map<String, dynamic> payload) {
    final message = payload['message'];
    final validation = payload['errors'];

    final details = validation is Map<String, dynamic>
        ? _flattenErrors(validation)
        : null;

    final parts = <String>[];
    if (message is String && message.isNotEmpty) {
      parts.add(message);
    }
    if (details != null && details.isNotEmpty) {
      parts.add(details);
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  String _extractErrorMessage(Object error) {
    if (error is String) {
      return error;
    }

    final raw = error.toString();
    final sanitized = raw.startsWith('Exception: ') ? raw.substring(11) : raw;
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(sanitized);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map<String, dynamic>) {
          final message = _messageFromPayload(decoded);
          if (message != null && message.isNotEmpty) {
            return message;
          }
        }
      } catch (_) {
        // ignore JSON parse issues and fall back to raw message
      }
    }

    return sanitized.isNotEmpty ? sanitized : raw;
  }

  String _flattenErrors(Map<String, dynamic> errors) {
    final buffer = <String>[];
    for (final entry in errors.entries) {
      final value = entry.value;
      if (value is List) {
        buffer.addAll(value.whereType<String>());
      } else if (value is String) {
        buffer.add(value);
      } else if (value != null) {
        buffer.add(value.toString());
      }
    }
    return buffer.join('\n');
  }
}
