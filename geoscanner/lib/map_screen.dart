import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});
  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _controller;
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};
  LatLng? _selectedPoint;

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
  }

  void _onTap(LatLng point) {
    setState(() {
      _selectedPoint = point;
      _polygons.clear();
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('selectedArea'),
          points: _createCirclePoints(point, 750),
          strokeWidth: 2,
          strokeColor: Colors.blue,
          fillColor: Colors.blue.withOpacity(0.15),
        ),
      );
      print('Selected point: $point');
    });
  }

  List<LatLng> _createCirclePoints(LatLng center, double radius) {
    const int points = 100;
    const double earthRadius = 6378137.0;
    double radiusInRad = radius / earthRadius;
    double centerLatRad = center.latitude * (math.pi / 180);
    double centerLonRad = center.longitude * (math.pi / 180);
    List<LatLng> circlePoints = [];

    for (int i = 0; i < points; i++) {
      double angle = i * (2 * math.pi / points);
      double latRad = math.asin(math.sin(centerLatRad) * math.cos(radiusInRad) +
          math.cos(centerLatRad) * math.sin(radiusInRad) * math.cos(angle));
      double lonRad = centerLonRad +
          math.atan2(math.sin(angle) * math.sin(radiusInRad) * math.cos(centerLatRad),
              math.cos(radiusInRad) - math.sin(centerLatRad) * math.sin(latRad));
      circlePoints.add(LatLng(latRad * (180 / math.pi), lonRad * (180 / math.pi)));
    }
    return circlePoints;
  }

  Future<void> _fetchAndDisplayRoads() async {
    if (_selectedPoint == null) {
      _showDialog(
        title: 'Invalid Selection',
        content: 'Please select a point.',
      );
      return;
    }

    try {
      double lat = _selectedPoint!.latitude;
      double lon = _selectedPoint!.longitude;
      int radius = 750;  // 默认500米

      // 调用Google Cloud Function
      final url = Uri.parse('http://ec2-35-178-35-159.eu-west-2.compute.amazonaws.com//get_osm?lat=$lat&lon=$lon&radius=$radius');
      print('Fetching OSM data from: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nodes = data['nodes'];
        final edges = data['edges'];

        if (!mounted) return;

        setState(() {
          _polylines.clear();
          print('Fetched ${nodes['features'].length} nodes and ${edges['features'].length} edges');

          var displayCount = 0;

          for (var edge in edges['features']) {
            final List<LatLng> points = [];
            for (var coord in edge['geometry']['coordinates']) {
              points.add(LatLng(coord[1], coord[0]));
            }
            _polylines.add(
              Polyline(
                polylineId: PolylineId(edge['id'].toString()),
                points: points,
                width: 2,
                color: Colors.red,
              ),
            );
            displayCount++;
            print('Added edge: $displayCount');
          }
        });
      } else {
        print('Failed to load OSM data');
      }
    } catch (e) {
      if (!mounted) return;
      _showDialog(
        title: 'Error',
        content: 'Failed to load data: $e',
      );
    }
  }

  void _showDialog({required String title, required String content}) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            TextButton(
              child: const Text('OK'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Area'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            onPressed: _fetchAndDisplayRoads,
          ),
        ],
      ),
      body: GoogleMap(
        onMapCreated: _onMapCreated,
        initialCameraPosition: const CameraPosition(
          target: LatLng(51.506611, -0.149472),
          zoom: 14,
        ),
        polygons: _polygons,
        polylines: _polylines,
        onTap: _onTap,
      ),
    );
  }
}
