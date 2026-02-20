

class ApiConstants {
  // Use 10.0.2.2 for Android Emulator, localhost for iOS/Web
static String get baseUrl {
    // Return your Railway URL (HTTPS is standard)
    return 'https://api.truthysystems.com'; 
  }

  static const String loginEndpoint = '/auth/login';
  static const String syncPushEndpoint = '/sync/push';
}