import 'dart:convert'; // 👈 if you want to use jsonEncode/jsonDecode elsewhere

class AddCategoryRequest {
  final String name;
  final int sortOrder;

  AddCategoryRequest({
    required this.name,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sortOrder': sortOrder,
    };
  }

  factory AddCategoryRequest.fromJson(Map<String, dynamic> json) {
    return AddCategoryRequest(
      name: json['name'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}

class AddSubCategoryRequest {
  final String name;
  final int sortOrder;

  AddSubCategoryRequest({
    required this.name,
    required this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'sortOrder': sortOrder,
    };
  }

  factory AddSubCategoryRequest.fromJson(Map<String, dynamic> json) {
    return AddSubCategoryRequest(
      name: json['name'] ?? '',
      sortOrder: json['sortOrder'] ?? 0,
    );
  }
}
