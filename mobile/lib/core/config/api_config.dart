class ApiConfig {
  // Android emulator reaches the host PC through 10.0.2.2.
  // For a physical phone use the PC's LAN IP, e.g. http://192.168.1.10:8085
  static const String baseUrl = 'http://10.0.2.2:8085';

  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 20);
}