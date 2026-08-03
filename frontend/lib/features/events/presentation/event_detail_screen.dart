import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/profile/presentation/providers/profile_providers.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/events/domain/event_model.dart';
import 'package:kickoff/features/events/domain/event_member_model.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';

class EventDetailScreen extends ConsumerWidget {
  final String eventId;

  const EventDetailScreen({super.key, required this.eventId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final eventAsync = ref.watch(eventDetailsProvider(eventId));
    final rosterAsync = ref.watch(eventRosterProvider(eventId));
    final actionState = ref.watch(eventActionProvider);

    final currentUserId = ref.watch(profileProvider).profile?.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Match Room', style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Roster',
            onPressed: () {
              ref.invalidate(eventDetailsProvider(eventId));
              ref.invalidate(eventRosterProvider(eventId));
            },
          ),
          // If the event loads and current user is host, show check-in option
          eventAsync.when(
            data: (event) {
              if (event.hostId == currentUserId && event.status == EventStatus.scheduled) {
                return IconButton(
                  icon: const Icon(Icons.qr_code_scanner, color: AppTheme.primaryGreen),
                  tooltip: 'Show Check-in QR',
                  onPressed: () => _showQrModal(context, event.qrCheckInCode ?? ''),
                );
              }
              return const SizedBox.shrink();
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
      body: eventAsync.when(
        data: (event) {
          final isHost = event.hostId == currentUserId;

          return rosterAsync.when(
            data: (roster) {
              final isMember = roster.any((m) => m.profileId == currentUserId);
              final myRosterRow = roster.cast<EventMemberModel?>().firstWhere(
                (m) => m?.profileId == currentUserId,
                orElse: () => null,
              );

              final teamA = roster.where((m) => m.team == RosterTeam.teamA).toList();
              final teamB = roster.where((m) => m.team == RosterTeam.teamB).toList();
              final unassigned = roster.where((m) => m.team == RosterTeam.unassigned).toList();

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(eventDetailsProvider(eventId));
                  ref.invalidate(eventRosterProvider(eventId));
                  await ref.read(eventDetailsProvider(eventId).future);
                  await ref.read(eventRosterProvider(eventId).future);
                },
                child: SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Event info banner
                    _buildEventHeader(context, event, roster.length),
                    const SizedBox(height: 24),

                    // Action bar for joining/leaving/canceling
                    _buildActionBar(context, ref, event, isHost, isMember, roster.length, actionState),
                    const SizedBox(height: 28),

                    // Roster sections
                    _buildTeamRosterSection(
                      context,
                      ref,
                      title: 'Team A',
                      members: teamA,
                      color: Colors.blue.shade700,
                      bgColor: Colors.blue.shade100,
                      isHost: isHost,
                      eventStatus: event.status,
                    ),
                    const SizedBox(height: 16),

                    _buildTeamRosterSection(
                      context,
                      ref,
                      title: 'Team B',
                      members: teamB,
                      color: Colors.red.shade700,
                      bgColor: Colors.red.shade100,
                      isHost: isHost,
                      eventStatus: event.status,
                    ),
                    const SizedBox(height: 16),

                    _buildTeamRosterSection(
                      context,
                      ref,
                      title: 'Unassigned Players',
                      members: unassigned,
                      color: Colors.grey.shade700,
                      bgColor: Colors.grey.shade200,
                      isHost: isHost,
                      eventStatus: event.status,
                    ),

                    if (isHost && event.status == EventStatus.scheduled) ...[
                      const SizedBox(height: 32),
                      _buildHostAdminPanel(context, ref, event),
                    ],
                  ],
                ),
              ),
            );
          },
            loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
            error: (err, _) => Center(child: Text('Error loading roster: $err')),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
        error: (err, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.lock, size: 64, color: Colors.grey),
                const SizedBox(height: 16),
                const Text(
                  'Event Details Locked',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(height: 8),
                Text(
                  err.toString().contains('PRIVATE_EVENT')
                      ? 'This match is private. You must follow the host or use a valid invite link to view.'
                      : 'Match Room not found or inaccessible.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEventHeader(BuildContext context, EventModel event, int currentCount) {
    final theme = Theme.of(context);
    String statusLabel = event.status.name.toUpperCase();
    Color statusColor = Colors.orange;
    if (event.status == EventStatus.live) statusColor = Colors.red;
    if (event.status == EventStatus.completed) statusColor = Colors.green;
    if (event.status == EventStatus.cancelled) statusColor = Colors.grey;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  statusLabel,
                  style: TextStyle(color: statusColor, fontWeight: FontWeight.bold, fontSize: 11),
                ),
              ),
              Row(
                children: [
                  const Icon(Icons.people, color: Colors.grey, size: 16),
                  const SizedBox(width: 4),
                  Text('$currentCount / ${event.capacity}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (event.status == EventStatus.live || event.status == EventStatus.completed) ...[
            Center(
              child: Column(
                children: [
                  Text(
                    event.sport == 'Cricket'
                        ? '${event.teamAScore}/${event.teamAWickets} - ${event.teamBScore}/${event.teamBWickets}'
                        : '${event.teamAScore} - ${event.teamBScore}',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                  ),
                  const Text('TEAM A  vs  TEAM B', style: TextStyle(color: Colors.grey, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2)),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
          Text(
            event.title,
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          if (event.description != null && event.description!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              event.description!,
              style: TextStyle(color: Colors.grey.shade500, height: 1.4, fontSize: 13),
            ),
          ],
          const Divider(height: 24),
          _buildMetaRow(Icons.sports, 'Sport', event.sport),
          const SizedBox(height: 8),
          _buildMetaRow(Icons.location_on, 'Location', event.turfName ?? 'Turf Ground'),
          const SizedBox(height: 8),
          _buildMetaRow(
            Icons.access_time,
            'Time',
            '${event.startsAt.day}/${event.startsAt.month} ${event.startsAt.hour}:00 - ${event.endsAt.hour}:00',
          ),
          if (event.privacy == EventPrivacy.private) ...[
            const SizedBox(height: 8),
            _buildMetaRow(Icons.lock, 'Privacy', 'Private (Followers/Invite Only)', color: Colors.red.shade700),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaRow(IconData icon, String label, String value, {Color? color}) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color ?? Colors.grey.shade500),
        const SizedBox(width: 8),
        Text('$label: ', style: TextStyle(color: Colors.grey.shade500, fontSize: 13, fontWeight: FontWeight.w600)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: color ?? Colors.grey.shade700, fontSize: 13, fontWeight: FontWeight.w700),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildActionBar(
    BuildContext context,
    WidgetRef ref,
    EventModel event,
    bool isHost,
    bool isMember,
    int currentCount,
    EventActionState actionState,
  ) {
    if (event.status == EventStatus.live) {
      return Column(
        children: [
          if (isHost) ...[
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal.shade700,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.sports, color: Colors.white),
                label: const Text('Manage Live Match', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                onPressed: () => context.push('/events/${event.id}/live'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          SizedBox(
            width: double.infinity,
            height: 48,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: AppTheme.primaryGreen, width: 1.5),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.analytics, color: AppTheme.primaryGreen),
              label: const Text('View Live Scoreboard', style: TextStyle(color: AppTheme.primaryGreen, fontWeight: FontWeight.bold)),
              onPressed: () => context.push('/events/${event.id}/scoreboard'),
            ),
          ),
        ],
      );
    }

    if (event.status == EventStatus.completed) {
      return SizedBox(
        width: double.infinity,
        height: 48,
        child: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryGreen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.emoji_events, color: Colors.white),
          label: const Text('View Match Scoreboard & Stats', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onPressed: () => context.push('/events/${event.id}/scoreboard'),
        ),
      );
    }

    if (event.status == EventStatus.cancelled) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: Text(
            'This match has been cancelled.',
            style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
          ),
        ),
      );
    }

    final actionNotifier = ref.read(eventActionProvider.notifier);

    if (isHost) {
      return Row(
        children: [
          Expanded(
            child: ElevatedButton.icon(
              icon: const Icon(Icons.person_add, size: 18, color: Colors.white),
              label: const Text('Add Guest Player'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: () => _showAddGuestDialog(context, ref),
            ),
          ),
        ],
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 48,
      child: isMember
          ? OutlinedButton(
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.red),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: actionState.isLoading
                  ? null
                  : () async {
                      final success = await actionNotifier.leaveEvent(event.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('You have left the match roster.')),
                        );
                      } else {
                        final state = ref.read(eventActionProvider);
                        if (state.error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: actionState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.red),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.red),
                        SizedBox(width: 8),
                        Text('Leave Match Room', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                      ],
                    ),
            )
          : ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryGreen,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: (currentCount >= event.capacity || actionState.isLoading)
                  ? null
                  : () async {
                      final success = await actionNotifier.joinEvent(event.id);
                      if (success && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Joined match roster successfully!')),
                        );
                      } else {
                        final state = ref.read(eventActionProvider);
                        if (state.error != null && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
                          );
                        }
                      }
                    },
              child: actionState.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add, color: Colors.white),
                        SizedBox(width: 8),
                        Text('Join Match Roster', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ],
                    ),
            ),
    );
  }

  Widget _buildTeamRosterSection(
    BuildContext context,
    WidgetRef ref, {
    required String title,
    required List<EventMemberModel> members,
    required Color color,
    required Color bgColor,
    required bool isHost,
    required EventStatus eventStatus,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 14),
              ),
              Text(
                '${members.length} players',
                style: TextStyle(fontWeight: FontWeight.w600, color: color.withOpacity(0.8), fontSize: 12),
              ),
            ],
          ),
        ),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.onTertiary,
            border: Border.all(color: Theme.of(context).colorScheme.onTertiary),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
          ),
          child: members.isEmpty
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Center(
                    child: Text(
                      'No players assigned',
                      style: TextStyle(color: Colors.grey, fontSize: 13, fontStyle: FontStyle.italic),
                    ),
                  ),
                )
              : ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: members.length,
                  separatorBuilder: (context, index) => const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, index) {
                    final member = members[index];
                    final displayName = member.guestName ?? member.fullName ?? member.username ?? 'Athlete';
                    final isGuest = member.profileId == null;

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AppTheme.accentGreen.withOpacity(0.3),
                        child: Text(
                          displayName.isNotEmpty ? displayName[0].toUpperCase() : 'A',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.accentGreen, fontSize: 12),
                        ),
                      ),
                      title: Row(
                        children: [
                          Text(displayName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                          if (isGuest) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade200,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Text('GUEST', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)),
                            ),
                          ],
                        ],
                      ),
                      subtitle: member.username != null ? Text('@${member.username}', style: const TextStyle(fontSize: 11)) : null,
                      trailing: isHost && eventStatus != EventStatus.completed && eventStatus != EventStatus.cancelled
                          ? Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Team Selector Dropdown
                                DropdownButton<RosterTeam>(
                                  value: member.team,
                                  underline: const SizedBox.shrink(),
                                  icon: const Icon(Icons.swap_horiz, size: 16, color: Colors.grey),
                                  onChanged: (newTeam) async {
                                    if (newTeam != null) {
                                      await ref.read(eventActionProvider.notifier).assignTeam(eventId, member.id, newTeam);
                                    }
                                  },
                                  items: const [
                                    DropdownMenuItem(value: RosterTeam.unassigned, child: Text('Unassigned', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: RosterTeam.teamA, child: Text('Team A', style: TextStyle(fontSize: 11))),
                                    DropdownMenuItem(value: RosterTeam.teamB, child: Text('Team B', style: TextStyle(fontSize: 11))),
                                  ],
                                ),
                                // Delete member option
                                if (!member.isOfficial) ...[
                                  IconButton(
                                    icon: const Icon(Icons.close, size: 16, color: Colors.red),
                                    onPressed: () async {
                                      await ref.read(eventActionProvider.notifier).deleteMember(eventId, member.id);
                                    },
                                  ),
                                ],
                              ],
                            )
                          : null,
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildHostAdminPanel(BuildContext context, WidgetRef ref, EventModel event) {
    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.onTertiary,
      borderOnForeground: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Host Administration',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _showEditCapacityDialog(context, ref, event),
                    child: const Text('Edit Match Info'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _confirmCancelEvent(context, ref),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.shade700,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Cancel Match'),
                  ),
                ),
              ],
            ),
            if (event.privacy == EventPrivacy.private && event.inviteToken != null) ...[
              const Divider(height: 24),
              Row(
                children: [
                  const Icon(Icons.link, color: Colors.grey, size: 20),
                  const SizedBox(width: 8),
                  const Text('Invite Link Token:', style: TextStyle(fontSize: 12, color: Colors.grey)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SelectableText(
                      event.inviteToken!,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.primaryGreen),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showQrModal(BuildContext context, String qrCode) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text('Turf Check-in QR', style: TextStyle(fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Show this QR code to the turf manager when you arrive to start the match.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey, fontSize: 13),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade100),
                ),
                child: Image.network(
                  'https://api.qrserver.com/v1/create-qr-code/?size=200x200&data=$qrCode',
                  width: 200,
                  height: 200,
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return const SizedBox(
                      width: 200,
                      height: 200,
                      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Code: $qrCode',
                style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey.shade800, fontSize: 13),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  void _showAddGuestDialog(BuildContext context, WidgetRef ref) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add Guest Player'),
          content: TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: 'Enter guest player name',
              focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppTheme.primaryGreen)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              onPressed: () async {
                final name = controller.text.trim();
                if (name.isNotEmpty) {
                  Navigator.pop(context);
                  final result = await ref.read(eventActionProvider.notifier).addGuest(eventId, name);
                  if (result == null && context.mounted) {
                    final state = ref.read(eventActionProvider);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(state.error ?? 'Failed to add guest player.'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  } else if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Guest player added successfully!'),
                        backgroundColor: Colors.green,
                      ),
                    );
                  }
                }
              },
              child: const Text('Add Guest', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showEditCapacityDialog(BuildContext context, WidgetRef ref, EventModel event) {
    final titleController = TextEditingController(text: event.title);
    final descController = TextEditingController(text: event.description ?? '');
    final capController = TextEditingController(text: event.capacity.toString());

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Match Info'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(labelText: 'Title'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: descController,
                  maxLines: 2,
                  decoration: const InputDecoration(labelText: 'Description'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: capController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Player Capacity'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primaryGreen),
              onPressed: () async {
                final title = titleController.text.trim();
                final desc = descController.text.trim();
                final capacity = int.tryParse(capController.text.trim());

                if (title.isNotEmpty && capacity != null) {
                  final success = await ref.read(eventActionProvider.notifier).updateEvent(
                    eventId,
                    title: title,
                    description: desc.isEmpty ? null : desc,
                    capacity: capacity,
                  );

                  if (success != null && context.mounted) {
                    Navigator.pop(context);
                  } else {
                    final state = ref.read(eventActionProvider);
                    if (state.error != null && context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
                      );
                    }
                  }
                }
              },
              child: const Text('Save Changes', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _confirmCancelEvent(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Cancel Match?'),
          content: const Text(
            'Are you sure you want to cancel this match? This will remove all roster spots and notify the players.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Keep Match'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () async {
                final success = await ref.read(eventActionProvider.notifier).cancelEvent(eventId);
                if (success && context.mounted) {
                  Navigator.pop(context);
                  context.go('/');
                }
              },
              child: const Text('Cancel Match', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }
}
