import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../repositories/salon_repository.dart';

part 'add_salon_state.dart';

class AddSalonFormData {
  const AddSalonFormData({
    required this.name,
    required this.phone,
    required this.startTime,
    required this.endTime,
    required this.description,
  });

  final String name;
  final String phone;
  final String startTime;
  final String endTime;
  final String description;
}

class AddSalonCubit extends Cubit<AddSalonState> {
  AddSalonCubit(this._repository) : super(const AddSalonState());

  final SalonRepository _repository;

  Future<void> loadSavedPhone({String? initialPhone}) async {
    if (initialPhone != null && initialPhone.isNotEmpty) {
      emit(
        state.copyWith(
          status: AddSalonStatus.ready,
          savedPhone: initialPhone,
          clearError: true,
        ),
      );
      return;
    }

    emit(state.copyWith(status: AddSalonStatus.loading));

    try {
      final prefs = await SharedPreferences.getInstance();
      final savedPhone = prefs.getString('phone_number');
      emit(
        state.copyWith(
          status: AddSalonStatus.ready,
          savedPhone: savedPhone,
          clearError: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AddSalonStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void updateAddress(AddSalonAddress address) {
    emit(state.copyWith(address: address, status: AddSalonStatus.ready));
  }

  void setImages(List<File> images) {
    emit(state.copyWith(images: images, status: AddSalonStatus.ready));
  }

  Future<void> submit(AddSalonFormData formData) async {
    final address = state.address;
    if (address == null) {
      emit(
        state.copyWith(
          status: AddSalonStatus.failure,
          errorMessage: 'Please select the salon location before submitting.',
        ),
      );
      return;
    }

    emit(state.copyWith(status: AddSalonStatus.submitting, clearError: true));

    try {
      await _repository.createSalon(
        name: formData.name,
        phone: formData.phone,
        startTime: formData.startTime,
        endTime: formData.endTime,
        description: formData.description,
        buildingName: address.buildingName,
        city: address.city,
        pincode: address.pincode,
        state: address.state,
        latitude: address.latitude,
        longitude: address.longitude,
        images: state.images,
      );

      emit(
        state.copyWith(
          status: AddSalonStatus.success,
          clearError: true,
          clearImages: true,
          clearAddress: true,
        ),
      );
    } catch (error) {
      emit(
        state.copyWith(
          status: AddSalonStatus.failure,
          errorMessage: error.toString(),
        ),
      );
    }
  }

  void resetStatus() {
    emit(state.copyWith(status: AddSalonStatus.ready, clearError: true));
  }
}
