import 'package:go_router/go_router.dart';

import 'pages/canonical_pathway_page.dart';
import 'pages/visa_page.dart';
import 'pages/visa_search_page.dart';
import 'pages/editorial_article_page.dart';
import 'pages/visa_content_countries_page.dart';
import 'pages/other_titles_library_page.dart';

/// Real route entries keep browser/system Back aligned with visible detail
/// controls, and preserve the catalog page (including its scroll position).
GoRoute visaRoute() => GoRoute(
  path: '/visa',
  builder: (_, _) => const VisaPage(),
  routes: [
    GoRoute(
      path: 'other-titles',
      builder: (_, state) => OtherTitlesLibraryPage(
        preview: state.uri.queryParameters['preview'] == 'true',
      ),
    ),
    GoRoute(
      path: 'content-countries',
      builder: (_, state) => VisaContentCountriesPage(
        preview: state.uri.queryParameters['preview'] == 'true',
      ),
      routes: [
        GoRoute(
          path: ':countryCode',
          builder: (_, state) => VisaContentCountriesPage(
            countryCode: state.pathParameters['countryCode']!,
            preview: state.uri.queryParameters['preview'] == 'true',
          ),
        ),
      ],
    ),
    GoRoute(
      path: 'content/:articleId',
      builder: (_, state) => EditorialArticlePage(
        articleId: state.pathParameters['articleId']!,
        locale: state.uri.queryParameters['locale'] == 'en' ? 'en' : 'fa',
        preview: state.uri.queryParameters['preview'] == 'true',
        initialSectionAnchor: state.uri.fragment.isNotEmpty
            ? state.uri.fragment
            : state.uri.queryParameters['section'],
        requestedLocale: state.uri.queryParameters['requested_locale'],
      ),
    ),
    GoRoute(
      path: 'articles/:articleId',
      builder: (_, state) => EditorialArticlePage(
        articleId: state.pathParameters['articleId']!,
        locale: state.uri.queryParameters['locale'] == 'en' ? 'en' : 'fa',
        requestedLocale: state.uri.queryParameters['requested_locale'],
        initialSectionAnchor: state.uri.fragment.isNotEmpty
            ? state.uri.fragment
            : state.uri.queryParameters['section'],
      ),
    ),
    GoRoute(
      path: 'search',
      builder: (_, state) =>
          VisaSearchPage(initialQuery: state.uri.queryParameters['q']),
    ),
    GoRoute(
      path: ':countryId',
      builder: (_, state) =>
          VisaPage(countryId: state.pathParameters['countryId']),
      routes: [
        GoRoute(
          path: 'articles/:articleSlug',
          builder: (_, state) => EditorialLegacySlugPage(
            country: state.pathParameters['countryId']!,
            slug: state.pathParameters['articleSlug']!,
          ),
        ),
        GoRoute(
          path: 'programs/:programId',
          builder: (_, state) => VisaPage(
            countryId: state.pathParameters['countryId'],
            programId: state.pathParameters['programId'],
          ),
        ),
        GoRoute(
          path: ':pathwaySlug',
          builder: (_, state) => CanonicalPathwayPage(
            countrySlug: state.pathParameters['countryId']!,
            pathwaySlug: state.pathParameters['pathwaySlug']!,
            initialSectionAnchor: state.uri.fragment.isNotEmpty
                ? state.uri.fragment
                : null,
          ),
        ),
      ],
    ),
  ],
);
