import 'package:flutter/material.dart';
// import 'package:geoscanner/map_screen.dart';
// import 'package:geoscanner/nav_screen.dart';
// import 'package:geoscanner/nav_example.dart';
import 'package:geoscanner/screens/auth_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: AuthScreen(),
    );
  }
}
