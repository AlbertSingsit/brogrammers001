import 'package:flutter/material.dart';

void main() {
  runApp(First());
}

class First extends StatelessWidget {
  const First({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(darkTheme: ThemeData.dark());
  }
}
