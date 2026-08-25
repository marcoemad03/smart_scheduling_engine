import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Core
import 'package:reception_workforce_scheduler/core/constants/enums.dart';

// Features
import 'package:reception_workforce_scheduler/features/authentication/data/datasources/auth_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/authentication/domain/entities/user.dart';
import 'package:reception_workforce_scheduler/features/authentication/domain/repositories/auth_repository.dart';
import 'package:reception_workforce_scheduler/features/authentication/presentation/viewmodels/auth_viewmodel.dart';
import 'package:reception_workforce_scheduler/features/areas/data/datasources/area_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/areas/data/repositories_impl/area_repository_impl.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/repositories/area_repository.dart';
import 'package:reception_workforce_scheduler/features/areas/presentation/viewmodels/area_viewmodel.dart';

// Firebase providers
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);
final firebaseFirestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

// Authentication providers
final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(
    auth: ref.watch(firebaseAuthProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    remoteDataSource: ref.watch(authRemoteDataSourceProvider),
  );
});

final signInUseCaseProvider = Provider((ref) => SignInUseCase(ref.watch(authRepositoryProvider)));
final signOutUseCaseProvider = Provider((ref) => SignOutUseCase(ref.watch(authRepositoryProvider)));
final getCurrentUserUseCaseProvider = Provider((ref) => GetCurrentUserUseCase(ref.watch(authRepositoryProvider)));

final authViewModelProvider = StateNotifierProvider<AuthViewModel, AsyncValue<UserDomain?>>((ref) {
  return AuthViewModel(
    signInUseCase: ref.watch(signInUseCaseProvider),
    signOutUseCase: ref.watch(signOutUseCaseProvider),
    getCurrentUserUseCase: ref.watch(getCurrentUserUseCaseProvider),
  );
});

final authStateProvider = StreamProvider<UserDomain?>((ref) {
  return ref.watch(authRepositoryProvider).authStateChanges();
});

final currentUserProvider = Provider<UserDomain?>((ref) {
  final asyncValue = ref.watch(authViewModelProvider);
  return asyncValue.valueOrNull;
});

final userRoleProvider = FutureProvider<UserRole?>((ref) async {
  final user = ref.watch(currentUserProvider);
  return user?.role;
});

// Areas providers
final areaRemoteDataSourceProvider = Provider<AreaRemoteDataSource>((ref) {
  return AreaRemoteDataSource(firestore: ref.watch(firebaseFirestoreProvider));
});

final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(remoteDataSource: ref.watch(areaRemoteDataSourceProvider));
});

final areaListViewModelProvider = StateNotifierProvider<AreaListViewModel, AsyncValue<List<ReceptionArea>>>((ref) {
  return AreaListViewModel(repository: ref.watch(areaRepositoryProvider));
});

final areaActionsProvider = Provider((ref) => AreaActions(
  repository: ref.watch(areaRepositoryProvider),
));

// Global navigation key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();