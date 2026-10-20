// Route registration for the Interview Scheduling feature.
//
// Antigravity owns core/routing/app_router.dart. Integration is a single
// spread addition inside the ShellRoute:
//
//   ...interviewRoutes(),
//
// Do NOT wire these into app_router.dart from this branch.

import 'package:go_router/go_router.dart';

import 'pages/interviews_page.dart';

List<GoRoute> interviewRoutes() => [
  GoRoute(path: '/interviews', builder: (_, _) => const InterviewsPage()),
];
