import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/features/turfs/domain/turf_model.dart';
import 'package:kickoff/features/turfs/domain/slot_model.dart';

// State model for turf search filters
class TurfFilters {
  final double latitude;
  final double longitude;
  final String? sport;
  final String date;

  TurfFilters({
    this.latitude = 51.4816, // Default to London (Stamford Bridge)
    this.longitude = -0.1910,
    this.sport,
    required this.date,
  });

  TurfFilters copyWith({
    double? latitude,
    double? longitude,
    String? sport,
    String? date,
  }) {
    return TurfFilters(
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      sport: sport ?? this.sport,
      date: date ?? this.date,
    );
  }
}

// Format DateTime to YYYY-MM-DD
String formatDate(DateTime date) {
  return "${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}";
}

// Search filters provider
final turfFiltersProvider = StateProvider<TurfFilters>((ref) {
  return TurfFilters(date: formatDate(DateTime.now()));
});

// Turf search result state
class TurfSearchState {
  final List<TurfModel> turfs;
  final String? nextCursor;
  final bool isLoading;
  final String? error;

  TurfSearchState({
    this.turfs = const [],
    this.nextCursor,
    this.isLoading = false,
    this.error,
  });
}

// Turf search state notifier
class TurfSearchNotifier extends StateNotifier<TurfSearchState> {
  final Ref _ref;

  TurfSearchNotifier(this._ref) : super(TurfSearchState()) {
    search();
  }

  Future<void> search({bool isLoadMore = false}) async {
    if (state.isLoading) return;

    final filters = _ref.read(turfFiltersProvider);
    final apiClient = _ref.read(apiClientProvider);

    if (isLoadMore && state.nextCursor == null) return;

    state = TurfSearchState(
      turfs: isLoadMore ? state.turfs : [],
      nextCursor: isLoadMore ? state.nextCursor : null,
      isLoading: true,
    );

    try {
      final Map<String, dynamic> queryParams = {
        'lat': filters.latitude,
        'lng': filters.longitude,
        'limit': 20,
      };

      if (filters.sport != null && filters.sport!.isNotEmpty) {
        queryParams['sport'] = filters.sport;
      }
      if (isLoadMore && state.nextCursor != null) {
        queryParams['cursor'] = state.nextCursor;
      }

      final response = await apiClient.get('/api/turfs', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;
      
      final List<dynamic> list = data['data'] ?? [];
      final List<TurfModel> newTurfs = list.map((item) => TurfModel.fromJson(item)).toList();
      final String? cursor = data['next_cursor'] as String?;

      state = TurfSearchState(
        turfs: isLoadMore ? [...state.turfs, ...newTurfs] : newTurfs,
        nextCursor: cursor,
        isLoading: false,
      );
    } catch (e) {
      state = TurfSearchState(
        turfs: isLoadMore ? state.turfs : [],
        nextCursor: isLoadMore ? state.nextCursor : null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// Turf list notifier provider
final turfListProvider = StateNotifierProvider<TurfSearchNotifier, TurfSearchState>((ref) {
  return TurfSearchNotifier(ref);
});

// Slots provider parameters
class SlotsParams {
  final String turfId;
  final String date;

  SlotsParams({required this.turfId, required this.date});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SlotsParams && runtimeType == other.runtimeType && turfId == other.turfId && date == other.date;

  @override
  int get hashCode => turfId.hashCode ^ date.hashCode;
}

// Slots fetch provider
final turfSlotsProvider = FutureProvider.autoDispose.family<List<SlotModel>, SlotsParams>((ref, params) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/turfs/${params.turfId}/slots', queryParameters: {
    'date': params.date,
  });

  final List<dynamic> list = response.data as List<dynamic>;
  return list.map((item) => SlotModel.fromJson(item)).toList();
});
