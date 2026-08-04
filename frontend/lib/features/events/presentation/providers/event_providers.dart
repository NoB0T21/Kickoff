import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/features/events/domain/event_model.dart';
import 'package:kickoff/features/events/domain/event_member_model.dart';
import 'package:kickoff/features/events/domain/match_log_model.dart';
import 'package:kickoff/core/network/api_exceptions.dart';

// State model for event feed search filters
class EventFilters {
  final String? sport;
  final EventStatus status;

  EventFilters({
    this.sport,
    this.status = EventStatus.scheduled,
  });

  EventFilters copyWith({
    String? sport,
    EventStatus? status,
  }) {
    return EventFilters(
      sport: sport ?? this.sport,
      status: status ?? this.status,
    );
  }
}

final eventFiltersProvider = StateProvider<EventFilters>((ref) {
  return EventFilters();
});

// Event feed search state
class EventSearchState {
  final List<EventModel> events;
  final String? nextCursor;
  final bool isLoading;
  final String? error;

  EventSearchState({
    this.events = const [],
    this.nextCursor,
    this.isLoading = false,
    this.error,
  });
}

// Event feed search notifier
class EventSearchNotifier extends StateNotifier<EventSearchState> {
  final Ref _ref;

  EventSearchNotifier(this._ref) : super(EventSearchState()) {
    search();
  }

  Future<void> search({bool isLoadMore = false}) async {
    if (state.isLoading) return;

    final filters = _ref.read(eventFiltersProvider);
    final apiClient = _ref.read(apiClientProvider);

    if (isLoadMore && state.nextCursor == null) return;

    state = EventSearchState(
      events: isLoadMore ? state.events : [],
      nextCursor: isLoadMore ? state.nextCursor : null,
      isLoading: true,
    );

    try {
      final Map<String, dynamic> queryParams = {
        'status': filters.status.name,
        'limit': 20,
      };

      if (filters.sport != null && filters.sport!.isNotEmpty) {
        queryParams['sport'] = filters.sport;
      }
      if (isLoadMore && state.nextCursor != null) {
        queryParams['cursor'] = state.nextCursor;
      }

      final response = await apiClient.get('/api/events', queryParameters: queryParams);
      final data = response.data as Map<String, dynamic>;

      final List<dynamic> list = data['data'] ?? [];
      final List<EventModel> newEvents = list.map((item) => EventModel.fromJson(item)).toList();
      final String? cursor = data['next_cursor'] as String?;

      state = EventSearchState(
        events: isLoadMore ? [...state.events, ...newEvents] : newEvents,
        nextCursor: cursor,
        isLoading: false,
      );
    } catch (e) {
      state = EventSearchState(
        events: isLoadMore ? state.events : [],
        nextCursor: isLoadMore ? state.nextCursor : null,
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

// Event list notifier provider
final eventListProvider = StateNotifierProvider<EventSearchNotifier, EventSearchState>((ref) {
  return EventSearchNotifier(ref);
});

// Single Event details provider
final eventDetailsProvider = FutureProvider.autoDispose.family<EventModel, String>((ref, eventId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/events/$eventId');
  return EventModel.fromJson(response.data as Map<String, dynamic>);
});

// Event roster list provider
final eventRosterProvider = FutureProvider.autoDispose.family<List<EventMemberModel>, String>((ref, eventId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/events/$eventId/roster');
  final List<dynamic> list = response.data as List<dynamic>;
  return list.map((item) => EventMemberModel.fromJson(item)).toList();
});

// Match logs timeline provider
final matchLogsProvider = FutureProvider.autoDispose.family<List<MatchLogModel>, String>((ref, eventId) async {
  final apiClient = ref.read(apiClientProvider);
  final response = await apiClient.get('/api/events/$eventId/score/logs');
  final List<dynamic> list = response.data as List<dynamic>;
  return list.map((item) => MatchLogModel.fromJson(item)).toList();
});

// State model for action execution
class EventActionState {
  final bool isLoading;
  final String? error;
  final dynamic result;

  EventActionState({
    this.isLoading = false,
    this.error,
    this.result,
  });
}

// State notifier for event mutations
class EventActionNotifier extends StateNotifier<EventActionState> {
  final Ref _ref;

  EventActionNotifier(this._ref) : super(EventActionState());

  String? _getErrorMessage(dynamic e) {
    if (e is DioException && e.error is ApiException) {
      return (e.error as ApiException).message;
    }
    return e.toString();
  }

  Future<EventModel?> createEvent({
    required String bookingId,
    required String title,
    String? description,
    required String sport,
    required String privacy,
    required int capacity,
    int? maxOvers,
  }) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.post('/api/events', data: {
        'booking_id': bookingId,
        'title': title,
        'description': description,
        'sport': sport,
        'privacy': privacy,
        'capacity': capacity,
        if (maxOvers != null) 'max_overs': maxOvers,
      });
      final event = EventModel.fromJson(response.data as Map<String, dynamic>);
      state = EventActionState(isLoading: false, result: event);
      // Refresh feed
      _ref.read(eventListProvider.notifier).search();
      return event;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  Future<bool> joinEvent(String eventId) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/join', data: {});
      state = EventActionState(isLoading: false, result: true);
      // Invalidate target event cache to force UI refresh
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> leaveEvent(String eventId) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/leave', data: {});
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<EventMemberModel?> addGuest(String eventId, String guestName, {RosterTeam team = RosterTeam.unassigned}) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    String teamStr = 'unassigned';
    if (team == RosterTeam.teamA) teamStr = 'team_a';
    if (team == RosterTeam.teamB) teamStr = 'team_b';

    try {
      final response = await apiClient.post('/api/events/$eventId/roster/guest', data: {
        'guest_name': guestName,
        'team': teamStr,
      });
      final member = EventMemberModel.fromJson(response.data as Map<String, dynamic>);
      state = EventActionState(isLoading: false, result: member);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return member;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  Future<bool> deleteMember(String eventId, String memberId) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.delete('/api/events/$eventId/roster/$memberId');
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> assignTeam(String eventId, String memberId, RosterTeam team) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    String teamStr = 'unassigned';
    if (team == RosterTeam.teamA) teamStr = 'team_a';
    if (team == RosterTeam.teamB) teamStr = 'team_b';

    try {
      await apiClient.dio.put('/api/events/$eventId/roster/$memberId/team', data: {
        'team': teamStr,
      });
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<EventModel?> updateEvent(String eventId, {String? title, String? description, int? capacity}) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.dio.patch('/api/events/$eventId', data: {
        if (title != null) 'title': title,
        if (description != null) 'description': description,
        if (capacity != null) 'capacity': capacity,
      });
      final event = EventModel.fromJson(response.data as Map<String, dynamic>);
      state = EventActionState(isLoading: false, result: event);
      _ref.invalidate(eventDetailsProvider(eventId));
      return event;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  Future<bool> cancelEvent(String eventId) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/cancel', data: {});
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.read(eventListProvider.notifier).search();
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<EventModel?> resolveInvite(String token) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.get('/api/events/invite/$token');
      final event = EventModel.fromJson(response.data as Map<String, dynamic>);
      state = EventActionState(isLoading: false, result: event);
      return event;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }

  Future<bool> checkIn(String eventId, String qrCode) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/check-in', data: {
        'qr_check_in_code': qrCode,
      });
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> logScore(String eventId, String sport, Map<String, dynamic> details) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/score/log', data: {
        'sport': sport,
        'details': details,
      });
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      _ref.invalidate(matchLogsProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> setupToss(String eventId, String winnerTeam, String decision, int maxOvers) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/cricket/toss', data: {
        'toss_winner_team': winnerTeam,
        'toss_decision': decision,
        'max_overs': maxOvers,
      });
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<bool> setActiveCricketPlayers(String eventId, {String? strikerId, String? nonStrikerId, String? bowlerId}) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      await apiClient.post('/api/events/$eventId/cricket/players', data: {
        'striker_id': strikerId,
        'non_striker_id': nonStrikerId,
        'current_bowler_id': bowlerId,
      });
      state = EventActionState(isLoading: false, result: true);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      return true;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return false;
    }
  }

  Future<Map<String, dynamic>?> settleMatch(
    String eventId, {
    required String winningTeam,
    String? manOfTheMatchId,
    List<Map<String, dynamic>>? playerStats,
  }) async {
    state = EventActionState(isLoading: true);
    final apiClient = _ref.read(apiClientProvider);
    try {
      final response = await apiClient.post('/api/events/$eventId/settle', data: {
        'winning_team': winningTeam,
        if (manOfTheMatchId != null) 'man_of_the_match_id': manOfTheMatchId,
        if (playerStats != null) 'player_stats': playerStats,
      });
      final res = response.data as Map<String, dynamic>;
      state = EventActionState(isLoading: false, result: res);
      _ref.invalidate(eventDetailsProvider(eventId));
      _ref.invalidate(eventRosterProvider(eventId));
      _ref.invalidate(matchLogsProvider(eventId));
      _ref.read(eventListProvider.notifier).search();
      return res;
    } catch (e) {
      state = EventActionState(isLoading: false, error: _getErrorMessage(e));
      return null;
    }
  }
}

// Action executor notifier provider
final eventActionProvider = StateNotifierProvider<EventActionNotifier, EventActionState>((ref) {
  return EventActionNotifier(ref);
});
