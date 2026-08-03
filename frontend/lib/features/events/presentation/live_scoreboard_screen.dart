import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/events/domain/event_model.dart';
import 'package:kickoff/features/events/domain/event_member_model.dart';
import 'package:kickoff/features/events/domain/match_log_model.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';

class LiveScoreboardScreen extends ConsumerWidget {
  final String eventId;

  const LiveScoreboardScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailsProvider(eventId));
    final rosterAsync = ref.watch(eventRosterProvider(eventId));
    final logsAsync = ref.watch(matchLogsProvider(eventId));

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A), // Stadium dark background
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Match Scoreboard', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.pop(),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white),
            onPressed: () {
              ref.invalidate(eventDetailsProvider(eventId));
              ref.invalidate(eventRosterProvider(eventId));
              ref.invalidate(matchLogsProvider(eventId));
            },
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          final isCompleted = event.status == EventStatus.completed;

          return rosterAsync.when(
            data: (roster) {
              final teamA = roster.where((m) => m.team == RosterTeam.teamA).toList();
              final teamB = roster.where((m) => m.team == RosterTeam.teamB).toList();

              return Column(
                children: [
                  // 1. Stadium Score Card Banner
                  _buildStadiumScoreCard(context, event),
                  const SizedBox(height: 12),

                  // 2. VIP Highlights Panel (Top Scorer)
                  logsAsync.when(
                    data: (logs) => _buildVipHighlights(logs, roster),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),

                  // 3. Scoreboard Roster & Live Timeline Tabs
                  Expanded(
                    child: DefaultTabController(
                      length: 2,
                      child: Column(
                        children: [
                          const TabBar(
                            indicatorColor: AppTheme.accentGreen,
                            labelColor: Colors.white,
                            unselectedLabelColor: Colors.grey,
                            tabs: [
                              Tab(text: 'Rosters', icon: Icon(Icons.people, size: 18)),
                              Tab(text: 'Timeline Logs', icon: Icon(Icons.history, size: 18)),
                            ],
                          ),
                          Expanded(
                            child: TabBarView(
                              children: [
                                // Rosters Tab
                                SingleChildScrollView(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(child: _buildRosterView('TEAM A', teamA, Colors.blue.shade400)),
                                      const SizedBox(width: 16),
                                      Expanded(child: _buildRosterView('TEAM B', teamB, Colors.red.shade400)),
                                    ],
                                  ),
                                ),

                                // Timeline Tab
                                logsAsync.when(
                                  data: (logs) {
                                    if (logs.isEmpty) {
                                      return const Center(
                                        child: Text(
                                          'No events logged yet.',
                                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                                        ),
                                      );
                                    }
                                    return _buildTimelineLogs(logs);
                                  },
                                  loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
                                  error: (err, _) => Center(
                                    child: Text('Error loading logs: $err', style: const TextStyle(color: Colors.white)),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
            error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: Colors.green)),
        error: (err, _) => Center(child: Text('Error: $err', style: const TextStyle(color: Colors.white))),
      ),
    );
  }

  Widget _buildStadiumScoreCard(BuildContext context, EventModel event) {
    final isCricket = event.sport == 'Cricket';
    final isCompleted = event.status == EventStatus.completed;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10)),
        ],
        gradient: LinearGradient(
          colors: [const Color(0xFF1E4D2B).withOpacity(0.5), const Color(0xFF0F172A)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCompleted ? Colors.green.withOpacity(0.2) : Colors.red.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  isCompleted ? 'COMPLETED' : 'LIVE',
                  style: TextStyle(
                    color: isCompleted ? Colors.green : Colors.red,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Text(
                event.sport.toUpperCase(),
                style: const TextStyle(color: Colors.grey, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1.2),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Team A Name & Logo
              Expanded(
                child: Column(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.blue,
                      radius: 20,
                      child: Text('A', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'TEAM A',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),

              // Scores
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    isCricket
                        ? '${event.teamAScore}/${event.teamAWickets}'
                        : '${event.teamAScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16),
                    child: Text('-', style: TextStyle(color: Colors.grey, fontSize: 24, fontWeight: FontWeight.bold)),
                  ),
                  Text(
                    isCricket
                        ? '${event.teamBScore}/${event.teamBWickets}'
                        : '${event.teamBScore}',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                ],
              ),

              // Team B Name & Logo
              Expanded(
                child: Column(
                  children: [
                    const CircleAvatar(
                      backgroundColor: Colors.red,
                      radius: 20,
                      child: Text('B', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'TEAM B',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (isCricket) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Text(
                  '${(event.teamABalls / 6).floor()}.${event.teamABalls % 6} Overs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
                Text(
                  '${(event.teamBBalls / 6).floor()}.${event.teamBBalls % 6} Overs',
                  style: const TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ]
        ],
      ),
    );
  }

  Widget _buildVipHighlights(List<MatchLogModel> logs, List<EventMemberModel> roster) {
    // Dynamically calculate scorers / MVP scorers from logs
    final Map<String, int> scorerCounts = {};
    for (var log in logs) {
      if (log.logType == 'goal' && log.scorerMemberId != null && !log.message.contains('Score adjusted')) {
        scorerCounts[log.scorerMemberId!] = (scorerCounts[log.scorerMemberId!] ?? 0) + 1;
      }
    }

    if (scorerCounts.isEmpty) {
      return const SizedBox.shrink();
    }

    // Sort to find top scorer
    final sortedScorers = scorerCounts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topScorerId = sortedScorers.first.key;
    final topScorerGoals = sortedScorers.first.value;

    final topMember = roster.cast<EventMemberModel?>().firstWhere((m) => m?.id == topScorerId, orElse: () => null);
    if (topMember == null) return const SizedBox.shrink();

    final name = topMember.guestName ?? topMember.fullName ?? topMember.username ?? 'Striker';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.amber.shade900.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amber.shade800.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.workspace_premium, color: Colors.amber, size: 24),
          const SizedBox(width: 8),
          const Text('VIP TOP SCORER: ', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 12)),
          Expanded(
            child: Text(
              '$name ($topScorerGoals Goal${topScorerGoals > 1 ? 's' : ''})',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRosterView(String teamTitle, List<EventMemberModel> members, Color teamColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(teamTitle, style: TextStyle(color: teamColor, fontWeight: FontWeight.w900, fontSize: 14)),
        const Divider(color: Colors.grey, height: 16),
        if (members.isEmpty)
          const Text('No players assigned.', style: TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            itemBuilder: (context, index) {
              final member = members[index];
              final name = member.guestName ?? member.fullName ?? member.username ?? 'Athlete';
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6.0),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: teamColor.withOpacity(0.2),
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'P',
                        style: TextStyle(color: teamColor, fontWeight: FontWeight.bold, fontSize: 10),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        name,
                        style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildTimelineLogs(List<MatchLogModel> logs) {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: logs.length,
      itemBuilder: (context, index) {
        final log = logs[index];

        IconData icon = Icons.sports_soccer;
        Color iconColor = Colors.green;

        if (log.logType == 'wicket') {
          icon = Icons.cancel;
          iconColor = Colors.red;
        } else if (log.logType == 'extra') {
          icon = Icons.add_circle;
          iconColor = Colors.orange;
        } else if (log.logType == 'runs') {
          icon = Icons.sports_cricket;
          iconColor = Colors.teal;
        }

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon & vertical indicator line
              Column(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor: iconColor.withOpacity(0.15),
                    child: Icon(icon, color: iconColor, size: 16),
                  ),
                ],
              ),
              const SizedBox(width: 12),
              // Message & Time details
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(log.message, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 4),
                      Text(
                        '${log.createdAt.hour.toString().padLeft(2, '0')}:${log.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(color: Colors.grey, fontSize: 10),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
