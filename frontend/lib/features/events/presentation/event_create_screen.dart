import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/auth/presentation/providers/auth_providers.dart';
import 'package:kickoff/core/theme/app_theme.dart';
import 'package:kickoff/features/bookings/domain/booking_model.dart';
import 'package:kickoff/features/events/presentation/providers/event_providers.dart';
import 'package:kickoff/features/events/domain/event_model.dart';

class EventCreateScreen extends ConsumerStatefulWidget {
  final String bookingId;

  const EventCreateScreen({super.key, required this.bookingId});

  @override
  ConsumerState<EventCreateScreen> createState() => _EventCreateScreenState();
}

class _EventCreateScreenState extends ConsumerState<EventCreateScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  
  BookingModel? _booking;
  bool _isLoadingBooking = true;
  String? _bookingError;

  String _selectedSport = 'Football';
  EventPrivacy _privacy = EventPrivacy.public;
  int _capacity = 4;
  int _maxOvers = 10;

  @override
  void initState() {
    super.initState();
    _loadBookingDetails();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _loadBookingDetails() async {
    try {
      final apiClient = ref.read(apiClientProvider);
      final response = await apiClient.get('/api/bookings/${widget.bookingId}');
      
      if (mounted) {
        final booking = BookingModel.fromJson(response.data as Map<String, dynamic>);
        setState(() {
          _booking = booking;
          _isLoadingBooking = false;
          // Set default sport from turf sports if available
          if (booking.turf != null && booking.turf!.sports.isNotEmpty) {
            _selectedSport = booking.turf!.sports.first;
          } else {
            _selectedSport = 'Football';
          }
          _capacity = _getMinCapacity(_selectedSport);
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoadingBooking = false;
          _bookingError = 'Failed to load booking details: $e';
        });
      }
    }
  }

  int _getMinCapacity(String sport) {
    switch (sport) {
      case 'Football': return 4;
      case 'Cricket': return 4;
      case 'Badminton': return 2;
      case 'Basketball': return 2;
      case 'Tennis': return 2;
      default: return 2;
    }
  }

  int _getMaxCapacity(String sport) {
    switch (sport) {
      case 'Football': return 22;
      case 'Cricket': return 30;
      case 'Badminton': return 4;
      case 'Basketball': return 10;
      case 'Tennis': return 4;
      default: return 30;
    }
  }

  void _onSportChanged(String? sport) {
    if (sport == null) return;
    setState(() {
      _selectedSport = sport;
      final minCap = _getMinCapacity(sport);
      final maxCap = _getMaxCapacity(sport);
      if (_capacity < minCap) {
        _capacity = minCap;
      } else if (_capacity > maxCap) {
        _capacity = maxCap;
      }
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _booking == null) return;

    final actionNotifier = ref.read(eventActionProvider.notifier);
    final event = await actionNotifier.createEvent(
      bookingId: widget.bookingId,
      title: _titleController.text.trim(),
      description: _descController.text.trim().isEmpty ? null : _descController.text.trim(),
      sport: _selectedSport,
      privacy: _privacy.name,
      capacity: _capacity,
      maxOvers: _selectedSport == 'Cricket' ? _maxOvers : null,
    );

    if (event != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event hosted successfully!')),
      );
      context.go('/events/${event.id}');
    } else {
      final state = ref.read(eventActionProvider);
      if (state.error != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(state.error!), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final actionState = ref.watch(eventActionProvider);

    if (_isLoadingBooking) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
      );
    }

    if (_bookingError != null || _booking == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Host Event')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 64, color: Colors.red),
                const SizedBox(height: 16),
                Text(_bookingError ?? 'Booking not found', textAlign: TextAlign.center),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/'),
                  child: const Text('Back to Dashboard'),
                )
              ],
            ),
          ),
        ),
      );
    }

    final minCap = _getMinCapacity(_selectedSport);
    final maxCap = _getMaxCapacity(_selectedSport);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Host a Match', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Turf info banner
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.green.shade100),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sports_soccer, color: AppTheme.primaryGreen, size: 36),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _booking!.turf?.name ?? 'Turf Ground',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Slot: ${_booking!.slotDate} at ${_booking!.hours.map((h) => '$h:00').join(', ')}',
                            style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 28),

              // Title input
              Text('Match Title', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _titleController,
                maxLength: 100,
                decoration: InputDecoration(
                  hintText: 'e.g. 5v5 Friendly Kickoff',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter a title';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Description input
              Text('Description (Optional)', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              TextFormField(
                controller: _descController,
                maxLines: 3,
                maxLength: 500,
                decoration: InputDecoration(
                  hintText: 'Rules, skill levels, or instructions...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppTheme.primaryGreen, width: 2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Sport type selector
              Text('Sport Type', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedSport,
                decoration: InputDecoration(
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: (_booking!.turf?.sports ?? ['Football'])
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: _onSportChanged,
              ),
              if (_selectedSport == 'Cricket') ...[
                const SizedBox(height: 16),
                Text('Match Overs', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                DropdownButtonFormField<int>(
                  value: _maxOvers,
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: [5, 6, 7, 8, 9, 10]
                      .map((o) => DropdownMenuItem(value: o, child: Text('$o Overs')))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _maxOvers = val);
                  },
                ),
              ],
              const SizedBox(height: 20),

              // Privacy selector
              Text('Privacy Model', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Public Feed')),
                      selected: _privacy == EventPrivacy.public,
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) {
                        if (val) setState(() => _privacy = EventPrivacy.public);
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ChoiceChip(
                      label: const Center(child: Text('Private / Follows Only')),
                      selected: _privacy == EventPrivacy.private,
                      selectedColor: Colors.green.shade100,
                      onSelected: (val) {
                        if (val) setState(() => _privacy = EventPrivacy.private);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Capacity bounds
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Player Capacity', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                  Text('$_capacity Players', style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryGreen, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 8),
              Slider(
                value: _capacity.toDouble(),
                min: minCap.toDouble(),
                max: maxCap.toDouble(),
                divisions: (maxCap - minCap) > 0 ? (maxCap - minCap) : 1,
                activeColor: AppTheme.primaryGreen,
                label: '$_capacity',
                onChanged: (val) {
                  setState(() {
                    _capacity = val.round();
                  });
                },
              ),
              Text(
                'Allowed range for $_selectedSport: $minCap to $maxCap players',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
              const SizedBox(height: 40),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: actionState.isLoading ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: actionState.isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text('Host Match Room', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
