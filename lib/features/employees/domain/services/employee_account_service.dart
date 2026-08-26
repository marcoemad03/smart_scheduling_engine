import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/firebase_options.dart';

/// Thrown when an auth account cannot be provisioned. [code] is a stable
/// machine-readable code the UI can localize.
class AccountProvisionException implements Exception {
  final String code;
  final String? email;
  AccountProvisionException(this.code, {this.email});

  @override
  String toString() => 'AccountProvisionException($code)';
}

/// Creates Firebase Authentication accounts for employees WITHOUT touching
/// the admin's own session.
///
/// Security notes:
/// - No Admin SDK credentials are embedded in the client.
/// - Passwords are ONLY sent to Firebase Authentication; they are never
///   written to Firestore.
/// - The account is created through a secondary Firebase app instance so
///   the currently signed-in admin is not signed out.
/// - If the email already has an account, the existing UID is reused
///   (no duplicate account is created).
class EmployeeAccountService {
  final FirebaseFirestore firestore;

  /// Secondary app used for provisioning; created lazily.
  FirebaseApp? _provisioningApp;

  EmployeeAccountService({required this.firestore});

  Future<FirebaseAuth> _ensureProvisioningAuth() async {
    _provisioningApp ??= await Firebase.initializeApp(
      name: 'employee-provisioning',
      options: DefaultFirebaseOptions.currentPlatform,
    );
    return FirebaseAuth.instanceFor(app: _provisioningApp!);
  }

  /// Creates (or reuses) the Firebase Auth account for [email].
  /// Returns the Firebase UID.
  Future<String> createOrReuseAccount({
    required String email,
    required String password,
  }) async {
    // Reuse an existing account when the email is already registered.
    final existing = await findUidByEmail(email);
    if (existing != null) return existing;

    final auth = await _ensureProvisioningAuth();
    try {
      final cred = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = cred.user!.uid;
      await auth.signOut();
      return uid;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'email-already-in-use') {
        // A race: the account appeared after our lookup. Try once more.
        final uid = await findUidByEmail(email);
        if (uid != null) return uid;
      }
      throw AccountProvisionException(e.code, email: email);
    } catch (e) {
      throw AccountProvisionException('unknown', email: email);
    } finally {
      try {
        await auth.signOut();
      } catch (_) {}
    }
  }

  /// Looks up an existing login profile by email. Returns its UID or null.
  Future<String?> findUidByEmail(String email) async {
    final snapshot = await firestore
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isEmpty) return null;
    return snapshot.docs.first.id;
  }

  /// Creates the Firestore login profile for [uid] (role: employee).
  /// The password is NEVER stored here.
  Future<void> ensureUserProfile({
    required String uid,
    required String email,
    String displayName = '',
    String linkedEmployeeId = '',
  }) async {
    await firestore.collection('users').doc(uid).set({
      'uid': uid,
      'email': email,
      'role': 'employee',
      'displayName': displayName,
      'linkedEmployeeId': linkedEmployeeId,
      'isActive': true,
      'createdAt': FieldValue.serverTimestamp(),
      'lastLoginAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Sends a password reset email for an employee's account.
  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Returns the auth role stored on the login profile ('admin'/'employee').
  Future<String?> fetchUserRole(String uid) async {
    final doc = await firestore.collection('users').doc(uid).get();
    return doc.data()?['role'] as String?;
  }

  /// Changes the auth role on the login profile. 'admin' grants full
  /// schedule/employee management access; 'employee' revokes it. The router
  /// guards re-evaluate as soon as the profile document changes.
  Future<void> updateUserRole(String uid, String role) async {
    await firestore
        .collection('users')
        .doc(uid)
        .set({'role': role}, SetOptions(merge: true));
  }
}

  void dispose() {
    final app = _provisioningApp;
    _provisioningApp = null;
    if (app != null) {
      app.delete();
    }
  }
}

final employeeAccountServiceProvider = Provider<EmployeeAccountService>((ref) {
  return EmployeeAccountService(
      firestore: ref.watch(firebaseFirestoreProvider));
});
