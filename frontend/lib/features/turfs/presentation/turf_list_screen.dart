import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:kickoff/features/turfs/presentation/providers/turf_providers.dart';
import 'package:kickoff/features/turfs/domain/turf_model.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class TurfListScreen extends ConsumerWidget {
  const TurfListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(turfListProvider);
    final filters = ref.watch(turfFiltersProvider);
    final theme = Theme.of(context);

    // List of sports for the horizontal chips
    final sports = ['All', 'Football', 'Cricket', 'Badminton', 'Basketball', 'Tennis'];

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.sports_soccer, size: 24),
            SizedBox(width: 8),
            Text(
              'KICKOFF',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.5, fontSize: 20),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.my_location),
            onPressed: () {
              // Trigger a mock GPS location update (e.g. Stamford Bridge)
              ref.read(turfFiltersProvider.notifier).update((state) => state.copyWith(
                latitude: 51.4816,
                longitude: -0.1910,
              ));
              ref.read(turfListProvider.notifier).search();
              
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Updated location coordinates!'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Sticky Header: Search Bar & Location ──
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.location_on, color: AppTheme.accentGreen, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Showing courts near coordinates: (${filters.latitude.toStringAsFixed(4)}, ${filters.longitude.toStringAsFixed(4)})",
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // ── Sport Selector Chips (Horizontal Scroll) ──
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: sports.length,
              itemBuilder: (context, index) {
                final sport = sports[index];
                final isSelected = (sport == 'All' && filters.sport == null) || (filters.sport == sport);
                
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(
                      sport,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: isSelected ? Colors.white : Colors.grey.shade700,
                      ),
                    ),
                    selected: isSelected,
                    selectedColor: AppTheme.primaryGreen,
                    backgroundColor: Colors.grey.shade100,
                    checkmarkColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    onSelected: (selected) {
                      if (selected) {
                        ref.read(turfFiltersProvider.notifier).update((state) => state.copyWith(
                          sport: sport == 'All' ? null : sport,
                        ));
                        ref.read(turfListProvider.notifier).search();
                      }
                    },
                  ),
                );
              },
            ),
          ),

          // ── Turf Cards List ──
          Expanded(
            child: searchState.isLoading
                ? const Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen))
                : searchState.error != null
                    ? _buildErrorView(searchState.error!, ref)
                    : searchState.turfs.isEmpty
                        ? _buildEmptyView()
                        : NotificationListener<ScrollNotification>(
                            onNotification: (ScrollNotification scrollInfo) {
                              if (scrollInfo.metrics.pixels == scrollInfo.metrics.maxScrollExtent) {
                                ref.read(turfListProvider.notifier).search(isLoadMore: true);
                              }
                              return true;
                            },
                            child: RefreshIndicator(
                              onRefresh: () => ref.read(turfListProvider.notifier).search(),
                              child: ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                itemCount: searchState.turfs.length + (searchState.nextCursor != null ? 1 : 0),
                                itemBuilder: (context, index) {
                                  if (index == searchState.turfs.length) {
                                    return const Padding(
                                      padding: EdgeInsets.symmetric(vertical: 16),
                                      child: Center(child: CircularProgressIndicator(color: AppTheme.primaryGreen)),
                                    );
                                  }

                                  final turf = searchState.turfs[index];
                                  return Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: GestureDetector(
                                      onTap: () {
                                        context.push('/turfs/${turf.id}');
                                      },
                                      child: Container(
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(16),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(0.04),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(16),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Image Banner with overlays
                                              Stack(
                                                children: [
                                                  Image.network(
                                                    turf.imageUrls.isNotEmpty
                                                        ? turf.imageUrls[0]
                                                        : 'https://images.unsplash.com/photo-1508098682722-e99c43a406b2?q=80',
                                                    height: 180,
                                                    width: double.infinity,
                                                    fit: BoxFit.cover,
                                                    errorBuilder: (context, error, stackTrace) {
                                                      return Container(
                                                        height: 180,
                                                        color: Colors.grey.shade300,
                                                        child: const Icon(Icons.sports, size: 64, color: Colors.grey),
                                                      );
                                                    },
                                                  ),
                                                  Positioned(
                                                    top: 12,
                                                    right: 12,
                                                    child: Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                      decoration: BoxDecoration(
                                                        color: Colors.black.withOpacity(0.65),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Row(
                                                        mainAxisSize: MainAxisSize.min,
                                                        children: [
                                                          const Icon(Icons.star, color: Colors.amber, size: 14),
                                                          const SizedBox(width: 4),
                                                          Text(
                                                            '4.8', // Mock rating
                                                            style: TextStyle(
                                                              color: Colors.white,
                                                              fontWeight: FontWeight.w800,
                                                              fontSize: 12,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                  if (turf.distanceKm != null)
                                                    Positioned(
                                                      bottom: 12,
                                                      left: 12,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.65),
                                                          borderRadius: BorderRadius.circular(12),
                                                        ),
                                                        child: Row(
                                                          mainAxisSize: MainAxisSize.min,
                                                          children: [
                                                            const Icon(Icons.directions_run, color: Colors.white, size: 14),
                                                            const SizedBox(width: 4),
                                                            Text(
                                                              '${turf.distanceKm!.toStringAsFixed(1)} km away',
                                                              style: const TextStyle(
                                                                color: Colors.white,
                                                                fontWeight: FontWeight.w700,
                                                                fontSize: 12,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                    ),
                                                ],
                                              ),
                                              // Details
                                              Padding(
                                                padding: const EdgeInsets.all(16),
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                      children: [
                                                        Expanded(
                                                          child: Text(
                                                            turf.name,
                                                            style: const TextStyle(
                                                              fontSize: 18,
                                                              fontWeight: FontWeight.w800,
                                                              color: AppTheme.primaryGreen,
                                                            ),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                        Text(
                                                          '₹${turf.hourlyRate.toStringAsFixed(0)}/hr',
                                                          style: const TextStyle(
                                                            fontSize: 18,
                                                            fontWeight: FontWeight.w900,
                                                            color: AppTheme.accentGreen,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      children: [
                                                        Icon(Icons.location_on_outlined, color: Colors.grey.shade500, size: 16),
                                                        const SizedBox(width: 4),
                                                        Expanded(
                                                          child: Text(
                                                            turf.locationName,
                                                            style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                                                            maxLines: 1,
                                                            overflow: TextOverflow.ellipsis,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 10),
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
                                                          style: const TextStyle(
                                                            fontSize: 11,
                                                            fontWeight: FontWeight.w800,
                                                            color: AppTheme.primaryGreen,
                                                          ),
                                                        ),
                                                      )).toList(),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyView() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.sports_soccer, size: 64, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          const Text(
            'No Turfs Found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey),
          ),
          const SizedBox(height: 8),
          const Text('Try modifying your search filter.', style: TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }

  Widget _buildErrorView(String error, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text(
              'Error Loading Turfs',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(turfListProvider.notifier).search(),
              child: const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }
}
