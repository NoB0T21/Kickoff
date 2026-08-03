import 'package:flutter/material.dart';
import 'package:kickoff/features/turfs/presentation/turf_list_screen.dart';
import 'package:kickoff/features/profile/presentation/profile_screen.dart';
import 'package:kickoff/features/bookings/presentation/my_bookings_screen.dart';
import 'package:kickoff/features/events/presentation/community_screen.dart';
import 'package:kickoff/core/theme/app_theme.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const TurfListScreen(),
    const MyBookingsScreen(),
    const CommunityScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: _screens,
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: (index) {
            setState(() {
              _currentIndex = index;
            });
          },
          selectedItemColor: AppTheme.primaryGreen,
          unselectedItemColor: Colors.grey.shade500,
          backgroundColor: theme.colorScheme.surface,
          showSelectedLabels: true,
          showUnselectedLabels: true,
          type: BottomNavigationBarType.fixed,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12),
          elevation: 0,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.explore_outlined),
              activeIcon: Icon(Icons.explore, color: AppTheme.primaryGreen),
              label: 'Discover',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.confirmation_num_outlined),
              activeIcon: Icon(Icons.confirmation_num, color: AppTheme.primaryGreen),
              label: 'Bookings',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.people_outline),
              activeIcon: Icon(Icons.people, color: AppTheme.primaryGreen),
              label: 'Community',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person_outline),
              activeIcon: Icon(Icons.person, color: AppTheme.primaryGreen),
              label: 'Profile',
            ),
          ],
        ),
      ),
    );
  }
}
