import 'dart:async';
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
          // If match is completed, auto-pop to return to match room details screen
          if (event.status == EventStatus.completed) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) {
                if (Navigator.canPop(context)) {
                  Navigator.pop(context);
                } else {
                  context.go('/events/${event.id}');
                }
              }
            });
            return const Center(child: CircularProgressIndicator(color: Colors.green));
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

              return Column(
                children: [
                  // 1. Live Match Timer & Stadium Banner
                  _buildTimerSection(),
                  const SizedBox(height: 12),

                  // 2. Main Scoreboard Adjuster
                  _buildScoreboardSection(event, roster),
                  const SizedBox(height: 12),

                  // 3. Roster Management split columns
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        children: [
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
                                ),
                              ),
                            ],
                          ),
                          if (unassigned.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildUnassignedList(unassigned),
                          ],
                          const SizedBox(height: 100), // padding
                        ],
                      ),
                    ),
                  ),
                ],
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


  Widget _buildScoreboardSection(EventModel event, List<EventMemberModel> roster) {
    final isFootball = event.sport == 'Football';
    final isCricket = event.sport == 'Cricket';

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
                      '${(event.teamABalls / 6).floor()}.${event.teamABalls % 6} Overs',
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
                      '${(event.teamBBalls / 6).floor()}.${event.teamBBalls % 6} Overs',
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
          if (isCricket) ...[
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
            // Ball outcomes grid
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                _buildCricketLogBtn('Dot', () => _logCricketBall(event.currentBatting, 'dot', 0)),
                _buildCricketLogBtn('+1 Run', () => _logCricketBall(event.currentBatting, 'runs', 1)),
                _buildCricketLogBtn('+4 Run', () => _logCricketBall(event.currentBatting, 'runs', 4)),
                _buildCricketLogBtn('+6 Run', () => _logCricketBall(event.currentBatting, 'runs', 6)),
                _buildCricketLogBtn('Wicket', () => _logCricketWicket(event.currentBatting, roster)),
                _buildCricketLogBtn('Wide', () => _logCricketExtra(event.currentBatting, 'wide')),
                _buildCricketLogBtn('No Ball', () => _logCricketExtra(event.currentBatting, 'no_ball')),
              ],
            ),
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
  }) {
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
                if (count > 0) {
                  final scoreText = sport == 'Football'
                      ? '⚽ $count Goal${count > 1 ? 's' : ''}'
                      : (sport == 'Cricket'
                          ? '🏏 $count Run${count > 1 ? 's' : ''}'
                          : '⭐ $count Point${count > 1 ? 's' : ''}');
                  subtitleText = '$roleText • $scoreText';
                }

                return ListTile(
                  dense: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                  title: Text(
                    name,
                    style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitleText,
                    style: TextStyle(
                      color: member.profileId == null ? Colors.grey : AppTheme.accentGreen,
                      fontSize: 10,
                      fontWeight: count > 0 ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                    onPressed: () => onSwitch(member),
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

  Future<void> _logCricketWicket(String battingTeam, List<EventMemberModel> roster) async {
    final teamCode = battingTeam == 'team_a' ? 'A' : 'B';

    // Show dialog to attribute wicket dismissal
    String dismissal = 'bowled';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          title: const Text('Log Wicket', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
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
                  if (val != null) dismissal = val;
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
                await ref.read(eventActionProvider.notifier).logScore(widget.eventId, 'Cricket', {
                  'team': teamCode,
                  'outcome': 'wicket',
                  'runs': 0,
                  'dismissal_type': dismissal,
                });
              },
              child: const Text('Record Wicket', style: TextStyle(color: Colors.white)),
            ),
          ],
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
}

extension RosterFindExtension on List<EventMemberModel> {
  EventMemberModel? find(bool Function(EventMemberModel) test) {
    for (var element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}
