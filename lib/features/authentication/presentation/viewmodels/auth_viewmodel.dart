import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../domain/usecases/auth_usecases.dart';
import '../../core/errors/failures.dart';

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

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AsyncValue<UserDomain?>>(
  (ref) => AuthViewModel(
    signInUseCase: ref.watch(signInUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
  ),
);

final authStateProvider = StreamProvider<UserDomain?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentuserProvider = Provider<UserDomain?>((ref) {
  final asyncValue = ref.watch(authViewModelProvider);
  return asyncValue.valueOrNull;
});