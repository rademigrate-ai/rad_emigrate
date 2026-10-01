import 'package:flutter/material.dart';

import '../core/theme/app_theme.dart';
import 'routes.dart';

class RadEmigrateApp extends StatelessWidget {
  const RadEmigrateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rad Emigrate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      initialRoute: AppRoutes.home,
      onGenerateRoute: AppRoutes.onGenerateRoute,
    );
  }
}
