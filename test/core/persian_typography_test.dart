import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/core/theme/app_theme.dart';

void main() {
  for (final brightness in Brightness.values) {
    for (final width in [390.0, 1440.0]) {
      testWidgets(
        'Persian component typography ($brightness, ${width.toInt()}px)',
        (tester) async {
          tester.view.physicalSize = Size(width, 900);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          await tester.pumpWidget(
            MaterialApp(
              theme: brightness == Brightness.light
                  ? AppTheme.light()
                  : AppTheme.dark(),
              locale: const Locale('fa'),
              localizationsDelegates: GlobalMaterialLocalizations.delegates,
              supportedLocales: const [Locale('fa'), Locale('en')],
              home: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      FilledButton(
                        onPressed: () {},
                        child: const Text('پرونده‌ها'),
                      ),
                      OutlinedButton(
                        onPressed: () {},
                        child: const Text('مدارک'),
                      ),
                      TextButton(
                        onPressed: () {},
                        child: const Text('تلاش دوباره'),
                      ),
                      const Chip(label: Text('بررسی‌شده')),
                      NavigationBar(
                        destinations: const [
                          NavigationDestination(
                            icon: Icon(Icons.home),
                            label: 'خانه',
                          ),
                          NavigationDestination(
                            icon: Icon(Icons.folder),
                            label: 'درخواست‌ها',
                          ),
                        ],
                      ),
                      SizedBox(
                        height: 250,
                        child: NavigationRail(
                          selectedIndex: 0,
                          labelType: NavigationRailLabelType.all,
                          destinations: const [
                            NavigationRailDestination(
                              icon: Icon(Icons.person),
                              label: Text('پروفایل'),
                            ),
                            NavigationRailDestination(
                              icon: Icon(Icons.article),
                              label: Text('پژوهش'),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          for (final label in [
            'پرونده‌ها',
            'مدارک',
            'تلاش دوباره',
            'بررسی‌شده',
            'خانه',
            'درخواست‌ها',
            'پروفایل',
            'پژوهش',
          ]) {
            final richText = find.descendant(
              of: find.text(label),
              matching: find.byType(RichText),
            );
            final paragraph = tester.renderObject<RenderParagraph>(richText);
            expect(paragraph.text.toPlainText(), label);
            expect(paragraph.textDirection, TextDirection.rtl, reason: label);
            expect(
              paragraph.text.style?.fontFamily,
              'Vazirmatn',
              reason: label,
            );
            expect(paragraph.text.style?.letterSpacing, 0, reason: label);
          }
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
