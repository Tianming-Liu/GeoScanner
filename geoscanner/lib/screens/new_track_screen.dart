import 'package:flutter/material.dart';
import 'package:geoscanner/screens/map_screen.dart';
import 'package:geoscanner/screens/track_screen.dart';
import 'package:google_fonts/google_fonts.dart';

class NewTrackScreen extends StatelessWidget {
  const NewTrackScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: MediaQuery.of(context).size.width,
            height: 30,
            padding: const EdgeInsets.only(left: 15),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Device Connection Guide',
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.black.withOpacity(0.5),
                    fontFamily: GoogleFonts.roboto().fontFamily,
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(
                    Icons.help,
                    size: 17,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(
            height: 25,
          ),
          Container(
            width: MediaQuery.of(context).size.width,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black12,
                  offset: Offset(0, 2),
                  blurRadius: 6,
                ),
              ],
            ),
            child: const Image(image: AssetImage('assets/hardware.png')),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ButtonStyle(
              fixedSize: WidgetStateProperty.all<Size>(const Size(205, 20)),
              backgroundColor: WidgetStateProperty.all<Color>(
                  const Color.fromARGB(255, 0, 122, 255)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const TrackScreen()),
              );
            },
            child: Text(
              'Free Sensing',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: GoogleFonts.roboto().fontFamily),
            ),
          ),
          const SizedBox(height: 25),
          ElevatedButton(
            style: ButtonStyle(
              fixedSize: WidgetStateProperty.all<Size>(const Size(205, 20)),
              backgroundColor: WidgetStateProperty.all<Color>(
                  const Color.fromARGB(255, 0, 122, 255)),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const MapScreen()),
              );
            },
            child: Text(
              'Sense with Route Planning',
              style: TextStyle(
                  color: Colors.white,
                  fontSize: 13,
                  fontFamily: GoogleFonts.roboto().fontFamily),
            ),
          ),
        ],
      ),
    );
  }
}
