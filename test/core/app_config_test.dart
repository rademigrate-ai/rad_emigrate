import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/config/app_config.dart';

void main() {
  test('AppConfig.isProduction is true only for production', () {
    expect(AppConfig.production.isProduction, isTrue);
    expect(AppConfig.development.isProduction, isFalse);
    expect(AppConfig.staging.isProduction, isFalse);
  });

  test('fromName resolves environments', () {
    expect(
      AppConfig.fromName('production').environment,
      AppEnvironment.production,
    );
    expect(
      AppConfig.fromName('staging').environment,
      AppEnvironment.staging,
    );
    expect(
      AppConfig.fromName('development').environment,
      AppEnvironment.development,
    );
    expect(
      AppConfig.fromName('unknown').environment,
      AppEnvironment.development,
    );
  });
}
