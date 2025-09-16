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
      if (sortOrder != null) 'sortOrder': sortOrder,
      'disabled': isDisabled,
    };
  }

  factory AddCategoryRequest.fromJson(Map<String, dynamic> json) {
    return AddCategoryRequest(
      name: json['name'] ?? '',
      description: json['description'] as String?,
      isDisabled: json['disabled'] as bool? ?? false,
      sortOrder: json['sortOrder'] as int?,
    );
  }
}
