import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import '../../domain/entities/user.dart';

class AuthRemoteDataSource {
  final FirebaseAuth auth;
  final FirebaseFirestore firestore;

  AuthRemoteDataSource({required this.auth, required this.firestore});

  Future<UserCredential> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) {
    return auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<void> signOut() {
    return auth.signOut();
  }

  Stream<User?> authStateChanges() {
    return auth.authStateChanges();
  }

  User? getCurrentUser() {
    return auth.currentUser;
  }

  Future<UserModel> getUserById(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    if (!doc.exists) throw Exception('User not found');
    return UserModel.fromJson(doc.data()!);
  }

  Future<void> updateUserLastLogin(String uid) async {
    await firestore.collection('users').doc(uid).update({
      'lastLoginAt': FieldValue.serverTimestamp(),
    });
  }

  /// Links the signed-in auth account to its employee record so schedules
  /// (keyed by the employee document id) match what employees query by uid.
  /// Matching is done by email, then by an existing uid field.
  Future<String?> linkEmployeeRecord(String uid, String? email) async {
    final employees = firestore.collection('employees');
    if (email != null && email.isNotEmpty) {
      final byEmail =
          await employees.where('email', isEqualTo: email).limit(1).get();
      if (byEmail.docs.isNotEmpty) {
        final doc = byEmail.docs.first;
        if ((doc.data()['uid'] as String? ?? '') != uid) {
          await doc.reference.update({'uid': uid});
        }
        return doc.data()['employeeId'] as String? ?? doc.id;
      }
    }
    final byUid = await employees.where('uid', isEqualTo: uid).limit(1).get();
    if (byUid.docs.isNotEmpty) {
      return byUid.docs.first.data()['employeeId'] as String? ??
          byUid.docs.first.id;
    }
    return null;
  }
}

class UserModel {
  final String uid;
  final String email;
  final String role;
  final String displayName;
  final DateTime createdAt;
  final DateTime lastLoginAt;
  final bool isActive;

  UserModel({
    required this.uid,
    required this.email,
    required this.role,
    required this.displayName,
    required this.createdAt,
    required this.lastLoginAt,
    required this.isActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      uid: json['uid'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      displayName: json['displayName'] as String,
      createdAt: (json['createdAt'] as Timestamp).toDate(),
      lastLoginAt: (json['lastLoginAt'] as Timestamp).toDate(),
      isActive: json['isActive'] as bool,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'role': role,
      'displayName': displayName,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLoginAt': Timestamp.fromDate(lastLoginAt),
      'isActive': isActive,
    };
  }

  UserDomain toDomain() {
    return UserDomain(
      id: uid,
      email: email,
      role: role == 'admin' ? UserRole.admin : UserRole.employee,
      displayName: displayName,
      isActive: isActive,
    );
  }
}