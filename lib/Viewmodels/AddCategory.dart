class AddCategoryRequest {
  final String name;
  final String? description;
  final bool isDisabled;
  final int? sortOrder;

  AddCategoryRequest({
    required this.name,
    this.description,
    this.isDisabled = false,
    this.sortOrder,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      if (description != null && description!.isNotEmpty)
        'description': description,
      'sortOrder': 100,
      // 'isActive': !isDisabled,
    };
  }

  factory AddCategoryRequest.fromJson(Map<String, dynamic> json) {
    final isActive = json['isActive'] as bool? ?? true;
    return AddCategoryRequest(
      name: json['name'] ?? '',
      description: json['description'] as String?,
      // isDisabled: !isActive,
      sortOrder: json['sortOrder'] as int?,
    );
  }
}
