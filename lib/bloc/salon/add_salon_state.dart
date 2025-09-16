part of 'add_salon_cubit.dart';

const _noPhoneValue = Object();

enum AddSalonStatus { initial, loading, ready, submitting, success, failure }

class AddSalonAddress {
  const AddSalonAddress({
    required this.buildingName,
    required this.city,
    required this.pincode,
    required this.state,
    required this.latitude,
    required this.longitude,
  });

  final String buildingName;
  final String city;
  final String pincode;
  final String state;
  final double latitude;
  final double longitude;

  AddSalonAddress copyWith({
    String? buildingName,
    String? city,
    String? pincode,
    String? state,
    double? latitude,
    double? longitude,
  }) {
    return AddSalonAddress(
      buildingName: buildingName ?? this.buildingName,
      city: city ?? this.city,
      pincode: pincode ?? this.pincode,
      state: state ?? this.state,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
    );
  }
}

class AddSalonState {
  const AddSalonState({
    this.status = AddSalonStatus.initial,
    this.address,
    this.images = const <File>[],
    this.savedPhone,
    this.errorMessage,
  });

  final AddSalonStatus status;
  final AddSalonAddress? address;
  final List<File> images;
  final String? savedPhone;
  final String? errorMessage;

  bool get isSubmitting => status == AddSalonStatus.submitting;
  bool get isSuccess => status == AddSalonStatus.success;

  AddSalonState copyWith({
    AddSalonStatus? status,
    AddSalonAddress? address,
    bool clearAddress = false,
    List<File>? images,
    bool clearImages = false,
    Object? savedPhone = _noPhoneValue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddSalonState(
      status: status ?? this.status,
      address: clearAddress ? null : (address ?? this.address),
      images: clearImages ? const <File>[] : (images ?? this.images),
      savedPhone: savedPhone == _noPhoneValue
          ? this.savedPhone
          : savedPhone as String?,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
