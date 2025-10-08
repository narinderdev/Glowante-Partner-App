class AddCategoryRequest {
  final String displayName;
  final String? description;
  final bool isActive;
  final int sortOrder;

  AddCategoryRequest({
    required this.displayName,
    this.description,
    this.isActive = true,
    this.sortOrder = 100,
  });

  Map<String, dynamic> toJson() {
    return {
      'displayName': displayName,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'sortOrder': sortOrder,
      'isActive': isActive,
    };
  }

  factory AddCategoryRequest.fromJson(Map<String, dynamic> json) {
    return AddCategoryRequest(
      displayName: json['displayName'] ?? '',
      description: json['description'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      sortOrder: json['sortOrder'] as int? ?? 100,
    );
  }
}
