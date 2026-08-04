class AppConstants {
  // Replace with your development machine's actual LAN IP when testing on a physical device.
  // E.g. 'http://192.168.1.50:3000'
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.65.80.229:3000/', // Default fallback for Android emulators (if run locally)
  );
  // Supabase — used ONLY for Auth (token management, OAuth).
  // All data queries go through the backend API above.
  static const String supabaseUrl = String.fromEnvironment(
    'SUPABASE_URL',
    defaultValue: 'https://btcnbffupkhifxybcudb.supabase.co',
  );
  static const String supabaseAnonKey = String.fromEnvironment(
    'SUPABASE_ANON_KEY',
    defaultValue:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ0Y25iZmZ1cGtoaWZ4eWJjdWRiIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODUzNDIwNjAsImV4cCI6MjEwMDkxODA2MH0.gRTTi0Jmg6XIfgQy9ao4dB5gTPFunYRQCJjm23XpYyE',
  );

  // // Timeout durations
  // static const int connectTimeoutMs = 100000;
  // static const int receiveTimeoutMs = 100000;

  // Storage bucket names
  static const String avatarsBucket = 'avatars';
  static const String turfImagesBucket = 'turf-images';
}
