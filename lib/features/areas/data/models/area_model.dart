import 'package:cloud_firestore/cloud_firestore.dart';

class AreaModel {
  final String areaId;
  final String name;
  final String description;
  final int orderIndex;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  AreaModel({
    required this.areaId,
    required this.name,
    required this.description,
    required this.orderIndex,
    required this.isActive,
    required this.createdAt,
    required this.updatedAt,
  });

  factory AreaModel.fromJson(Map<String, dynamic> json) {
    return AreaModel(
      areaId: json['areaId'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      orderIndex: json['orderIndex'] as int? ?? 0,
      isActive: json['isActive'] as bool? ?? true,
      createdAt: (json['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (json['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'areaId': areaId,
      'name': name,
      'description': description,
      'orderIndex': orderIndex,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  ReceptionArea toDomain() {
    return ReceptionArea(
      areaId: areaId,
      name: name,
      description: description,
      orderIndex: orderIndex,
      isActive: isActive,
    );
  }
}