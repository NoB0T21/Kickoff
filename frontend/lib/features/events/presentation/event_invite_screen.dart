import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';

class EventInviteScreen extends ConsumerStatefulWidget {
  final String inviteToken;

  const EventInviteScreen({super.key, required this.inviteToken});

  @override
  ConsumerState<EventInviteScreen> createState() => _EventInviteScreenState();
}

class _EventInviteScreenState extends ConsumerState<EventInviteScreen> {
  bool _isResolving = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _resolveToken();
  }

  Future<void> _resolveToken() async {
    final actionNotifier = ref.read(eventActionProvider.notifier);
    final event = await actionNotifier.resolveInvite(widget.inviteToken);

    if (event != null && mounted) {
      context.go('/events/${event.id}');
    } else {
      if (mounted) {
        setState(() {
          _isResolving = false;
          _error = 'This invite link is invalid, expired, or the event has been cancelled.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(28.0),
          child: _isResolving
              ? const Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.sports_soccer, size: 64, color: AppTheme.primaryGreen),
                    SizedBox(height: 16),
                    Text(
                      'Resolving Invite Token...',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                    ),
                    SizedBox(height: 16),
                    CircularProgressIndicator(color: AppTheme.primaryGreen),
                  ],
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.link_off, size: 64, color: Colors.red),
                    const SizedBox(height: 20),
                    const Text(
                      'Invite Failed',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20, color: Colors.red),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _error ?? 'An error occurred while resolving your invite.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade600, height: 1.5, fontSize: 14),
                    ),
                    const SizedBox(height: 36),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () => context.go('/'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryGreen,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        ),
                        child: const Text(
                          'Back to Dashboard',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
