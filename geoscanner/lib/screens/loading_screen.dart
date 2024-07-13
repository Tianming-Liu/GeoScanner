import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoadingPage extends StatelessWidget {
  const LoadingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          color: Color.fromARGB(255, 255, 255, 255),
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'assets/logo.png',
                height: 300,
              ),
              const SizedBox(
                height: 30,
              ),
              Text(
                'GO SENSING',
                style: GoogleFonts.oswald(
                  fontSize: 50,
                  fontWeight: FontWeight.w600,
                  color: const Color.fromARGB(255, 189, 189, 189),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
