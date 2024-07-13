import 'package:flutter/material.dart';

class FirebaseWaiting extends StatelessWidget {
  const FirebaseWaiting({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 255, 255, 255),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/logo.png', width: 200, height: 200),
              const Text('Loading...'),
            ],
          ),
        ),
      ),
    );
  }
}
