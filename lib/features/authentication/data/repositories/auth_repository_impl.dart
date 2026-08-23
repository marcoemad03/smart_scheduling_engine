import 'package:firebase_auth/firebase_auth.dart' hide User;
import 'package:cloud_firestore/cloud_firestore.dart';
import '../data/datasources/auth_remote_datasource.dart';
import '../data/models/user_model.dart';
import '../../core/errors/exceptions.dart';

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
    } on FirebaseAuthException catch (e) {
      throw AuthException(e.message ?? 'Authentication failed');
    } catch (e) {
      throw AppException(e.toString());
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