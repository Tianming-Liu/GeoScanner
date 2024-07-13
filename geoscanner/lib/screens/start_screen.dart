import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geoscanner/screens/home3_screen.dart';
import 'package:geoscanner/screens/loading_screen.dart';

import 'dart:async';
import 'package:geoscanner/screens/auth_screen.dart';
import 'package:geoscanner/screens/firebase_waiting.dart';

class StartScreen extends StatefulWidget {
  const StartScreen({super.key});

  @override
  State<StartScreen> createState() => _StartScreenState();
}

class _StartScreenState extends State<StartScreen> {
  late Widget displayPage;

  @override
  void initState() {
    super.initState();
    displayPage = const LoadingPage();
    Timer(
      const Duration(seconds: 2),
      () => setState(() {
        // displayPage = const TagPage();
        displayPage = StreamBuilder(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (ctx, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const FirebaseWaiting();
            }
            if (snapshot.hasData) {
              return const Home3Screen();
            }
            return const AuthScreen();
          },
        );
      }),
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp( 
      debugShowCheckedModeBanner: false,
      home: displayPage,
    );
  }
}
