// Route registration for the Country & Pathway Comparison feature.
//
// Antigravity owns core/routing/app_router.dart. This file exports a ready-made
// route list so integration is a single spread addition inside the ShellRoute:
//
//   ...comparisonRoutes(),
//
// Do NOT wire these into app_router.dart from this branch; the integration
// owner applies the registration (see the delivery handoff).

import 'package:go_router/go_router.dart';

import 'pages/comparison_page.dart';

List<GoRoute> comparisonRoutes() => [
  GoRoute(path: '/compare', builder: (_, _) => const ComparisonPage()),
];
