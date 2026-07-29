class AppConstants {
  // Replace with your development machine's actual LAN IP when testing on a physical device.
  // E.g. 'http://192.168.1.50:3000'
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:3000', // Default fallback for Android emulators (if run locally)
  );

  // Supabase keys and configuration if client-side direct calls are made
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: '');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  // Timeout durations
  static const int connectTimeoutMs = 10000;
  static const int receiveTimeoutMs = 10000;

  // Storage bucket names
  static const String avatarsBucket = 'avatars';
  static const String turfImagesBucket = 'turf-images';
}
