import '../config/app_config.dart';

/// Network-specific settings derived from [AppConfig].
class NetworkConfig {
  const NetworkConfig({
    required this.baseUrl,
    required this.connectTimeout,
    required this.receiveTimeout,
    required this.enableLogging,
  });

  final String baseUrl;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final bool enableLogging;

  factory NetworkConfig.fromAppConfig(AppConfig config) {
    return NetworkConfig(
      baseUrl: config.apiBaseUrl,
      connectTimeout: config.connectTimeout,
      receiveTimeout: config.receiveTimeout,
      enableLogging: config.enableLogging,
    );
  }
}
