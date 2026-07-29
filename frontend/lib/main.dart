import 'package:flutter/material.dart';
import 'core/theme/app_theme.dart';

void main() {
  runApp(const KickoffApp());
}

class KickoffApp extends StatelessWidget {
  const KickoffApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kickoff',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.system,
      home: const MainLandingPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MainLandingPage extends StatelessWidget {
  const MainLandingPage({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('KICKOFF'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              // Hero Icon / Design
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: AppTheme.primaryGreen.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.sports_soccer,
                  size: 60,
                  color: AppTheme.primaryGreen,
                ),
              ),
              const SizedBox(height: 24),
              // App Title & Slogan
              Text(
                'Welcome to Kickoff',
                style: theme.textTheme.headlineMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Book Turfs • Join Matches • Level Up Your Stats',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              // Onboarding Call to Action
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Onboarding flow coming soon!'),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                  child: const Text('Get Started'),
                ),
              ),
              const SizedBox(height: 16),
              // Subtitle/Footer
              const Text(
                'Designed for Physical Device Testing',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
