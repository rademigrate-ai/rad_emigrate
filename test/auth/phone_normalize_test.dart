import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/auth/data/datasources/auth_remote_datasource.dart';

void main() {
  test('normalizeE164 accepts international numbers', () {
    expect(AuthRemoteDataSource.normalizeE164('+14155552671'), '+14155552671');
  });
  test('normalizeE164 maps Iranian local formats', () {
    expect(AuthRemoteDataSource.normalizeE164('09121234567'), '+989121234567');
    expect(AuthRemoteDataSource.normalizeE164('9121234567'), '+989121234567');
  });
  test('normalizeE164 rejects invalid', () {
    expect(AuthRemoteDataSource.normalizeE164('bad'), isNull);
    expect(AuthRemoteDataSource.normalizeE164(''), isNull);
  });
}
