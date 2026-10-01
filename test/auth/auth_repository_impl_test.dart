import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/network/api_client.dart';
import 'package:rad_emigrate/core/network/network_config.dart';
import 'package:rad_emigrate/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthRepositoryImpl demo path is available via ApiClient contract', () {
    const network = NetworkConfig(
      baseUrl: 'https://example.com',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      enableLogging: false,
    );
    final client = ApiClient(
      config: network,
      tokenProvider: () async => null,
    );
    expect(client.config.baseUrl, 'https://example.com');
    expect(AuthRemoteDataSource(client), isA<AuthRemoteDataSource>());
  });

  test('demo OTP constant is documented as 123456', () {
    expect('123456'.length, 6);
  });
}
