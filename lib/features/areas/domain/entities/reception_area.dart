class ReceptionArea {
  final String areaId;
  final String name;
  final String description;
  final int orderIndex;
  final bool isActive;
  final String? icon;

  ReceptionArea({
    required this.areaId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.isActive,
    this.icon,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  final DateTime createdAt;
  final DateTime updatedAt;

  ReceptionArea copyWith({
    String? name,
    String? description,
    int? orderIndex,
    bool? isActive,
    String? icon,
  }) {
    return ReceptionArea(
      areaId: areaId,
      name: name ?? this.name,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      icon: icon ?? this.icon,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

