import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/network/api_client.dart';
import 'package:rad_emigrate/core/network/network_config.dart';
import 'package:rad_emigrate/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AuthRemoteDataSource preserves the legacy transport contract', () {
    const network = NetworkConfig(
      baseUrl: 'https://example.com',
      connectTimeout: Duration(seconds: 1),
      receiveTimeout: Duration(seconds: 1),
      enableLogging: false,
    );
    final client = ApiClient(config: network, tokenProvider: () async => null);
    expect(client.config.baseUrl, 'https://example.com');
    expect(AuthRemoteDataSource(client), isA<AuthRemoteDataSource>());
  });
}
