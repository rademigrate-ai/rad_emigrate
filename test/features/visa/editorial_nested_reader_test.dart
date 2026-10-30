import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rad_emigrate/features/visa/data/editorial_repository.dart';
import 'package:rad_emigrate/features/visa/presentation/pages/editorial_article_page.dart';

void main() {
  testWidgets(
    'RTL narrow complete reader retains three nested list levels and ordering',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      const key = (id: 'nested-list-source', locale: 'fa', preview: true);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            editorialArticleProvider(key).overrideWith(
              (ref) async => {
                'title': 'منبع فهرست تو در تو',
                'rich_sections': [
                  {
                    'heading': 'مراحل',
                    'blocks': [
                      {
                        'id': 'nested-original',
                        'type': 'bullet_list',
                        'text': 'مرحله اصلی زیرمرحله اول نکته تکمیلی',
                        'items': [
                          {
                            'text': 'مرحله اصلی',
                            'children': [
                              {
                                'ordered': true,
                                'items': [
                                  {
                                    'text': 'زیرمرحله اول',
                                    'children': [
                                      {
                                        'ordered': false,
                                        'items': [
                                          {
                                            'text': 'نکته تکمیلی',
                                            'children': [],
                                          },
                                        ],
                                      },
                                    ],
                                  },
                                ],
                              },
                            ],
                          },
                        ],
                      },
                    ],
                  },
                ],
              },
            ),
          ],
          child: const MaterialApp(
            home: EditorialArticlePage(
              articleId: 'nested-list-source',
              locale: 'fa',
              preview: true,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final parent = tester.getRect(find.text('• مرحله اصلی'));
      final child = tester.getRect(find.text('1. زیرمرحله اول'));
      final leaf = tester.getRect(find.text('• نکته تکمیلی'));
      expect(child.top, greaterThan(parent.top));
      expect(leaf.top, greaterThan(child.top));
      expect(child.right, lessThan(parent.right));
      expect(leaf.right, lessThan(child.right));
      expect(tester.takeException(), isNull);
    },
  );
}
