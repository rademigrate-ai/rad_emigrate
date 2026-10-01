import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

class RadEmigrateApp extends StatelessWidget {
  const RadEmigrateApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Rad Emigrate',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Text(
            'Rad Emigrate',
            style: TextStyle(fontSize: 32),
          ),
        ),
      ),
    );
  }
}