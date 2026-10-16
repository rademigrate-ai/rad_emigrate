import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/widgets/rad_ai_bird_nav_icon.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  for (final dimensions in [
    ('master', 1536, 1024),
    ('256', 256, 171),
    ('512', 512, 341),
    ('768', 768, 512),
  ]) {
    test('owner Phoenix ${dimensions.$1} has real RGBA transparency', () async {
      final bytes = File(
        'assets/branding/rad_phoenix_final_${dimensions.$1}.png',
      ).readAsBytesSync();
      expect(bytes[25], 6, reason: 'PNG color type must be RGBA, not RGB');
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      try {
        expect(frame.image.width, dimensions.$2);
        expect(frame.image.height, dimensions.$3);
        final rgba = await frame.image.toByteData(
          format: ui.ImageByteFormat.rawStraightRgba,
        );
        expect(rgba, isNotNull);
        var transparent = 0;
        var visible = 0;
        var maximumAlpha = 0;
        for (var offset = 3; offset < rgba!.lengthInBytes; offset += 4) {
          final alpha = rgba.getUint8(offset);
          if (alpha == 0) transparent++;
          if (alpha > 0) visible++;
          if (alpha > maximumAlpha) maximumAlpha = alpha;
        }
        expect(transparent, greaterThan(dimensions.$2 * dimensions.$3 / 2));
        expect(visible, greaterThan(0));
        expect(maximumAlpha, greaterThan(200));
        for (final pixel in [
          0,
          dimensions.$2 - 1,
          (dimensions.$3 - 1) * dimensions.$2,
          dimensions.$2 * dimensions.$3 - 1,
        ]) {
          expect(rgba.getUint8(pixel * 4 + 3), 0);
        }
      } finally {
        frame.image.dispose();
        codec.dispose();
      }
    });
  }

  for (final dark in [false, true]) {
    testWidgets('same master derivative in ${dark ? 'dark' : 'light'} mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            brightness: dark ? Brightness.dark : Brightness.light,
          ),
          home: Builder(
            builder: (context) => MediaQuery(
              data: MediaQuery.of(context).copyWith(disableAnimations: true),
              child: Scaffold(
                body: Center(
                  child: RadAiBirdNavIcon(
                    selected: false,
                    label: 'AI Assistant',
                    moreLabel: 'More',
                    onTap: () {},
                    onLongPress: () {},
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final image = tester.widget<Image>(find.byType(Image));
      expect(
        (image.image as AssetImage).assetName,
        'assets/branding/rad_flying_bird_512.png',
      );
      expect(image.fit, BoxFit.contain);
      expect(
        image.color,
        isNull,
        reason: 'The approved artwork is not recolored',
      );
      expect(tester.takeException(), isNull);
    });
  }
}
