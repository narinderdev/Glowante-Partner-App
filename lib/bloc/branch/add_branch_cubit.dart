import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/salon_repository.dart';

part 'add_branch_state.dart';

class AddBranchFormData {
  const AddBranchFormData({
    required this.name,
    required this.phone,
    required this.startTime,
    required this.endTime,
    required this.description,
    required this.schedule,
    this.imageUrl,
    this.sourceBranchId,
  });

  final String name;
  final String phone;
  final String startTime;
  final String endTime;
  final String description;
  final Map<String, List<Map<String, String>>> schedule;
  final String? imageUrl;
  final int? sourceBranchId;
}

class AddBranchCubit extends Cubit<AddBranchState> {
  AddBranchCubit(this._repository, {required this.salonId})
      : super(const AddBranchState());

  final int salonId;
  final SalonRepository _repository;

  // ✅ Add this line to expose repository publicly
  SalonRepository get repository => _repository;

  Future<void> loadSavedPhone() async {
    emit(state.copyWith(status: BranchFormStatus.loading));

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('phone_number');
      emit(
        state.copyWith(
          status: BranchFormStatus.ready,
          savedPhone: savedPhone,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: BranchFormStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void updateAddress(BranchAddress address) {
    emit(
      state.copyWith(
        address: address,
        status: BranchFormStatus.ready,
      ),
    );
  }

  void setImages(List<File> images) {
    emit(
      state.copyWith(
        images: images.take(10).toList(),
        status: BranchFormStatus.ready,
      ),
    );
  }

  void removeImage(File image) {
    final updated = List<File>.from(state.images)..remove(image);
    emit(state.copyWith(images: updated, status: BranchFormStatus.ready));
  }

  Future<void> submit(AddBranchFormData formData) async {
    final address = state.address;
    if (address == null) {
      emit(
        state.copyWith(
          status: BranchFormStatus.failure,
          errorMessage: 'Please choose the branch location before submitting.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: BranchFormStatus.submitting, clearError: true));

    try {
      await _repository.addBranch(
        salonId: salonId,
        name: formData.name,
        phone: formData.phone,
        startTime: formData.startTime,
        endTime: formData.endTime,
        description: formData.description,
        schedule: formData.schedule,
        address: address.toJson(),
        latitude: address.latitude,
        longitude: address.longitude,
        images: state.images,
        imageUrl: formData.imageUrl,
        sourceBranchId: formData.sourceBranchId,
      );

      emit(
        state.copyWith(
          status: BranchFormStatus.success,
          clearAddress: true,
          clearImages: true,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: BranchFormStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void resetStatus() {
    emit(
      state.copyWith(
        status: BranchFormStatus.ready,
        clearError: true,
      ),
    );
  }
}
