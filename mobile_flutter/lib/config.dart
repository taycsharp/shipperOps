class AppConfig {
  /// Production API through Cloudflare Tunnel.
  /// Override at runtime with:
  /// flutter run --dart-define=API_BASE_URL=https://ship-api.dolasol.com
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://ship-api.dolasol.com',
  );

  /// GPS upload interval while shipper is available or idle.
  static const Duration availableInterval = Duration(seconds: 30);

  /// Faster GPS upload interval while shipper is carrying active orders.
  static const Duration busyInterval = Duration(seconds: 8);

  /// Maximum number of unsent GPS points kept on device for retry.
  static const int gpsPendingQueueLimit = 5;

  /// Network timeout for API calls.
  static const Duration apiTimeout = Duration(seconds: 20);
  static const Duration uploadTimeout = Duration(seconds: 60);
}
