// Route registration for the Booking feature.
//
// Antigravity owns core/routing/app_router.dart. This file exports ready-made
// routes so integration is a single spread addition inside the ShellRoute:
//
//   ...bookingRoutes(),
//
// Do NOT wire these into app_router.dart from this branch; the integration
// owner applies the registration (see 09_INTEGRATION_INSTRUCTIONS.md).

import 'package:go_router/go_router.dart';

import 'pages/booking_page.dart';
import 'pages/booking_service_page.dart';

List<GoRoute> bookingRoutes() => [
  GoRoute(path: '/booking', builder: (_, _) => const BookingPage()),
  GoRoute(
    path: '/booking/service/:serviceId',
    builder: (_, state) =>
        BookingServicePage(serviceId: state.pathParameters['serviceId'] ?? ''),
  ),
];
