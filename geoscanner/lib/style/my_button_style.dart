import 'package:flutter/material.dart';

// Design Custom Button Style

class MyButtonStyle {
  static ButtonStyle normalStyle = ButtonStyle(
    backgroundColor: WidgetStateProperty.all<Color>(const Color.fromARGB(255, 255, 255, 255)),
    shape: WidgetStateProperty.all<RoundedRectangleBorder>(
      RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
      ),
    ),
    padding: WidgetStateProperty.all<EdgeInsetsGeometry>(const EdgeInsets.only(top: 10, bottom: 10, left: 30, right: 30)),
    textStyle: WidgetStateProperty.all<TextStyle>(
      const TextStyle(
        color: Color.fromARGB(255, 255, 255, 255),
        fontSize: 16,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}