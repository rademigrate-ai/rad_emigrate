import 'environment.dart';

// Re-export so importers of AppConfig see AppEnvironment and AppEnvironmentX
// (including isProduction) without a separate import.
export 'environment.dart';

/// Application configuration. No production secrets are hardcoded.
class AppConfig {
  const AppConfig({
    required this.environment,
    required this.apiBaseUrl,
    required this.enableLogging,
    required this.connectTimeout,
    required this.receiveTimeout,
    this.featureFlags = const {},
  });

  final AppEnvironment environment;
  final String apiBaseUrl;
  final bool enableLogging;
  final Duration connectTimeout;
  final Duration receiveTimeout;
  final Map<String, bool> featureFlags;

  /// Convenience: true when [environment] is production.
  bool get isProduction => environment.isProduction;

  bool isEnabled(String flag) => featureFlags[flag] ?? false;

  /// Default development configuration.
  static const development = AppConfig(
    environment: AppEnvironment.development,
    apiBaseUrl: 'https://api.dev.radvisa.local/v1',
    enableLogging: true,
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    featureFlags: {
      'ai_assistant': true,
      'document_upload': false,
      'payments': false,
    },
  );

  static const staging = AppConfig(
    environment: AppEnvironment.staging,
    apiBaseUrl: 'https://api.staging.radvisa.com/v1',
    enableLogging: true,
    connectTimeout: Duration(seconds: 15),
    receiveTimeout: Duration(seconds: 30),
    featureFlags: {
      'ai_assistant': true,
      'document_upload': true,
      'payments': false,
    },
  );

  static const production = AppConfig(
    environment: AppEnvironment.production,
    apiBaseUrl: 'https://api.radvisa.com/v1',
    enableLogging: false,
    connectTimeout: Duration(seconds: 20),
    receiveTimeout: Duration(seconds: 45),
    featureFlags: {
      'ai_assistant': true,
      'document_upload': true,
      'payments': true,
    },
  );

  /// Resolve config from compile-time environment string.
  static AppConfig fromName(String name) {
    switch (name) {
      case 'production':
        return production;
      case 'staging':
        return staging;
      default:
        return development;
    }
  }
}
