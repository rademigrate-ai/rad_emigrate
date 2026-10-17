import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/supabase/supabase_client.dart';
import 'package:rad_emigrate/features/visa/data/visa_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/widgets/country_photography.dart';

void main() {
  test('all supported destination photographs decode locally including the four reported gaps', () async {
    for (final code in [
      'AE',
      'OM',
      'NO',
      'MY',
      'AT',
      'AU',
      'CA',
      'CH',
      'DE',
      'ES',
      'FR',
      'GB',
      'IE',
      'IT',
      'JP',
      'KR',
      'NL',
      'NZ',
      'SE',
      'SG',
      'TR',
      'US',
    ]) {
      final path = CountryPhotography.pathForCode(code);
      expect(path, isNot(endsWith('/fallback.jpg')), reason: code);
      final codec = await ui.instantiateImageCodec(
        File(path).readAsBytesSync(),
      );
      final frame = await codec.getNextFrame();
      expect(frame.image.width, greaterThanOrEqualTo(600), reason: code);
      frame.image.dispose();
      codec.dispose();
    }
  });

  test(
    'unconfigured builds expose a configuration failure, not an empty list',
    () async {
      final repository = VisaRepository(SupabaseClientService.instance);

      await expectLater(
        repository.loadCatalog(locale: 'en'),
        throwsA(
          isA<VisaCatalogException>().having(
            (error) => error.kind,
            'kind',
            VisaCatalogFailureKind.configuration,
          ),
        ),
      );
    },
  );

  test(
    'known destination images are bundled and unknown codes use fallback',
    () {
      expect(CountryPhotography.pathForCode('CA'), endsWith('/ca.jpg'));
      expect(CountryPhotography.pathForCode('ca'), endsWith('/ca.jpg'));
      expect(CountryPhotography.pathForCode('ZZ'), endsWith('/fallback.jpg'));
    },
  );
}
