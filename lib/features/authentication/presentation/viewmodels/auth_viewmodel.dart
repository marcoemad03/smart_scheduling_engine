import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthViewModel extends StateNotifier<AsyncValue<UserDomain?>> {
  final SignInUseCase signInUseCase;
  final SignOutUseCase signOutUseCase;
  final GetCurrentUserUseCase getCurrentUserUseCase;

  AuthViewModel({
    required this.signInUseCase,
    required this.signOutUseCase,
    required this.getCurrentUserUseCase,
  }) : super(const AsyncValue.loading()) {
    _init();
  }

  void _init() {
    final user = getCurrentUserUseCase();
    state = AsyncValue.data(user);
  }

  Future<void> signIn({required String email, required String password}) async {
    state = const AsyncValue.loading();
    try {
      final user = await signInUseCase(email, password);
      state = AsyncValue.data(user);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  Future<void> signOut() async {
    state = const AsyncValue.loading();
    try {
      await signOutUseCase();
      state = const AsyncValue.data(null);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}