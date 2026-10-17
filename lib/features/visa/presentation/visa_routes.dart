import 'package:go_router/go_router.dart';

import 'pages/visa_page.dart';

/// Real route entries keep browser/system Back aligned with visible detail
/// controls, and preserve the catalog page (including its scroll position).
GoRoute visaRoute() => GoRoute(
  path: '/visa',
  builder: (_, _) => const VisaPage(),
  routes: [
    GoRoute(
      path: ':countryId',
      builder: (_, state) =>
          VisaPage(countryId: state.pathParameters['countryId']),
      routes: [
        GoRoute(
          path: 'programs/:programId',
          builder: (_, state) => VisaPage(
            countryId: state.pathParameters['countryId'],
            programId: state.pathParameters['programId'],
          ),
        ),
      ],
    ),
  ],
);
