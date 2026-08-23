import '../../domain/entities/user.dart';

abstract class AuthRepository {
  Future<UserDomain> signIn({required String email, required String password});
  Future<void> signOut();
  Stream<UserDomain?> authStateChanges();
  UserDomain? getCurrentUser();
}