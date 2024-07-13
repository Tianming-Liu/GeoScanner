import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class CustomTextStyle {
  static TextStyle appTitle = TextStyle(
      fontFamily: GoogleFonts.cormorantGaramond().fontFamily,
      color: const Color.fromARGB(255, 0, 0, 0),
      fontSize: 28,
      fontWeight: FontWeight.w300);
  static TextStyle normalText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 0, 0, 0),
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );
  static TextStyle lightText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 100, 100, 100),
    fontSize: 12,
    fontWeight: FontWeight.w400,
  );
  static TextStyle tinyBoldGreyText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 100, 100, 100),
    fontSize: 8,
    fontWeight: FontWeight.w900,
  );
  static TextStyle smallBoldGreyText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 100, 100, 100),
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
  static TextStyle smallBoldBlackText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 0, 0, 0),
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
  static TextStyle smallBoldWhiteText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 255, 255, 255),
    fontSize: 12,
    fontWeight: FontWeight.w900,
  );
  static TextStyle mediumBoldGreyText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 100, 100, 100),
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
  static TextStyle mediumBoldBlackText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 0, 0, 0),
    fontSize: 16,
    fontWeight: FontWeight.w900,
  );
  static TextStyle mediumBoldWhiteText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 255, 255, 255),
    fontSize: 14,
    fontWeight: FontWeight.w900,
  );
  static TextStyle bigBoldBlackText = TextStyle(
    fontFamily: GoogleFonts.roboto().fontFamily,
    color: const Color.fromARGB(255, 0, 0, 0),
    fontSize: 18,
    fontWeight: FontWeight.w900,
  );
  static TextStyle boldTitle = TextStyle(
    fontFamily: GoogleFonts.oswald().fontFamily,
    color: const Color.fromARGB(255, 50, 50, 50),
    fontSize: 22,
    fontWeight: FontWeight.w900,
  );
}
