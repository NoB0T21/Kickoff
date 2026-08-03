import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/turfs/presentation/providers/turf_providers.dart';
import 'package:kickoff/features/turfs/domain/turf_model.dart';
import 'package:kickoff/features/turfs/domain/slot_model.dart';
import 'package:kickoff/features/bookings/presentation/providers/booking_providers.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class TurfDetailScreen extends ConsumerStatefulWidget {
  final String turfId;

  const TurfDetailScreen({super.key, required this.turfId});

  @override
  ConsumerState<TurfDetailScreen> createState() => _TurfDetailScreenState();
}

class _TurfDetailScreenState extends ConsumerState<TurfDetailScreen> {
  late DateTime _selectedDate;
  final Set<String> _selectedSlotIds = {};

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.now();
  }

  // Format date to show in carousel (e.g. "Mon\n31")
  String _formatDayLabel(DateTime date) {
    const weekdays = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final dayStr = weekdays[date.weekday % 7];
    return "$dayStr\n${date.day}";
  }

  bool _isSelectionContinuous(List<SlotModel> allSlots, Set<String> selectedIds) {
    if (selectedIds.isEmpty) return true;
    final selectedSlots = allSlots.where((s) => selectedIds.contains(s.id)).toList();
    selectedSlots.sort((a, b) => a.startHour.compareTo(b.startHour));
    for (int i = 0; i < selectedSlots.length - 1; i++) {
      if (selectedSlots[i].endHour != selectedSlots[i + 1].startHour) {
        return false;
      }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final searchState = ref.watch(turfListProvider);
    final theme = Theme.of(context);

    // Find the turf details from list state
    final turf = searchState.turfs.firstWhere(
      (t) => t.id == widget.turfId,
      orElse: () => TurfModel(
        id: widget.turfId,
        name: 'Kickoff Arena',
        locationName: 'Unknown Location',
        latitude: 0,
        longitude: 0,
        sports: ['Football'],
        imageUrls: [],
        hourlyRate: 80.00,
        openHour: 6,
        closeHour: 23,
      ),
    );

    // Fetch slots for this turf and date
    final dateStr = formatDate(_selectedDate);
    final slotsAsync = ref.watch(turfSlotsProvider(SlotsParams(turfId: widget.turfId, date: dateStr)));

    // Generate list of next 7 days for the carousel
    final days = List.generate(8, (i) => DateTime.now().add(Duration(days: i)));

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          // ── Silver AppBar with Banner Image ──
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                turf.name,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 18,
                  color: Colors.white,
                  shadows: [Shadow(color: Colors.black54, blurRadius: 4, offset: Offset(0, 1))],
                ),
              ),
              background: Image.network(
                turf.imageUrls.isNotEmpty ? turf.imageUrls[0] : 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80',
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) => Container(
                  color: Colors.grey.shade300,
                  child: const Icon(Icons.sports, size: 64, color: Colors.grey),
                ),
              ),
            ),
          ),

          // ── Turf Details Card ──
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Wrap(
                        spacing: 6,
                        children: turf.sports.map((sport) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryGreen.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sport,
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen),
                          ),
                        )).toList(),
                      ),
                      Text(
                        '₹${turf.hourlyRate.toStringAsFixed(0)}/hr',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: AppTheme.accentGreen),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      const Icon(Icons.location_on_outlined, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          turf.locationName,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.access_time_outlined, color: AppTheme.primaryGreen, size: 20),
                      const SizedBox(width: 6),
                      Text(
                        "Open: ${turf.openHour.toString().padLeft(2, '0')}:00 - ${turf.closeHour.toString().padLeft(2, '0')}:00",
                        style: TextStyle(fontSize: 14, color: Colors.grey.shade700, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Text('About Arena', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 6),
                  Text(
                    turf.description ?? 'A premium sports arena equipped with modern floodlights, high-grade synthetic turf, and player amenities.',
                    style: TextStyle(color: Colors.grey.shade600, height: 1.4, fontSize: 14),
                  ),
                  const Divider(height: 32),
                  
                  // ── Date Carousel ──
                  const Text('Select Date', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 10),
                  SizedBox(
                    height: 70,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: days.length,
                      itemBuilder: (context, index) {
                        final date = days[index];
                        final isSelected = DateUtils.isSameDay(date, _selectedDate);
                        
                        return Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                                _selectedSlotIds.clear();
                              });
                            },
                            child: Container(
                              width: 56,
                              decoration: BoxDecoration(
                                color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade100,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? AppTheme.primaryGreen : Colors.grey.shade200,
                                ),
                              ),
                              child: Center(
                                child: Text(
                                  _formatDayLabel(date),
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 13,
                                    height: 1.3,
                                    fontWeight: FontWeight.w700,
                                    color: isSelected ? Colors.white : Colors.grey.shade800,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // ── Slots Section ──
                  const Text('Available Slots', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppTheme.primaryGreen)),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),

          // Slots Grid (SliverGrid)
          slotsAsync.when(
            data: (slots) {
              if (slots.isEmpty) {
                return const SliverToBoxAdapter(
                  child: Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No slots generated for this date.', style: TextStyle(color: Colors.grey))),
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 2.2,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final slot = slots[index];
                      final isSelected = _selectedSlotIds.contains(slot.id);
                      
                      // Check states
                      final isBooked = slot.status == SlotStatus.booked;
                      final isLocked = slot.status == SlotStatus.locked;

                      // Check if slot start hour has already passed (if date is today)
                      final isToday = DateUtils.isSameDay(_selectedDate, DateTime.now());
                      final now = DateTime.now();
                      final isPastSlot = isToday && (slot.startHour <= now.hour);
                      
                      Color cardColor = Colors.white;
                      Color borderColor = Colors.green.shade600;
                      Widget slotIcon = const SizedBox.shrink();
                      Color textColor = Colors.green.shade800;

                      if (isBooked || isPastSlot) {
                        cardColor = Colors.grey.shade100;
                        borderColor = Colors.grey.shade300;
                        textColor = Colors.grey.shade500;
                        if (isPastSlot) {
                          slotIcon = Icon(Icons.block, size: 12, color: Colors.grey.shade400);
                        }
                      } else if (isLocked) {
                        cardColor = Colors.amber.shade50;
                        borderColor = Colors.amber.shade400;
                        textColor = Colors.amber.shade800;
                        slotIcon = const Icon(Icons.access_time_filled, size: 12, color: Colors.amber);
                      } else if (isSelected) {
                        cardColor = AppTheme.primaryGreen;
                        borderColor = AppTheme.primaryGreen;
                        textColor = Colors.white;
                      }

                      final startStr = slot.startHour.toString().padLeft(2, '0');
                      final endStr = slot.endHour.toString().padLeft(2, '0');

                      return GestureDetector(
                        onTap: (isBooked || isLocked || isPastSlot)
                            ? null
                            : () {
                                setState(() {
                                  if (isSelected) {
                                    final temp = Set<String>.from(_selectedSlotIds)..remove(slot.id);
                                    if (_isSelectionContinuous(slots, temp)) {
                                      _selectedSlotIds.remove(slot.id);
                                    } else {
                                      _selectedSlotIds.clear();
                                    }
                                  } else {
                                    if (_selectedSlotIds.isEmpty) {
                                      _selectedSlotIds.add(slot.id);
                                    } else {
                                      final temp = Set<String>.from(_selectedSlotIds)..add(slot.id);
                                      if (_isSelectionContinuous(slots, temp)) {
                                        _selectedSlotIds.add(slot.id);
                                      } else {
                                        _selectedSlotIds.clear();
                                        _selectedSlotIds.add(slot.id);
                                      }
                                    }
                                  }
                                });
                              },
                        child: Container(
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: borderColor, width: 1.5),
                          ),
                          child: Center(
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (slotIcon != const SizedBox.shrink()) ...[
                                  slotIcon,
                                  const SizedBox(width: 4),
                                ],
                                Text(
                                  "$startStr:00 - $endStr:00",
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                    color: textColor,
                                    decoration: isBooked ? TextDecoration.lineThrough : null,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                    childCount: slots.length,
                  ),
                ),
              );
            },
            loading: () => const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
              ),
            ),
            error: (err, _) => SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 40),
                child: Center(child: Text('Failed to load slots: $err', style: const TextStyle(color: Colors.red))),
              ),
            ),
          ),
          
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
      
      // ── Bottom Checkout Bar ──
      bottomSheet: _selectedSlotIds.isEmpty
          ? null
          : Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                boxShadow: [
                  BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -2)),
                ],
              ),
              child: Row(
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "${_selectedSlotIds.length} hour(s) selected",
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.grey),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "Total: ₹${(turf.hourlyRate * _selectedSlotIds.length).toStringAsFixed(0)}",
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppTheme.primaryGreen),
                      ),
                    ],
                  ),
                  const Spacer(),
                  SizedBox(
                    height: 48,
                    child: ElevatedButton(
                      onPressed: () => _lockAndProceed(context, turf),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.accentGreen,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: const Row(
                        children: [
                          Text('Lock & Pay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          SizedBox(width: 8),
                          Icon(Icons.arrow_forward, size: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  void _lockAndProceed(BuildContext context, TurfModel turf) async {
    // Show locking dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const AlertDialog(
        content: Row(
          children: [
            CircularProgressIndicator(color: AppTheme.primaryGreen),
            SizedBox(width: 24),
            Text('Acquiring temporary locks...', style: TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );

    // Release any existing active locks first to prevent lock conflicts
    await ref.read(bookingProvider.notifier).releaseActiveLocks();

    final lockResult = await ref.read(bookingProvider.notifier).lockSlots(_selectedSlotIds.toList());

    // Dismiss locking dialog
    if (mounted) Navigator.pop(context);

    if (lockResult.success) {
      if (mounted) {
        // Navigate to checkout screen with parameters
        context.push('/checkout', extra: {
          'turf_name': turf.name,
          'turf_id': turf.id,
          'slot_ids': _selectedSlotIds.toList(),
          'slot_date': formatDate(_selectedDate),
          'total_price': lockResult.totalPrice,
          'lock_expires_at': lockResult.lockExpiresAt,
        });
      }
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              lockResult.error?.contains('ACTIVE_LOCK_EXISTS') ?? false
                  ? 'Checkout session already active! Clear your locks or complete the booking.'
                  : 'Selected slots are no longer available. Please select other slots.',
            ),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
