import 'package:flutter/material.dart';
import '../features/home/presentation/home_page.dart';

class AppRoutes {
  static const String home = '/';
  static const String login = '/login';

  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      case home:
        return MaterialPageRoute(
          builder: (_) => const HomePage(),
        );
      case login:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Login'),
        );
      default:
        return MaterialPageRoute(
          builder: (_) => const _PlaceholderPage(title: 'Not Found'),
        );
    }
  }
}

class _PlaceholderPage extends StatelessWidget {
  final String title;

  const _PlaceholderPage({required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title),
      ),
    );
  }
}
