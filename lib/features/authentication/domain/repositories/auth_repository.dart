import 'package:firebase_auth/firebase_auth.dart';
import 'package:reception_workforce_scheduler/core/constants/enums.dart';
import 'package:reception_workforce_scheduler/core/errors/exceptions.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../domain/entities/user.dart';

abstract class AuthRepository {
  Future<UserDomain> signIn({required String email, required String password});
  Future<void> signOut();
  Stream<UserDomain?> authStateChanges();
  UserDomain? getCurrentUser();
}

class SignInUseCase {
  final AuthRepository repository;
  SignInUseCase(this.repository);
  Future<UserDomain> call(String email, String password) => repository.signIn(email: email, password: password);
}

class SignOutUseCase {
  final AuthRepository repository;
  SignOutUseCase(this.repository);
  Future<void> call() => repository.signOut();
}

class GetCurrentUserUseCase {
  final AuthRepository repository;
  GetCurrentUserUseCase(this.repository);
  UserDomain? call() => repository.getCurrentUser();
}

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;

  AuthRepositoryImpl({required this.remoteDataSource});

  @override
  Future<UserDomain> signIn({required String email, required String password}) async {
    try {
      final userCredential = await remoteDataSource.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final uid = userCredential.user!.uid;

      final userDoc = await remoteDataSource.getUserById(uid);
      await remoteDataSource.updateUserLastLogin(uid);
      // Link auth account -> employee record (by email) so employee-scoped
      // features resolve the correct employeeId.
      await remoteDataSource.linkEmployeeRecord(uid, userCredential.user!.email);

      return userDoc.toDomain();
    } on FirebaseAuthException catch (e) {
      throw AppException(_friendlyAuthError(e));
    } catch (e) {
      throw AppException('Authentication failed: $e');
    }
  }

  String _friendlyAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'wrong-password':
      case 'invalid-credential':
      case 'user-not-found':
        return 'Wrong email or password. Please try again.';
      case 'invalid-email':
        return 'That email address is not valid.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';
      case 'internal-error':
        // The desktop (C++ SDK) implementation reports failed credential
        // validation as internal-error.
        return 'Sign-in failed. Check your email and password, then try again.';
      case 'network-request-failed':
        return 'Network error. Check your connection and try again.';
      case 'operation-not-allowed':
        return 'Email/password sign-in is not enabled for this Firebase project.';
      default:
        return e.message ?? 'Sign-in failed (${e.code}).';
    }
  }

  @override
  Future<void> signOut() {
    return remoteDataSource.signOut();
  }

  @override
  Stream<UserDomain?> authStateChanges() {
    return remoteDataSource.authStateChanges().asyncMap((user) async {
      if (user == null) return null;
      try {
        final userModel = await remoteDataSource.getUserById(user.uid);
        return userModel.toDomain();
      } catch (_) {
        // Users document missing/unreadable: fail closed as a plain employee
        // instead of killing the stream.
        return UserDomain(
          id: user.uid,
          email: user.email ?? '',
          role: UserRole.employee,
          displayName: user.email ?? 'Unknown',
          isActive: true,
        );
      }
    });
  }

  @override
  UserDomain? getCurrentUser() {
    final firebaseUser = remoteDataSource.getCurrentUser();
    if (firebaseUser == null) return null;
    return UserDomain(
      id: firebaseUser.uid,
      email: firebaseUser.email ?? '',
      role: UserRole.employee,
      displayName: firebaseUser.displayName ?? 'Unknown',
      isActive: true,
    );
  }
}

class AuthException implements Exception {
  final String message;
  AuthException(this.message);
}