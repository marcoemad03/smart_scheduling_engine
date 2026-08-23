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

      final userDoc = await remoteDataSource.getUserById(userCredential.user!.uid);
      await remoteDataSource.updateUserLastLogin(userCredential.user!.uid);

      return userDoc.toDomain();
    } catch (e) {
      throw AppException('Authentication failed: $e');
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
      final userModel = await remoteDataSource.getUserById(user.uid);
      return userModel.toDomain();
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