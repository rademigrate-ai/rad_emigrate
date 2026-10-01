import 'package:flutter/material.dart';

class NotFoundPage extends StatelessWidget {
  final String title;
  const NotFoundPage({super.key, required this.title});

  @override
  Widget build(BuildContext context) =>
      Scaffold(body: Center(child: Text(title)));
}
