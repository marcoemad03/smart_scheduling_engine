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