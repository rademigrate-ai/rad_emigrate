import 'package:flutter_web_plugins/url_strategy.dart';

/// Enables path-based URLs on Flutter Web (matches SPA /* → index.html rewrite).
void configureUrlStrategy() {
  usePathUrlStrategy();
}
