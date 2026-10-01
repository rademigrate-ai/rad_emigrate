/// Runtime environment for RAD Emigrate.
enum AppEnvironment {
  development,
  staging,
  production,
}

extension AppEnvironmentX on AppEnvironment {
  String get name {
    switch (this) {
      case AppEnvironment.development:
        return 'development';
      case AppEnvironment.staging:
        return 'staging';
      case AppEnvironment.production:
        return 'production';
    }
  }

  bool get isProduction => this == AppEnvironment.production;
  bool get isDevelopment => this == AppEnvironment.development;
}
