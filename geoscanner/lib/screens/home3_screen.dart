// ignore_for_file: unused_import

import 'package:flutter/material.dart';
import 'package:curved_navigation_bar/curved_navigation_bar.dart';

import 'package:geoscanner/screens/track_screen.dart';
import 'package:geoscanner/screens/setting_screen.dart';
import 'package:geoscanner/screens/map_screen.dart';
import 'package:geoscanner/style/custom_text_style.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:geoscanner/screens/instruction_screen.dart';
import 'package:geoscanner/screens/records_screen.dart';
import 'package:geoscanner/widgets/animated_history.dart';
import 'package:geoscanner/screens/test_screen.dart';
import 'package:geoscanner/screens/new_track_screen.dart';

class Home3Screen extends StatefulWidget {
  const Home3Screen({super.key});

  @override
  State<Home3Screen> createState() => _Home3ScreenState();
}

class _Home3ScreenState extends State<Home3Screen> {
  int _page = 0;
  GlobalKey<CurvedNavigationBarState> _bottomNavigationKey = GlobalKey();

  Color mainColor = const Color.fromARGB(255, 245, 245, 245);

  static List<Widget> _widgetOptions = <Widget>[
    
    const NewTrackScreen (),
    const RecordsScreen(),
    const SettingScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mainColor,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4.0),
          child: Container(
            color: const Color.fromARGB(255, 190, 190, 190),
            height: 0.5,
          ),
        ),
        title: Text(
          'Sensing The City',
          style: TextStyle(
              fontFamily: GoogleFonts.marcellus().fontFamily,
              color: const Color.fromARGB(255, 75, 75, 75),
              fontSize: 22,
              fontWeight: FontWeight.w400),
        ),
      ),
      bottomNavigationBar: CurvedNavigationBar(
        key: _bottomNavigationKey,
        // Set Default Page Index
        index: 0,
        items: const <Widget>[
          Icon(Icons.assistant_navigation,
              size: 35, color: Color.fromARGB(255, 0, 0, 0)),
          Icon(Icons.cloud_circle,
              size: 35, color: Color.fromARGB(255, 0, 0, 0)),
          Icon(Icons.account_circle,
              size: 35, color: Color.fromARGB(255, 0, 0, 0)),
        ],
        color: mainColor,
        buttonBackgroundColor: mainColor,
        backgroundColor: const Color.fromARGB(255, 255, 255, 255),
        animationCurve: Curves.easeInOut,
        animationDuration: const Duration(milliseconds: 600),
        onTap: (index) {
          setState(() {
            _page = index;
          });
        },
        letIndexChange: (index) => true,
      ),
      body: Container(
        color: const Color.fromARGB(255, 255, 255, 255),
        child: _widgetOptions.elementAt(_page),
      ),
    );
  }
}
