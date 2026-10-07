import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_brand.dart';
import 'package:rad_emigrate/l10n/app_localizations.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('canonical application logo is square and transparent', () async {
    final codec = await ui.instantiateImageCodec(
      File('assets/branding/rad_official_logo.png').readAsBytesSync(),
    );
    final frame = await codec.getNextFrame();
    final image = frame.image;
    expect(image.width, 512);
    expect(image.height, 512);
    final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!
        .buffer
        .asUint8List();
    expect(pixels[3], 0, reason: 'The original clear space stays transparent');
    final redPixel = (256 * image.width + 384) * 4;
    expect(pixels[redPixel], greaterThan(150));
    expect(pixels[redPixel + 1], lessThan(80));
    expect(pixels[redPixel + 3], greaterThan(200));
    image.dispose();
    codec.dispose();
  });

  test('PWA installs use canonical PNGs with separate maskable artwork', () {
    final manifest = jsonDecode(
      File('web/manifest.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final icons = (manifest['icons'] as List<dynamic>)
        .cast<Map<String, dynamic>>();
    for (final size in [192, 512]) {
      for (final purpose in ['any', 'maskable']) {
        final icon = icons.singleWhere(
          (icon) =>
              icon['sizes'] == '${size}x$size' && icon['purpose'] == purpose,
        );
        expect(icon['type'], 'image/png');
        expect(File('web/${icon['src']}').existsSync(), isTrue);
      }
    }
    final provenance = jsonDecode(
      File('assets/branding/provenance.json').readAsStringSync(),
    ) as Map<String, dynamic>;
    final source = provenance['canonical_source'] as Map<String, dynamic>;
    expect(
      source['sha256'],
      'f421a6887fcc07d4b8ba7529d99c9bc5f95114a8ee14942e0776159e5bbca048',
    );
    expect(File(source['path'] as String).lengthSync(), 95420);
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('icons/apple-touch-icon.png'));
    expect(index, contains('width="116" height="116"'));
    expect(index, contains('assets/assets/branding/rad_official_logo.png'));
  });

  for (final locale in ['en', 'fa']) {
    for (final size in RadBrandSize.values) {
      testWidgets('canonical $locale $size emblem fits narrow space', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await tester.pumpWidget(
          MaterialApp(
            locale: Locale(locale),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 96,
                  child: RadBrand(size: size, darkSurface: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final logo = tester.widget<Image>(find.byType(Image));
        expect(
          (logo.image as AssetImage).assetName,
          'assets/branding/rad_official_logo.png',
        );
        expect(logo.width, logo.height);
        expect(logo.fit, BoxFit.contain);
        expect(logo.excludeFromSemantics, isTrue);
        expect(tester.getSize(find.byType(RadBrand)).width, 96);
        expect(
          find.bySemanticsLabel(
            locale == 'fa'
                ? 'موسسه بین‌المللی راد'
                : 'RAD International Institute',
          ),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
        semantics.dispose();
      });
    }
  }
}
