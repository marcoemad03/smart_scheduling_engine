import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:reception_workforce_scheduler/core/providers.dart';
import 'package:reception_workforce_scheduler/features/areas/domain/entities/reception_area.dart';
import 'package:reception_workforce_scheduler/features/staffing/data/datasources/staffing_remote_datasource.dart';
import 'package:reception_workforce_scheduler/features/staffing/data/repositories_impl/staffing_repository_impl.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/entities/staffing_requirement.dart';
import 'package:reception_workforce_scheduler/features/staffing/domain/repositories/staffing_repository.dart';

final staffingRemoteDataSourceProvider =
    Provider<StaffingRemoteDataSource>((ref) {
  return StaffingRemoteDataSource(
      firestore: ref.watch(firebaseFirestoreProvider));
});

final staffingRepositoryProvider = Provider<StaffingRepository>((ref) {
  return StaffingRepositoryImpl(
      remoteDataSource: ref.watch(staffingRemoteDataSourceProvider));
});

class StaffingState {
  final bool isLoading;
  final String? error;
  final List<StaffingRequirementEntity> requirements;
  final List<ReceptionArea> areas;

  const StaffingState({
    this.isLoading = false,
    this.error,
    this.requirements = const [],
    this.areas = const [],
  });

  StaffingState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
    List<StaffingRequirementEntity>? requirements,
    List<ReceptionArea>? areas,
  }) {
    return StaffingState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      requirements: requirements ?? this.requirements,
      areas: areas ?? this.areas,
    );
  }
}

class StaffingViewModel extends StateNotifier<StaffingState> {
  final StaffingRepository repository;
  final FirebaseFirestore firestore;

  StaffingViewModel({required this.repository, required this.firestore})
      : super(const StaffingState(isLoading: true)) {
    _subscribe();
    _loadAreas();
  }

  StreamSubscription? _subscription;

  void _subscribe() {
    _subscription = repository.getRequirements().listen(
      (requirements) {
        requirements.sort((a, b) {
          final byArea = a.areaId.compareTo(b.areaId);
          if (byArea != 0) return byArea;
          final byDay = a.dayOfWeek.compareTo(b.dayOfWeek);
          if (byDay != 0) return byDay;
          return a.shiftTemplateId.compareTo(b.shiftTemplateId);
        });
        state = state.copyWith(
          isLoading: false,
          clearError: true,
          requirements: requirements,
        );
      },
      onError: (e) =>
          state = state.copyWith(isLoading: false, error: e.toString()),
    );
  }

  Future<void> _loadAreas() async {
    try {
      final snapshot =
          await firestore.collection('areas').orderBy('orderIndex').get();
      final areas = snapshot.docs.map((doc) {
        final data = doc.data();
        return ReceptionArea(
          areaId: data['areaId'] as String? ?? doc.id,
          name: data['name'] as String? ?? '',
          description: data['description'] as String? ?? '',
          orderIndex: data['orderIndex'] as int? ?? 0,
          isActive: data['isActive'] as bool? ?? true,
        );
      }).toList();
      state = state.copyWith(areas: areas);
    } catch (_) {}
  }

  Future<void> saveRequirement(StaffingRequirementEntity requirement) async {
    await repository.saveRequirement(requirement);
  }

  Future<void> deleteRequirement(String requirementId) async {
    await repository.deleteRequirement(requirementId);
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}

final staffingViewModelProvider =
    StateNotifierProvider<StaffingViewModel, StaffingState>((ref) {
  return StaffingViewModel(
    repository: ref.watch(staffingRepositoryProvider),
    firestore: ref.watch(firebaseFirestoreProvider),
  );
});
