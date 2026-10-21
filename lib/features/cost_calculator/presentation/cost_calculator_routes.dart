// Route registration for the Immigration Cost Calculator feature.
//
// Antigravity owns core/routing/app_router.dart. This file exports a ready-made
// route list so integration is a single spread addition inside the ShellRoute:
//
//   ...costCalculatorRoutes(),
//
// Do NOT wire these into app_router.dart from this branch; the integration
// owner applies the registration (see the delivery handoff).

import 'package:go_router/go_router.dart';

import 'pages/cost_calculator_page.dart';

List<GoRoute> costCalculatorRoutes() => [
  GoRoute(
    path: '/cost-calculator',
    builder: (_, _) => const CostCalculatorPage(),
  ),
];
