part of 'add_branch_cubit.dart';

const _noBranchPhoneValue = Object();

enum BranchFormStatus { initial, loading, ready, submitting, success, failure }

class BranchAddress {
  const BranchAddress({
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

  Map<String, dynamic> toJson() {
    return {
      'line1': buildingName,
      'line2': '',
      'village': '',
      'district': '',
      'city': city,
      'state': state,
      'country': 'India',
      'postalCode': pincode,
    };
  }
}

class AddBranchState {
  const AddBranchState({
    this.status = BranchFormStatus.initial,
    this.address,
    this.images = const <File>[],
    this.savedPhone,
    this.errorMessage,
  });

  final BranchFormStatus status;
  final BranchAddress? address;
  final List<File> images;
  final String? savedPhone;
  final String? errorMessage;

  bool get isSubmitting => status == BranchFormStatus.submitting;
  bool get isSuccess => status == BranchFormStatus.success;

  AddBranchState copyWith({
    BranchFormStatus? status,
    BranchAddress? address,
    bool clearAddress = false,
    List<File>? images,
    bool clearImages = false,
    Object? savedPhone = _noBranchPhoneValue,
    String? errorMessage,
    bool clearError = false,
  }) {
    return AddBranchState(
      status: status ?? this.status,
      address: clearAddress ? null : (address ?? this.address),
      images: clearImages ? const <File>[] : (images ?? this.images),
      savedPhone: savedPhone == _noBranchPhoneValue
          ? this.savedPhone
          : savedPhone as String?,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}
