class ReceptionArea {
  final String areaId;
  final String name;
  final String description;
  final int orderIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReceptionArea({
    required this.areaId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.isActive,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  ReceptionArea copyWith({
    String? name,
    String? description,
    int? orderIndex,
    bool? isActive,
  }) {
    return ReceptionArea(
      areaId: areaId,
      name: name ?? this.name,
      description: description ?? this.description,
      orderIndex: orderIndex ?? this.orderIndex,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
      updatedAt: DateTime.now(),
    );
  }
}

