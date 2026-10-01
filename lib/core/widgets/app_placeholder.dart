import 'package:flutter/material.dart';

class AppPlaceholder extends StatelessWidget {
  final String title;
  const AppPlaceholder({super.key, required this.title});

  @override
  Widget build(BuildContext context) => Scaffold(body: Center(child: Text(title)));
}
