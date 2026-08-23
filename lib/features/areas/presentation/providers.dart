import '../data/repositories/area_repository_impl.dart';
import '../domain/entities/reception_area.dart';
import '../domain/repositories/area_repository.dart';

// Repository provider
final areaRepositoryProvider = Provider<AreaRepository>((ref) {
  return AreaRepositoryImpl(
    remoteDataSource: AreaRemoteDataSource(
      firestore: FirebaseFirestore.instance,
    ),
  );
});

// ViewModel providers
final areaListViewModelProvider = StateNotifierProvider<AreaListViewModel, AsyncValue<List<ReceptionArea>>>((ref) {
  return AreaListViewModel(
    repository: ref.watch(areaRepositoryProvider),
  );
});

final areaActionsProvider = Provider((ref) => AreaActions(
  repository: ref.watch(areaRepositoryProvider),
));