import 'dart:convert';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../Viewmodels/AddCategory.dart';
import '../../repositories/salon_repository.dart';

part 'category_state.dart';

class CategoryCubit extends Cubit<CategoryState> {
  CategoryCubit(this._repository) : super(const CategoryState());

  final SalonRepository _repository;

  void resetCategories() {
    emit(
      state.copyWith(
        status: CategoryStatus.loading,
        categories: const [],
        clearMessage: true,
      ),
    );
  }

  void clear() {
    emit(const CategoryState());
  }

  Future<bool> loadCategories(int branchId, {bool silent = false}) async {
    if (!silent) {
      emit(state.copyWith(status: CategoryStatus.loading, clearMessage: true));
    }

    try {
      final response = await _repository.fetchSalonCatalog(branchId);
      if (response['success'] != true) {
        throw Exception(response['message'] ?? 'Failed to load categories');
      }

      final data = response['data'] as Map<String, dynamic>?;
      final categories = _activeCategoryTree(
        (data?['categories'] as List?) ?? const [],
      );

      emit(state.copyWith(
        status: CategoryStatus.success,
        categories: categories.cast<dynamic>(),
        clearMessage: true,
      ));
      return true;
    } catch (error) {
      if (_isNoCategories404(error)) {
        emit(state.copyWith(
          status: CategoryStatus.success,
          categories: const [],
          clearMessage: true,
        ));
        return true;
      }
      emit(state.copyWith(
        status: CategoryStatus.failure,
        message: _extractErrorMessage(error),
      ));
      return false;
    }
  }

  Future<void> addCategory(int branchId, AddCategoryRequest request) async {
    await _performMutation(
      branchId,
      () => _repository.addCategory(branchId: branchId, request: request),
      fallbackMessage: 'Category added successfully',
    );
  }

  Future<void> updateCategory(
    int branchId,
    int branchCategoryId,
    AddCategoryRequest request,
  ) async {
    await _performMutation(
      branchId,
      () => _repository.updateCategory(
        branchId: branchId,
        branchCategoryId: branchCategoryId,
        request: request,
      ),
      fallbackMessage: 'Category updated successfully',
    );
  }

  Future<void> deleteCategory(int branchId, int categoryId) async {
    await _performMutation(
      branchId,
      () => _repository.deleteCategory(
          branchId: branchId, categoryId: categoryId),
      fallbackMessage: 'Category deleted successfully',
    );
  }

  Future<void> addSubCategory(int branchId, int categoryId, String name) async {
    await _performMutation(
      branchId,
      () => _repository.addSubCategory(
        branchId: branchId,
        categoryId: categoryId,
        displayName: name,
      ),
      fallbackMessage: 'Subcategory added successfully',
    );
  }

  bool _isNoCategories404(Object error) {
    final raw = error.toString();
    final match = RegExp(r'\{.*\}', dotAll: true).firstMatch(raw);
    if (match != null) {
      try {
        final decoded = jsonDecode(match.group(0)!);
        if (decoded is Map<String, dynamic>) {
          final code =
              decoded['statusCode'] ?? decoded['status'] ?? decoded['code'];
          final msg = (decoded['message'] ?? decoded['error'] ?? '').toString();
          if (code == 404 &&
              msg.toLowerCase().contains('no salon categories')) {
            return true;
          }
        }
      } catch (_) {/* ignore */}
    }

    final lower = raw.toLowerCase();
    if (lower.contains('statuscode":404') ||
        lower.contains('status: 404') ||
        lower.contains(' 404')) {
      if (lower.contains('no salon categories')) return true;
    }

    return false;
  }

  List<Map<String, dynamic>> _activeCategoryTree(List<dynamic> rawCategories) {
    return rawCategories
        .whereType<Map>()
        .map((entry) => Map<String, dynamic>.from(entry))
        .where(_isCatalogItemActive)
        .map((category) {
      final subCategories =
          ((category['subCategories'] ?? category['subcategories']) as List? ??
                  const [])
              .whereType<Map>()
              .map((entry) => Map<String, dynamic>.from(entry))
              .where(_isCatalogItemActive)
              .map((subCategory) {
        final services = (subCategory['services'] as List? ?? const [])
            .whereType<Map>()
            .map((entry) => Map<String, dynamic>.from(entry))
            .where(_isCatalogItemActive)
            .toList();
        return {
          ...subCategory,
          'services': services,
        };
      }).toList();

      final services = (category['services'] as List? ?? const [])
          .whereType<Map>()
          .map((entry) => Map<String, dynamic>.from(entry))
          .where(_isCatalogItemActive)
          .toList();

      return {
        ...category,
        'subCategories': subCategories,
        'services': services,
      };
    }).toList();
  }

  bool _isCatalogItemActive(Map<String, dynamic> item) {
    final isActive = item['isActive'] ?? item['active'];
    if (isActive is bool && !isActive) return false;
    if (isActive is num && isActive == 0) return false;
    if (isActive is String) {
      final normalized = isActive.trim().toLowerCase();
      if (normalized == 'false' ||
          normalized == '0' ||
          normalized == 'inactive' ||
          normalized == 'deleted') {
        return false;
      }
    }

    final status = item['status'] ?? item['state'];
    if (status is String) {
      final normalized = status.trim().toLowerCase();
      if (normalized == 'inactive' ||
          normalized == 'deleted' ||
          normalized == 'archived' ||
          normalized == 'disabled') {
        return false;
      }
    }

    return true;
  }

  Future<void> updateSubCategory(
    int branchId,
    int subCategoryId,
    String displayName, {
    int sortOrder = 200,
    bool isActive = true,
  }) async {
    await _performMutation(
      branchId,
      () => _repository.updateSubCategory(
        branchId: branchId,
        subCategoryId: subCategoryId,
        displayName: displayName,
        sortOrder: sortOrder,
        isActive: isActive,
      ),
      fallbackMessage: 'Subcategory updated successfully',
    );
  }

  Future<void> deleteSubCategory(int branchId, int subCategoryId) async {
    await _performMutation(
      branchId,
      () => _repository.deleteSubCategory(
        branchId: branchId,
        subCategoryId: subCategoryId,
      ),
      fallbackMessage: 'Subcategory deleted successfully',
    );
  }

  Future<void> deleteService(int branchId, int serviceId) async {
    await _performMutation(
      branchId,
      () => _repository.deleteService(branchId: branchId, serviceId: serviceId),
      fallbackMessage: 'Service deleted successfully',
    );
  }

  Future<void> updateService(
    int branchId,
    int serviceId,
    Map<String, dynamic> body,
  ) async {
    emit(state.copyWith(status: CategoryStatus.submitting, clearMessage: true));

    try {
      await _repository.updateService(branchId, serviceId, body);
      await loadCategories(branchId);

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
    final normalizedStatus = state.status == CategoryStatus.actionSuccess ||
            state.status == CategoryStatus.actionFailure
        ? CategoryStatus.success
        : state.status;

    emit(state.copyWith(status: normalizedStatus, clearMessage: true));
  }

  Future<void> _performMutation(
    int branchId,
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

      final successMessage = _messageFromPayload(result) ?? fallbackMessage;
      emit(state.copyWith(
        status: CategoryStatus.actionSuccess,
        message: successMessage,
      ));
      await loadCategories(branchId, silent: true);
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
    final parts = <String>[];

    final message = payload['message'];
    if (message is String && message.trim().isNotEmpty) {
      parts.add(message.trim());
    } else if (message is List) {
      parts.addAll(
        message
            .whereType<String>()
            .map((s) => s.trim())
            .where((s) => s.isNotEmpty),
      );
    }
    final error = payload['error'];
    if (parts.isEmpty && error is String && error.trim().isNotEmpty) {
      parts.add(error.trim());
    }

    final validation = payload['errors'];
    if (validation is Map<String, dynamic>) {
      final details = _flattenErrors(validation);
      if (details.isNotEmpty) parts.add(details);
    } else if (validation is List) {
      parts.addAll(validation.whereType<String>());
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
      } catch (_) {}
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
