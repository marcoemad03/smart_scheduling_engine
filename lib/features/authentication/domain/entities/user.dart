import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserDomain {
  final String id;
  final String email;
  final UserRole role;
  final String displayName;
  final bool isActive;

  UserDomain({
    required this.id,
    required this.email,
    required this.role,
    required this.displayName,
    required this.isActive,
  });
}