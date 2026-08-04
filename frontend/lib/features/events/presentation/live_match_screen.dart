import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/events/domain/event_model.dart';
import 'package:kickoff/features/events/domain/event_member_model.dart';
import 'package:kickoff/features/events/domain/match_log_model.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';

class LiveMatchScreen extends ConsumerStatefulWidget {
  final String eventId;

  const LiveMatchScreen({super.key, required this.eventId});

  @override
  ConsumerState<LiveMatchScreen> createState() => _LiveMatchScreenState();
}

class _LiveMatchScreenState extends ConsumerState<LiveMatchScreen> {
  // Timer state
  Timer? _timer;
  Duration _timeRemaining = Duration.zero;
  EventModel? _lastEvent;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer(DateTime endsAt) {
    _timer?.cancel();
    _timeRemaining = endsAt.difference(DateTime.now());
    if (_timeRemaining.isNegative) _timeRemaining = Duration.zero;
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (mounted) {
        setState(() {
          _timeRemaining = endsAt.difference(DateTime.now());
          if (_timeRemaining.isNegative) {
            _timeRemaining = Duration.zero;
            _timer?.cancel();
            ref.invalidate(eventDetailsProvider(widget.eventId));
          }
        });
      }
    });
  }

  String _formatTime() {
    if (_timeRemaining.isNegative || _timeRemaining == Duration.zero) {
      return "00:00 (Time Up)";
    }
    final minutes = _timeRemaining.inMinutes;
    final seconds = _timeRemaining.inSeconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final eventAsync = ref.watch(eventDetailsProvider(widget.eventId));
    final rosterAsync = ref.watch(eventRosterProvider(widget.eventId));
    final logsAsync = ref.watch(matchLogsProvider(widget.eventId));
    final actionState = ref.watch(eventActionProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Sleek deep navy/black stadium feel
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Live Host Dashboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.2),
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: Colors.red, width: 1),
            ),
            child: const Row(
              children: [
                Icon(Icons.fiber_manual_record, color: Colors.red, size: 10),
                SizedBox(width: 4),
                Text('LIVE', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 11)),
              ],
            ),
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          // If match is completed, render the completed match screen
          if (event.status == EventStatus.completed) {
            return rosterAsync.maybeWhen(
              data: (roster) => _buildMatchCompletedScreen(event, roster),
              orElse: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
            );
          }

          // Initialize countdown timer once
          if (_lastEvent?.id != event.id) {
            _lastEvent = event;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              _startTimer(event.endsAt);
            });
          }

          return rosterAsync.when(
            data: (roster) {
              final teamA = roster.where((m) => m.team == RosterTeam.teamA).toList();
              final teamB = roster.where((m) => m.team == RosterTeam.teamB).toList();
              final unassigned = roster.where((m) => m.team == RosterTeam.unassigned).toList();


              final Map<String, int> contributions = {};
              logsAsync.whenData((logs) {
                for (var log in logs) {
                  if (log.scorerMemberId != null && !log.message.contains('Score adjusted')) {
                    if (event.sport == 'Football' && log.logType == 'goal') {
                      contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + 1;
                    } else if (event.sport == 'Cricket') {
                      contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + log.runs;
                    } else if (log.logType == 'score_update') {
                      contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + 1;
                    }
                  }
                }
              });

              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Column(
                    children: [
                      // 1. Live Match Timer & Stadium Banner
                      _buildTimerSection(),
                      const SizedBox(height: 12),

                      // 2. Main Scoreboard Adjuster
                      _buildScoreboardSection(event, roster, logsAsync.value ?? []),
                      const SizedBox(height: 12),

                      // 3. Roster Management split columns
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: _buildTeamColumn(
                              title: 'TEAM A',
                              members: teamA,
                              color: Colors.blue.shade400,
                              onSwitch: (member) => _switchTeam(member, RosterTeam.teamB),
                              contributions: contributions,
                              sport: event.sport,
                              event: event,
                              roster: roster,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildTeamColumn(
                              title: 'TEAM B',
                              members: teamB,
                              color: Colors.red.shade400,
                              onSwitch: (member) => _switchTeam(member, RosterTeam.teamA),
                              contributions: contributions,
                              sport: event.sport,
                              event: event,
                              roster: roster,
                            ),
                          ),
                        ],
                      ),
                      if (unassigned.isNotEmpty) ...[
                        const SizedBox(height: 16),
                        _buildUnassignedList(unassigned),
                      ],
                      const SizedBox(height: 32),
                    ],
                  ),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
            error: (err, _) => Center(child: Text('Error loading roster: $err', style: const TextStyle(color: Colors.white))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(16),
        color: const Color(0xFF1E293B),
        child: SafeArea(
          child: ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade700,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {
              final logs = logsAsync.value ?? [];
              _showSettleDialog(context, logs);
            },
            child: const Text(
              'Complete Match & Submit Scores',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMatchCompletedScreen(EventModel event, List<EventMemberModel> roster) {
    final theme = Theme.of(context);
    final isCricket = event.sport == 'Cricket';
    
    String resultText = 'Draw';
    Color winnerColor = Colors.grey;
    if (event.teamAScore > event.teamBScore) {
      resultText = 'Team A Won the Match!';
      winnerColor = Colors.blue.shade400;
    } else if (event.teamBScore > event.teamAScore) {
      resultText = 'Team B Won the Match!';
      winnerColor = Colors.red.shade400;
    } else {
      resultText = 'Match Ended in a Draw!';
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.emoji_events, color: Colors.amber, size: 80),
              const SizedBox(height: 16),
              const Text(
                'Match Completed',
                style: TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                resultText,
                style: TextStyle(color: winnerColor, fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),

              // Score Card Container
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade800),
                ),
                child: Column(
                  children: [
                    Text(
                      event.sport.toUpperCase(),
                      style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        // Team A
                        Column(
                          children: [
                            const Text('TEAM A', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              isCricket ? '${event.teamAScore}/${event.teamAWickets}' : '${event.teamAScore}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            if (isCricket)
                              Text(
                                '${(event.teamABalls / 6).floor()}.${event.teamABalls % 6} Ov',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                          ],
                        ),
                        const Text('VS', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
                        // Team B
                        Column(
                          children: [
                            const Text('TEAM B', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                            const SizedBox(height: 8),
                            Text(
                              isCricket ? '${event.teamBScore}/${event.teamBWickets}' : '${event.teamBScore}',
                              style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                            ),
                            if (isCricket)
                              Text(
                                '${(event.teamBBalls / 6).floor()}.${event.teamBBalls % 6} Ov',
                                style: const TextStyle(color: Colors.grey, fontSize: 12),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 48),

              // Action Buttons
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add, color: Colors.white),
                  label: const Text('Host a New Match Room', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/events/new?booking_id=${event.bookingId}'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.arrow_forward, color: Colors.white),
                  label: const Text('Go to Event Page', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.grey),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: () => context.go('/events/${event.id}'),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => context.go('/'),
                child: const Text('Back to Dashboard', style: TextStyle(color: Colors.grey)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimerSection() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          colors: [Colors.teal.shade900.withOpacity(0.4), const Color(0xFF0F172A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Column(
          children: [
            const Text(
              'BOOKING TIME REMAINING',
              style: TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.1),
            ),
            const SizedBox(height: 4),
            Text(
              _formatTime(),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
          ],
        ),
      ),
    );
  }


  Widget _buildScoreboardSection(EventModel event, List<EventMemberModel> roster, List<MatchLogModel> logs) {
    final isFootball = event.sport == 'Football';
    final isCricket = event.sport == 'Cricket';

    final battingTeam = event.currentBatting;
    final battingMembersNotOut = roster.where((m) =>
      (battingTeam == 'team_a' && m.team == RosterTeam.teamA) ||
      (battingTeam == 'team_b' && m.team == RosterTeam.teamB)
    ).where((m) => !m.isOut).toList();
    final isLastManStanding = battingMembersNotOut.length == 1;
    final isLineupIncomplete = isCricket && (
      event.strikerId == null ||
      (!isLastManStanding && event.nonStrikerId == null) ||
      event.currentBowlerId == null
    );

    // Determine first and second batting teams
    String firstBattingTeam = 'team_a';
    if (event.tossWinnerTeam == 'team_a') {
      firstBattingTeam = event.tossDecision == 'bat' ? 'team_a' : 'team_b';
    } else if (event.tossWinnerTeam == 'team_b') {
      firstBattingTeam = event.tossDecision == 'bat' ? 'team_b' : 'team_a';
    }
    final secondBattingTeam = firstBattingTeam == 'team_a' ? 'team_b' : 'team_a';

    final isSecondInnings = event.currentBatting == secondBattingTeam;
    final firstBattingScore = firstBattingTeam == 'team_a' ? event.teamAScore : event.teamBScore;
    final targetRuns = firstBattingScore + 1;
    
    final secondBattingScore = secondBattingTeam == 'team_a' ? event.teamAScore : event.teamBScore;
    final secondBattingWickets = secondBattingTeam == 'team_a' ? event.teamAWickets : event.teamBWickets;
    final secondBattingBalls = secondBattingTeam == 'team_a' ? event.teamABalls : event.teamBBalls;
    
    final hasChased = secondBattingScore >= targetRuns;
    final isAllOutOrOversFinished = (event.strikerId == null && event.nonStrikerId == null) || secondBattingBalls >= ((event.maxOvers ?? 10) * 6);
    
    final isMatchFinished = isCricket && event.tossWinnerTeam != null && isSecondInnings && (hasChased || isAllOutOrOversFinished);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade800, width: 1.5),
      ),
      child: Column(
        children: [
          // Score numbers row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Team A Score
              Column(
                children: [
                  const Text('TEAM A', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    isCricket
                        ? '${event.teamAScore}/${event.teamAWickets}'
                        : '${event.teamAScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                  ),
                  if (isCricket)
                    Text(
                      '${(event.teamABalls / 6).floor()}.${event.teamABalls % 6} / ${event.maxOvers} Overs',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
              const Text('VS', style: TextStyle(color: Colors.grey, fontSize: 18, fontWeight: FontWeight.bold)),
              // Team B Score
              Column(
                children: [
                  const Text('TEAM B', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
                  const SizedBox(height: 8),
                  Text(
                    isCricket
                        ? '${event.teamBScore}/${event.teamBWickets}'
                        : '${event.teamBScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 44, fontWeight: FontWeight.bold),
                  ),
                  if (isCricket)
                    Text(
                      '${(event.teamBBalls / 6).floor()}.${event.teamBBalls % 6} / ${event.maxOvers} Overs',
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                ],
              ),
            ],
          ),
          const Divider(height: 32, color: Colors.grey),

          // Action controller buttons
          if (isFootball)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreActionBtn(
                  label: '+ A Goal',
                  color: Colors.blue.shade700,
                  onPressed: () => _logFootballGoal(context, 'A', roster),
                ),
                _buildScoreActionBtn(
                  label: '+ B Goal',
                  color: Colors.red.shade700,
                  onPressed: () => _logFootballGoal(context, 'B', roster),
                ),
              ],
            ),
          if (isCricket && (event.tossWinnerTeam == null || event.tossDecision == null)) ...[
            const SizedBox(height: 16),
            const Icon(Icons.monetization_on, color: Colors.amber, size: 48),
            const SizedBox(height: 12),
            Text(
              event.tossWinnerTeam != null ? 'Winner Choice Required' : 'Toss Setup Required',
              style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              event.tossWinnerTeam != null
                  ? '${event.tossWinnerTeam == 'team_a' ? 'Team A' : 'Team B'} (previous winner) must choose to bat or bowl.'
                  : 'Conduct a coin flip to decide who bats first.',
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              icon: const Icon(Icons.swap_horizontal_circle, color: Colors.white),
              label: Text(
                event.tossWinnerTeam != null ? 'Select Bat / Bowl' : 'Perform Coin Flip',
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.teal,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () => _startTossFlow(event),
            ),
          ] else if (isLineupIncomplete) ...[
            const SizedBox(height: 16),
            const Text(
              'Set Active Player Lineup',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                if (event.strikerId == null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sports_cricket, size: 14, color: Colors.white),
                    label: const Text('Select Striker', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                    onPressed: () {
                      final battingTeam = event.currentBatting;
                      final teamMembers = roster.where((m) =>
                        m.team == RosterTeam.unassigned ||
                        (battingTeam == 'team_a' && m.team == RosterTeam.teamA) ||
                        (battingTeam == 'team_b' && m.team == RosterTeam.teamB)
                      ).where((m) => !m.isOut && m.id != event.nonStrikerId).toList();
                      _showPlayerSelectDialog(
                        title: 'Select Striker',
                        candidates: teamMembers,
                        onSelected: (m) => ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                          event.id,
                          strikerId: m.id,
                          nonStrikerId: event.nonStrikerId,
                          bowlerId: event.currentBowlerId,
                        ),
                      );
                    },
                  ),
                if (event.nonStrikerId == null && !isLastManStanding)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sports_cricket, size: 14, color: Colors.white),
                    label: const Text('Select Non-Striker', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                    onPressed: () {
                      final battingTeam = event.currentBatting;
                      final teamMembers = roster.where((m) =>
                        m.team == RosterTeam.unassigned ||
                        (battingTeam == 'team_a' && m.team == RosterTeam.teamA) ||
                        (battingTeam == 'team_b' && m.team == RosterTeam.teamB)
                      ).where((m) => !m.isOut && m.id != event.strikerId).toList();
                      _showPlayerSelectDialog(
                        title: 'Select Non-Striker',
                        candidates: teamMembers,
                        onSelected: (m) => ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                          event.id,
                          strikerId: event.strikerId,
                          nonStrikerId: m.id,
                          bowlerId: event.currentBowlerId,
                        ),
                      );
                    },
                  ),
                if (event.currentBowlerId == null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.sports_baseball, size: 14, color: Colors.white),
                    label: const Text('Select Bowler', style: TextStyle(fontSize: 12, color: Colors.white)),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                    onPressed: () {
                      final fieldingTeam = event.currentBatting == 'team_a' ? 'team_b' : 'team_a';
                      final teamMembers = roster.where((m) =>
                        m.team == RosterTeam.unassigned ||
                        (fieldingTeam == 'team_a' && m.team == RosterTeam.teamA) ||
                        (fieldingTeam == 'team_b' && m.team == RosterTeam.teamB)
                      ).where((m) => m.id != event.strikerId && m.id != event.nonStrikerId).toList();
                      _showPlayerSelectDialog(
                        title: 'Select Bowler',
                        candidates: teamMembers,
                        onSelected: (m) => ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                          event.id,
                          strikerId: event.strikerId,
                          nonStrikerId: event.nonStrikerId,
                          bowlerId: m.id,
                        ),
                      );
                    },
                  ),
              ],
            ),
          ] else if (isCricket) ...[
            // Current batting side indicator
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Current Batting: ', style: TextStyle(color: Colors.grey, fontSize: 13)),
                Text(
                  event.currentBatting == 'team_a' ? 'Team A' : 'Team B',
                  style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold, fontSize: 13),
                ),
                IconButton(
                  icon: const Icon(Icons.swap_calls, color: Colors.teal, size: 18),
                  tooltip: 'Swap Batting Side',
                  onPressed: () => _toggleCricketBatting(event.currentBatting),
                ),
              ],
            ),
            const SizedBox(height: 8),
            // Display active striker, non-striker, bowler names and stats
            () {
              final strikerModel = roster.where((m) => m.id == event.strikerId).firstOrNull;
              final nonStrikerModel = roster.where((m) => m.id == event.nonStrikerId).firstOrNull;
              final bowlerModel = roster.where((m) => m.id == event.currentBowlerId).firstOrNull;

              final strikerName = strikerModel?.guestName ?? strikerModel?.fullName ?? strikerModel?.username ?? 'Striker';
              final nonStrikerName = isLastManStanding ? 'N/A' : (nonStrikerModel?.guestName ?? nonStrikerModel?.fullName ?? nonStrikerModel?.username ?? 'Non-Striker');
              final bowlerName = bowlerModel?.guestName ?? bowlerModel?.fullName ?? bowlerModel?.username ?? 'Bowler';

              return Container(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🏏 Striker: $strikerName (${strikerModel?.battingRuns ?? 0} runs, ${strikerModel?.ballsFaced ?? 0} balls)',
                          style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          isLastManStanding
                              ? 'Last Man Standing'
                              : 'Non-Striker: $nonStrikerName (${nonStrikerModel?.battingRuns ?? 0} runs, ${nonStrikerModel?.ballsFaced ?? 0} balls)',
                          style: const TextStyle(color: Colors.grey, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '🥎 Bowler: $bowlerName',
                          style: const TextStyle(color: Colors.white70, fontSize: 11),
                        ),
                        Text(
                          'Bowler Over Stats: R:${bowlerModel?.bowlerRuns ?? 0} W:${bowlerModel?.bowlerWickets ?? 0} (${((bowlerModel?.bowlerBalls ?? 0)/6).floor()}.${(bowlerModel?.bowlerBalls ?? 0)%6} Ov)',
                          style: const TextStyle(color: Colors.grey, fontSize: 10),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            }(),
            const SizedBox(height: 12),
            // Ball outcomes grid
            if (isMatchFinished) ...[
              Container(
                margin: const EdgeInsets.symmetric(vertical: 8),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade600, width: 1.5),
                ),
                child: Column(
                  children: [
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.emoji_events, color: Colors.amber, size: 24),
                        SizedBox(width: 8),
                        Text(
                          'Match Finished!',
                          style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasChased
                          ? 'Chasing team (${secondBattingTeam == 'team_a' ? 'Team A' : 'Team B'}) successfully chased target!'
                          : 'Fielding team (${firstBattingTeam == 'team_a' ? 'Team A' : 'Team B'}) defended score!',
                      style: const TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton.icon(
                      icon: const Icon(Icons.check_circle, color: Colors.white),
                      label: const Text('Complete & Settle Match Now', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green.shade700,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: () {
                        _showSettleDialog(context, logs);
                      },
                    ),
                  ],
                ),
              ),
            ] else ...[
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _buildCricketLogBtn('Dot', () => _logCricketBall(event.currentBatting, 'dot', 0)),
                  _buildCricketLogBtn('+1 Run', () => _logCricketBall(event.currentBatting, 'runs', 1)),
                  _buildCricketLogBtn('+4 Run', () => _logCricketBall(event.currentBatting, 'runs', 4)),
                  _buildCricketLogBtn('+6 Run', () => _logCricketBall(event.currentBatting, 'runs', 6)),
                  _buildCricketLogBtn('Wicket', () => _logCricketWicket(event.currentBatting, roster, event)),
                  _buildCricketLogBtn('Wide', () => _logCricketExtra(event.currentBatting, 'wide')),
                  _buildCricketLogBtn('No Ball', () => _logCricketExtra(event.currentBatting, 'no_ball')),
                ],
              ),
            ],
          ],
          if (!isFootball && !isCricket)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildScoreActionBtn(
                  label: '+ A Point',
                  color: Colors.blue.shade700,
                  onPressed: () => _logGenericPoint('A', roster),
                ),
                _buildScoreActionBtn(
                  label: '+ B Point',
                  color: Colors.red.shade700,
                  onPressed: () => _logGenericPoint('B', roster),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Widget _buildScoreActionBtn({required String label, required Color color, required VoidCallback onPressed}) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }

  Widget _buildCricketLogBtn(String label, VoidCallback onPressed) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        foregroundColor: Colors.white,
        side: BorderSide(color: Colors.grey.shade700),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: onPressed,
      child: Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildTeamColumn({
    required String title,
    required List<EventMemberModel> members,
    required Color color,
    required Function(EventMemberModel) onSwitch,
    required Map<String, int> contributions,
    required String sport,
    required EventModel event,
    required List<EventMemberModel> roster,
  }) {
    final battingTeam = event.currentBatting;
    final battingMembersNotOut = roster.where((m) =>
      (battingTeam == 'team_a' && m.team == RosterTeam.teamA) ||
      (battingTeam == 'team_b' && m.team == RosterTeam.teamB)
    ).where((m) => !m.isOut).toList();
    final isLastManStanding = battingMembersNotOut.length == 1;

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Text(
              '$title (${members.length})',
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          if (members.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Text('No players', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic)),
              ),
            )
          else
            ListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: members.length,
              itemBuilder: (context, index) {
                final member = members[index];
                final name = member.guestName ?? member.fullName ?? member.username ?? 'Guest';
                final count = contributions[member.id] ?? 0;
                final roleText = member.profileId == null ? 'Guest' : 'Athlete';

                String subtitleText = roleText;
                Widget? titleTrailing;

                if (sport == 'Cricket') {
                  final battingTeam = event.currentBatting;
                  final isBatting = (battingTeam == 'team_a' && member.team == RosterTeam.teamA) ||
                      (battingTeam == 'team_b' && member.team == RosterTeam.teamB);

                  if (isBatting) {
                    if (member.id == event.strikerId) {
                      titleTrailing = const Icon(Icons.sports_cricket, color: Colors.teal, size: 16);
                      subtitleText = '$roleText • 🏏 ${member.battingRuns}(${member.ballsFaced}) • Striker';
                    } else if (member.id == event.nonStrikerId) {
                      titleTrailing = const Icon(Icons.sports_cricket, color: Colors.grey, size: 16);
                      subtitleText = '$roleText • 🏏 ${member.battingRuns}(${member.ballsFaced}) • Non-Striker';
                    } else if (member.isOut) {
                      subtitleText = '$roleText • OUT • ${member.battingRuns}(${member.ballsFaced})';
                    } else {
                      subtitleText = '$roleText • DNB';
                    }
                  } else {
                    // Fielding team / Bowlers
                    if (member.id == event.currentBowlerId) {
                      titleTrailing = const Icon(Icons.sports_baseball, color: Colors.amber, size: 16);
                      subtitleText = '$roleText • 🥎 R:${member.bowlerRuns} W:${member.bowlerWickets} (${((member.bowlerBalls)/6).floor()}.${member.bowlerBalls%6} Ov)';
                    } else if (member.bowlerBalls > 0) {
                      subtitleText = '$roleText • 🥎 R:${member.bowlerRuns} W:${member.bowlerWickets} (${((member.bowlerBalls)/6).floor()}.${member.bowlerBalls%6} Ov)';
                    }
                  }
                } else {
                  if (count > 0) {
                    final scoreText = sport == 'Football'
                        ? '⚽ $count Goal${count > 1 ? 's' : ''}'
                        : (sport == 'Cricket'
                            ? '🏏 $count Run${count > 1 ? 's' : ''}'
                            : '⭐ $count Point${count > 1 ? 's' : ''}');
                    subtitleText = '$roleText • $scoreText';
                  }
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    dense: true,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    tileColor: Colors.white.withOpacity(0.03),
                    splashColor: color.withOpacity(0.15),
                    hoverColor: color.withOpacity(0.08),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Expanded(
                          child: Text(
                            name,
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (titleTrailing != null) titleTrailing,
                      ],
                    ),
                    subtitle: Text(
                      subtitleText,
                      style: TextStyle(
                        color: member.profileId == null ? Colors.grey : AppTheme.accentGreen,
                        fontSize: 10,
                        fontWeight: count > 0 || member.id == event.strikerId || member.id == event.currentBowlerId ? FontWeight.bold : FontWeight.normal,
                      ),
                    ),
                    onTap: () => _showPlayerActionMenu(member, event, roster),
                    trailing: IconButton(
                      icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                      onPressed: () => onSwitch(member),
                    ),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUnassignedList(List<EventMemberModel> unassigned) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('UNASSIGNED PLAYERS', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: unassigned.map((member) {
              final name = member.guestName ?? member.fullName ?? member.username ?? 'Guest';
              return ActionChip(
                backgroundColor: const Color(0xFF334155),
                label: Text(name, style: const TextStyle(color: Colors.white, fontSize: 12)),
                avatar: const Icon(Icons.swap_horiz, size: 14, color: Colors.grey),
                onPressed: () => _showAssignTeamMenu(member),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showAssignTeamMenu(EventMemberModel member) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: Icon(Icons.circle, color: Colors.blue),
                title: const Text('Move to Team A', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _switchTeam(member, RosterTeam.teamA);
                },
              ),
              ListTile(
                leading: Icon(Icons.circle, color: Colors.red),
                title: const Text('Move to Team B', style: TextStyle(color: Colors.white)),
                onTap: () {
                  Navigator.pop(context);
                  _switchTeam(member, RosterTeam.teamB);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _switchTeam(EventMemberModel member, RosterTeam newTeam) async {
    final notifier = ref.read(eventActionProvider.notifier);
    await notifier.assignTeam(widget.eventId, member.id, newTeam);
  }

  Future<void> _toggleCricketBatting(String current) async {
    final nextBatting = current == 'team_a' ? 'team_b' : 'team_a';
    final notifier = ref.read(eventActionProvider.notifier);
    // Directly update state
    await ref.read(apiClientProvider).post('/api/events/${widget.eventId}/score/log', data: {
      'sport': 'Cricket',
      'details': {
        'team': nextBatting == 'team_a' ? 'A' : 'B',
        'outcome': 'batting_swap',
        'runs': 0,
      }
    });
    ref.invalidate(eventDetailsProvider(widget.eventId));
  }

  Future<void> _logCricketBall(String battingTeam, String outcome, int runs) async {
    final notifier = ref.read(eventActionProvider.notifier);
    final teamCode = battingTeam == 'team_a' ? 'A' : 'B';
    await notifier.logScore(widget.eventId, 'Cricket', {
      'team': teamCode,
      'outcome': outcome,
      'runs': runs,
    });
  }

  Future<void> _logCricketExtra(String battingTeam, String type) async {
    final notifier = ref.read(eventActionProvider.notifier);
    final teamCode = battingTeam == 'team_a' ? 'A' : 'B';
    await notifier.logScore(widget.eventId, 'Cricket', {
      'team': teamCode,
      'outcome': 'extra',
      'runs': 0,
      'extra_type': type,
    });
  }

  Future<void> _logCricketWicket(String battingTeam, List<EventMemberModel> roster, EventModel event) async {
    final teamCode = battingTeam == 'team_a' ? 'A' : 'B';
    String dismissal = 'bowled';
    String? selectedOutMemberId = event.strikerId;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final strikerModel = roster.where((m) => m.id == event.strikerId).firstOrNull;
            final nonStrikerModel = roster.where((m) => m.id == event.nonStrikerId).firstOrNull;

            final strikerName = strikerModel?.guestName ?? strikerModel?.fullName ?? strikerModel?.username ?? 'Striker';
            final nonStrikerName = nonStrikerModel?.guestName ?? nonStrikerModel?.fullName ?? nonStrikerModel?.username ?? 'Non-Striker';

            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: const Text('Log Wicket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select dismissal type:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: dismissal,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'bowled', child: Text('Bowled')),
                      DropdownMenuItem(value: 'caught', child: Text('Caught')),
                      DropdownMenuItem(value: 'run_out', child: Text('Run Out')),
                      DropdownMenuItem(value: 'lbw', child: Text('LBW')),
                    ],
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          dismissal = val;
                        });
                      }
                    },
                  ),
                  if (dismissal == 'run_out') ...[
                    const SizedBox(height: 16),
                    const Text('Select player dismissed:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      value: selectedOutMemberId,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                      ),
                      items: [
                        if (event.strikerId != null)
                          DropdownMenuItem(value: event.strikerId, child: Text('$strikerName (Striker)')),
                        if (event.nonStrikerId != null)
                          DropdownMenuItem(value: event.nonStrikerId, child: Text('$nonStrikerName (Non-Striker)')),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          setModalState(() {
                            selectedOutMemberId = val;
                          });
                        }
                      },
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).logScore(widget.eventId, 'Cricket', {
                      'team': teamCode,
                      'outcome': 'wicket',
                      'runs': 0,
                      'dismissal_type': dismissal,
                      'out_member_id': dismissal == 'run_out' ? selectedOutMemberId : event.strikerId,
                    });
                  },
                  child: const Text('Record Wicket', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logFootballGoal(BuildContext context, String team, List<EventMemberModel> roster) async {
    final targetTeam = team == 'A' ? RosterTeam.teamA : RosterTeam.teamB;
    final teamMembers = roster.where((m) => m.team == targetTeam).toList();

    EventMemberModel? selectedScorer;
    if (teamMembers.isNotEmpty) {
      selectedScorer = teamMembers[0];
    }

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              title: Text('Goal Scorer - Team $team', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Scorer:', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  if (teamMembers.isEmpty)
                    const Text('No players on this team to attribute goal.', style: TextStyle(color: Colors.orange, fontSize: 12))
                  else
                    DropdownButtonFormField<EventMemberModel>(
                      value: selectedScorer,
                      dropdownColor: const Color(0xFF1E293B),
                      style: const TextStyle(color: Colors.white),
                      decoration: const InputDecoration(
                        focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                      ),
                      items: teamMembers.map((m) {
                        final name = m.guestName ?? m.fullName ?? m.username ?? 'Athlete';
                        return DropdownMenuItem(value: m, child: Text(name));
                      }).toList(),
                      onChanged: (val) {
                        setModalState(() {
                          selectedScorer = val;
                        });
                      },
                    ),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    Navigator.pop(context);
                    final notifier = ref.read(eventActionProvider.notifier);
                    final event = ref.read(eventDetailsProvider(widget.eventId)).value;
                    int minuteVal = 0;
                    if (event != null) {
                      final totalDuration = event.endsAt.difference(event.startsAt);
                      final elapsed = totalDuration - _timeRemaining;
                      minuteVal = elapsed.inMinutes;
                      if (minuteVal < 0) minuteVal = 0;
                    }

                    await notifier.logScore(widget.eventId, 'Football', {
                      'team': team,
                      'scorer_member_id': selectedScorer?.id,
                      'minute': minuteVal,
                    });
                  },
                  child: const Text('Record Goal', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _logGenericPoint(String team, List<EventMemberModel> roster) async {
    final notifier = ref.read(eventActionProvider.notifier);
    await notifier.logScore(widget.eventId, 'Generic', {
      'team': team,
    });
  }



  void _showSettleDialog(BuildContext context, List<MatchLogModel> logs) {
    final rosterAsync = ref.read(eventRosterProvider(widget.eventId));
    rosterAsync.whenData((roster) {
      final officialMembers = roster.where((m) => m.isOfficial && m.profileId != null).toList();

      String winningTeam = 'Draw';
      final event = ref.read(eventDetailsProvider(widget.eventId)).value;
      if (event != null) {
        if (event.teamAScore > event.teamBScore) winningTeam = 'A';
        if (event.teamBScore > event.teamAScore) winningTeam = 'B';
      }

      // Calculate player contributions inside dialog scope
      final Map<String, int> contributions = {};
      if (event != null) {
        for (var log in logs) {
          if (log.scorerMemberId != null && !log.message.contains('Score adjusted')) {
            if (event.sport == 'Football' && log.logType == 'goal') {
              contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + 1;
            } else if (event.sport == 'Cricket') {
              contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + log.runs;
            } else if (log.logType == 'score_update') {
              contributions[log.scorerMemberId!] = (contributions[log.scorerMemberId!] ?? 0) + 1;
            }
          }
        }
      }

      // Pre-select Man of the Match (MVP) to player with highest contributions
      EventMemberModel? selectedMotm;
      int maxContrib = -1;
      for (var member in officialMembers) {
        final count = contributions[member.id] ?? 0;
        if (count > maxContrib) {
          maxContrib = count;
          selectedMotm = member;
        }
      }

      // Fallback to first official member if no scores were logged
      if (selectedMotm == null && officialMembers.isNotEmpty) {
        selectedMotm = officialMembers[0];
      }

      showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setModalState) {
              return AlertDialog(
                backgroundColor: const Color(0xFF1E293B),
                title: const Text('Complete Match Settlement', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                content: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Winning Team (Auto-calculated):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF334155),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              winningTeam == 'A'
                                  ? '🏆 Team A Wins'
                                  : (winningTeam == 'B' ? '🏆 Team B Wins' : '🤝 Draw'),
                              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Text('Man of the Match (MVP):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                      if (officialMembers.isEmpty)
                        const Text('No official players present to vote MVP.', style: TextStyle(color: Colors.orange, fontSize: 12))
                      else
                        DropdownButtonFormField<EventMemberModel>(
                          value: selectedMotm,
                          dropdownColor: const Color(0xFF1E293B),
                          style: const TextStyle(color: Colors.white),
                          items: officialMembers.map((m) {
                            final name = m.fullName ?? m.username ?? 'Athlete';
                            return DropdownMenuItem(value: m, child: Text(name));
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedMotm = val;
                            });
                          },
                        ),
                    ],
                  ),
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green.shade700),
                    onPressed: () async {
                      Navigator.pop(context);

                      final response = await ref.read(eventActionProvider.notifier).settleMatch(
                            widget.eventId,
                            winningTeam: winningTeam,
                            manOfTheMatchId: selectedMotm?.profileId,
                          );

                      if (response != null && context.mounted) {
                        final eventStatus = response['event_status'] as String? ?? 'completed';
                        _showSuccessDialog(context, response['points_allocated'] ?? [], eventStatus);
                      }
                    },
                    child: const Text('Submit & Settle', style: TextStyle(color: Colors.white)),
                  ),
                ],
              );
            },
          );
        },
      );
    });
  }

  void _showSuccessDialog(BuildContext context, List<dynamic> pointsAllocated, String eventStatus) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green),
              SizedBox(width: 8),
              Text('Match Settled!', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eventStatus == 'completed'
                      ? 'Match completed successfully. Points have been enqueued for allocation:'
                      : 'Match points submitted successfully! A new match is starting in the same booking session.',
                  style: const TextStyle(color: Colors.grey, fontSize: 13),
                ),
                const SizedBox(height: 12),
                if (pointsAllocated.isEmpty)
                  const Text('No points to allocate.', style: TextStyle(color: Colors.white, fontSize: 13))
                else
                  Flexible(
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: pointsAllocated.length,
                      itemBuilder: (context, index) {
                        final alloc = pointsAllocated[index];
                        final pId = alloc['profile_id'] as String;
                        final pts = alloc['points'] as int;
                        final reason = alloc['reason'] as String;

                        // Find player name from roster
                        final roster = ref.read(eventRosterProvider(widget.eventId)).value;
                        final member = roster?.cast<EventMemberModel?>().firstWhere((m) => m?.profileId == pId, orElse: () => null);
                        final name = member?.fullName ?? member?.username ?? 'Athlete';

                        return ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                          subtitle: Text(reason, style: const TextStyle(color: Colors.grey, fontSize: 11)),
                          trailing: Text('+$pts PTS', style: const TextStyle(color: AppTheme.accentGreen, fontWeight: FontWeight.bold, fontSize: 13)),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
              onPressed: () {
                Navigator.pop(context); // Close dialog
                if (eventStatus == 'completed') {
                  context.pop(); // Pop LiveMatchScreen
                } else {
                  // Invalidate providers to reset scoreboard and reload clean event data
                  ref.invalidate(eventDetailsProvider(widget.eventId));
                  ref.invalidate(matchLogsProvider(widget.eventId));
                }
              },
              child: Text(
                eventStatus == 'completed' ? 'Back to Room' : 'Start Next Match',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startTossFlow(EventModel event) {
    final random = Random();
    final tossWinner = event.tossWinnerTeam ?? (random.nextBool() ? 'team_a' : 'team_b');
    final isPreviousWinner = event.tossWinnerTeam != null;
    final tossWinnerName = tossWinner == 'team_a' ? 'Team A' : 'Team B';
    int selectedOvers = 5;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF1E293B),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Row(
                children: [
                  const Icon(Icons.monetization_on, color: Colors.amber, size: 28),
                  const SizedBox(width: 8),
                  Text(
                    isPreviousWinner ? 'Previous Winner Choice' : 'Coin Flip / Toss',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isPreviousWinner
                        ? '🪙 $tossWinnerName chooses to bat or bowl:'
                        : '🪙 $tossWinnerName won the toss!',
                    style: const TextStyle(color: AppTheme.accentGreen, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  const Text('Select Match Overs (5 to 10):', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedOvers,
                    dropdownColor: const Color(0xFF1E293B),
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: Colors.teal)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    ),
                    items: [5, 6, 7, 8, 9, 10].map((o) {
                      return DropdownMenuItem(value: o, child: Text('$o Overs'));
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setModalState(() {
                          selectedOvers = val;
                        });
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'What does $tossWinnerName choose to do?',
                    style: const TextStyle(color: Colors.grey, fontSize: 13),
                  ),
                ],
              ),
              actions: [
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).setupToss(event.id, tossWinner, 'bat', selectedOvers);
                  },
                  child: const Text('Batting', style: TextStyle(color: Colors.white)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal.shade700),
                  onPressed: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).setupToss(event.id, tossWinner, 'bowl', selectedOvers);
                  },
                  child: const Text('Bowling', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _showPlayerSelectDialog({
    required String title,
    required List<EventMemberModel> candidates,
    required Function(EventMemberModel) onSelected,
  }) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: candidates.isEmpty
              ? const Text('No players available.', style: TextStyle(color: Colors.grey))
              : SizedBox(
                  width: double.maxFinite,
                  child: ListView.builder(
                    shrinkWrap: true,
                    itemCount: candidates.length,
                    itemBuilder: (context, index) {
                      final member = candidates[index];
                      final name = member.guestName ?? member.fullName ?? member.username ?? 'Guest';
                      return ListTile(
                        title: Text(name, style: const TextStyle(color: Colors.white)),
                        onTap: () {
                          Navigator.pop(context);
                          onSelected(member);
                        },
                      );
                    },
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    );
  }

  void _showPlayerActionMenu(EventMemberModel member, EventModel event, List<EventMemberModel> roster) {
    if (event.sport != 'Cricket') return;

    final battingTeam = event.currentBatting;
    final isBattingTeam = (battingTeam == 'team_a' && member.team == RosterTeam.teamA) ||
        (battingTeam == 'team_b' && member.team == RosterTeam.teamB);

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  member.guestName ?? member.fullName ?? member.username ?? 'Player',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              if (isBattingTeam && !member.isOut) ...[
                ListTile(
                  leading: const Icon(Icons.sports_cricket, color: Colors.teal),
                  title: const Text('Set as Striker', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                      event.id,
                      strikerId: member.id,
                      nonStrikerId: event.nonStrikerId,
                      bowlerId: event.currentBowlerId,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.sports_cricket, color: Colors.teal),
                  title: const Text('Set as Non-Striker', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                      event.id,
                      strikerId: event.strikerId,
                      nonStrikerId: member.id,
                      bowlerId: event.currentBowlerId,
                    );
                  },
                ),
              ],
              if (!isBattingTeam) ...[
                ListTile(
                  leading: const Icon(Icons.sports_baseball, color: Colors.teal),
                  title: const Text('Set as Bowler', style: TextStyle(color: Colors.white)),
                  onTap: () async {
                    Navigator.pop(context);
                    await ref.read(eventActionProvider.notifier).setActiveCricketPlayers(
                      event.id,
                      strikerId: event.strikerId,
                      nonStrikerId: event.nonStrikerId,
                      bowlerId: member.id,
                    );
                  },
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

extension RosterFindExtension on List<EventMemberModel> {
  EventMemberModel? find(bool Function(EventMemberModel) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
