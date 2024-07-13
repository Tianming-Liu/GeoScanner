import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:location/location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math' as math;

class CustomMapType {
  final String name;
  final String? assetPath;
  final MapType? mapType;

  CustomMapType({required this.name, this.assetPath, this.mapType});

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CustomMapType &&
          runtimeType == other.runtimeType &&
          name == other.name &&
          assetPath == other.assetPath &&
          mapType == other.mapType;

  @override
  int get hashCode => name.hashCode ^ assetPath.hashCode ^ mapType.hashCode;
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  late GoogleMapController _controller;

  // Set Status Flags
  bool _isDeletingPath = false;
  bool _isFetchingData = false; // Update Fetching Animation
  bool _dataFetched = false; // Update Fetching Data Status

  bool _showCleanRouteGuide = false;

  bool _isProcessingPath = false;
  bool _routeProcessed = false;

  // Set data structures for storing map elements
  final Set<Polygon> _polygons = {};
  final Set<Polyline> _polylines = {};

  List<Map<String, dynamic>> _cleanedNodes = [];
  List<Map<String, dynamic>> _cleanedEdges = [];

  String streetLength = '';
  String routeLength = '';

  List<LatLng> routeCoordinates = [];
  int _routeIndex = 0;
  List<Map<String, dynamic>> waypoints = [];
  Location _location = Location();
  LatLng? _selectedPoint;
  double _radius = 300; // Sensing radius

  final Map<String, String> _mapStylePreviews = {
    'Standard': 'assets/standard.png',
    'Silver': 'assets/silver.png',
    'Dark': 'assets/dark.png',
    'Night': 'assets/night.png',
    'Aubergine': 'assets/aubergine.png',
    'Satellite': 'assets/satellite.png',
  };

  // Map types from https://mapstyle.withgoogle.com/
  final List<CustomMapType> _mapTypes = [
    CustomMapType(name: 'Standard', mapType: MapType.normal),
    CustomMapType(name: 'Silver', assetPath: 'assets/silver_map_style.json'),
    CustomMapType(name: 'Dark', assetPath: 'assets/dark_map_style.json'),
    CustomMapType(name: 'Night', assetPath: 'assets/night_map_style.json'),
    CustomMapType(
        name: 'Aubergine', assetPath: 'assets/aubergine_map_style.json'),
    CustomMapType(name: 'Satellite', mapType: MapType.satellite),
  ];

  CustomMapType _selectedMapType = CustomMapType(
      name: 'Silver',
      assetPath: 'assets/silver_map_style.json'); // Default map style

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _setMapStyle(_selectedMapType);
  }

  void _getCurrentLocation() async {
    print('Getting current location...');
    var currentLocation = await _location.getLocation();
    _controller.moveCamera(CameraUpdate.newCameraPosition(
      CameraPosition(
        target: LatLng(currentLocation.latitude!, currentLocation.longitude!),
        zoom: 16,
      ),
    ));
  }

  void _changeMapType(CustomMapType mapType) {
    setState(() {
      _selectedMapType = mapType;
      _setMapStyle(mapType);
    });
  }

  void _setMapStyle(CustomMapType mapType) async {
    if (mapType.assetPath != null) {
      String style =
          await DefaultAssetBundle.of(context).loadString(mapType.assetPath!);
      // ignore: deprecated_member_use
      _controller.setMapStyle(style);
    } else {
      // ignore: deprecated_member_use
      _controller.setMapStyle(null);
    }
  }

  TextStyle customTextStyle =
      TextStyle(fontSize: 14, fontFamily: GoogleFonts.roboto().fontFamily);

  List<Widget> _transModes = <Widget>[
    const Row(
      children: [
        Icon(Icons.directions_walk, size: 20),
      ],
    ),
    const Row(
      children: [
        Icon(Icons.directions_car, size: 20),
      ],
    ),
    const Row(
      children: [
        Icon(Icons.directions_bike, size: 20),
      ],
    ),
  ];

  List<bool> _selectedTransPattern = <bool>[true, false, false];

  String _selectedMode = 'walk';

  void _onTap(LatLng point) {
    if (!_isDeletingPath) {
      setState(() {
        _selectedPoint = point;
        _updateCircle(point, _radius);
      });
    }
  }

  void _updateCircle(LatLng center, double radius) {
    setState(() {
      _polygons.clear();
      _polygons.add(
        Polygon(
          polygonId: const PolygonId('selectedArea'),
          points: _createCirclePoints(center, radius),
          strokeWidth: 2,
          strokeColor: const Color.fromARGB(255, 0, 122, 255),
          fillColor: const Color.fromARGB(40, 0, 122, 255),
        ),
      );
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
          math.atan2(
              math.sin(angle) * math.sin(radiusInRad) * math.cos(centerLatRad),
              math.cos(radiusInRad) -
                  math.sin(centerLatRad) * math.sin(latRad));
      circlePoints
          .add(LatLng(latRad * (180 / math.pi), lonRad * (180 / math.pi)));
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

    setState(() {
      _isFetchingData = true;
      _dataFetched = false;
    });

    try {
      double lat = _selectedPoint!.latitude;
      double lon = _selectedPoint!.longitude;
      int radius = _radius.toInt();

      // Request OSM data from backend
      final url = Uri.parse(
          'http://ec2-35-178-35-159.eu-west-2.compute.amazonaws.com:5000/get_osm?lat=$lat&lon=$lon&radius=$radius&network_type=$_selectedMode');
      print('Fetching OSM data from: $url');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final nodes = data['nodes'];
        final edges = data['edges'];

        if (!mounted) return;

        setState(() {
          _polylines.clear();
          _polygons.clear();
          print(
              'Fetched ${nodes['features'].length} nodes and ${edges['features'].length} edges');

          // Clean up existing data
          _cleanedNodes.clear();
          _cleanedEdges.clear();

          // Save node data
          nodes['features'].forEach((node) {
            _cleanedNodes.add({
              'id': node['id'],
              'latitude': node['geometry']['coordinates'][1],
              'longitude': node['geometry']['coordinates'][0],
            });
          });

          var displayCount = 0;

          for (var edge in edges['features']) {
            final List<LatLng> points = [];
            for (var coord in edge['geometry']['coordinates']) {
              points.add(LatLng(coord[1], coord[0]));
            }
            final polylineId = PolylineId(edge['id'].toString());
            final polyline = Polyline(
              polylineId: polylineId,
              points: points,
              width: 4,
              color: Colors.red,
              consumeTapEvents: true,
              onTap: () {
                if (_isDeletingPath) {
                  setState(() {
                    _polylines
                        .removeWhere((poly) => poly.polylineId == polylineId);
                    // Update cleaned edges
                    _cleanedEdges
                        .removeWhere((e) => e['id'] == polylineId.value);
                  });
                }
              },
            );
            _polylines.add(polyline);

            // Save edge data
            _cleanedEdges.add({
              'id': edge['id'],
              'points': edge['geometry']['coordinates'].map((coord) {
                return {
                  'latitude': coord[1],
                  'longitude': coord[0],
                };
              }).toList(),
            });

            displayCount++;
            print('Added edge: $displayCount');
          }

          _dataFetched = true;
        });
      } else {
        print('Failed to load OSM data');
      }
    } catch (e) {
      _showDialog(
        title: 'Error',
        content: 'Failed to load data: $e',
      );
    } finally {
      setState(() {
        _isFetchingData = false;
      });
    }
  }

  Future<void> _processGraph() async {
    setState(() {
      _isProcessingPath = true;
    });

    try {
      final url = Uri.parse(
          'http://ec2-35-178-35-159.eu-west-2.compute.amazonaws.com:5000/process_graph');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'nodes': _cleanedNodes,
          'edges': _cleanedEdges,
        }),
      );

      if (response.statusCode == 200) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        streetLength = data['streetLength'];
        routeLength = data['routeLength'];

        waypoints = List<Map<String, dynamic>>.from(data['waypoints']);

        print('Route Planning Successful: $streetLength, $routeLength');
        print('Waypoints: $waypoints');

        // Update route coordinates
        routeCoordinates = waypoints
            .map((waypoint) =>
                LatLng(waypoint['latitude'], waypoint['longitude']))
            .toList();

        _startRouteAnimation(16.0);

        setState(() {
          _routeProcessed = true;
        });

        print('Route Planning Successful: $streetLength, $routeLength');
        print('Waypoints: $waypoints');
      } else {
        print('Route Planning Error: ${response.statusCode}');
      }
    } catch (e) {
      print('Route Planning Request Failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isProcessingPath = false;
        });
      }
    }
  }

  void _startRouteAnimation(double zoomLevel) async {
    for (int i = 0; i < routeCoordinates.length; i++) {
      await Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _routeIndex = i;
        });
        _controller.animateCamera(
          CameraUpdate.newLatLngZoom(routeCoordinates[_routeIndex], zoomLevel),
        );
      });
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

  void _toggleDeleteMode() {
    setState(() {
      _isDeletingPath = !_isDeletingPath;
      _showCleanRouteGuide = true;
    });

    if (!_isDeletingPath) {
      _processGraph();
      _showCleanRouteGuide = false;
    }
  }

  void _reset() {
    setState(() {
      _polylines.clear();
      _polygons.clear();
      _isDeletingPath = false;
      _selectedPoint = null;
      _dataFetched = false;
    });
  }

  @override
  void initState() {
    super.initState();
    _getCurrentLocation();
  }

  @override
  Widget build(BuildContext context) {
    Color mainColor = const Color.fromARGB(255, 245, 245, 245);
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
          'Go Sensing',
          style: TextStyle(
              fontFamily: GoogleFonts.marcellus().fontFamily,
              color: const Color.fromARGB(255, 75, 75, 75),
              fontSize: 22,
              fontWeight: FontWeight.w400),
        ),
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              color: Color.fromARGB(255, 255, 255, 255),
            ),
          ),
          GoogleMap(
            onMapCreated: _onMapCreated,
            initialCameraPosition: const CameraPosition(
              target: LatLng(51.506611, -0.149472),
              zoom: 15,
            ),
            myLocationButtonEnabled: false,
            mapType: _selectedMapType.mapType ?? MapType.normal,
            polygons: _polygons,
            polylines: _routeProcessed
                ? {
                    Polyline(
                      polylineId: const PolylineId('route'),
                      points: routeCoordinates,
                      color: Colors.blue,
                      width: 5,
                      startCap: Cap.roundCap,
                      endCap: Cap.roundCap,
                      jointType: JointType.mitered,
                      geodesic: true,
                    ),
                  }
                : _polylines,
            onTap: _onTap,
          ),
          if (_routeProcessed)
            Center(
              child: Container(
                height: 40,
                width: 40,
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 0, 0, 0),
                  border: Border.all(
                    color: Colors.white,
                    width: 2,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 2,
                      spreadRadius: 2,
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: 25,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "  Map Style Picker:",
                      style: TextStyle(
                          fontSize: 14,
                          fontFamily: GoogleFonts.roboto().fontFamily),
                    ),
                    DropdownButton<CustomMapType>(
                      value: _selectedMapType,
                      dropdownColor: Colors.white,
                      items: _mapTypes.map((mapType) {
                        return DropdownMenuItem<CustomMapType>(
                          value: mapType,
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundImage: AssetImage(
                                    _mapStylePreviews[mapType.name]!),
                                radius: 15,
                              ),
                              const SizedBox(width: 10),
                              Text(
                                '${mapType.name} Mode',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontFamily:
                                        GoogleFonts.roboto().fontFamily),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                      onChanged: (CustomMapType? mapType) {
                        if (mapType != null) {
                          _changeMapType(mapType);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 75,
            right: 10,
            child: FloatingActionButton(
              onPressed: _getCurrentLocation,
              backgroundColor: Colors.white.withOpacity(0.85),
              child: const Icon(Icons.my_location),
            ),
          ),
          Positioned(
            bottom: 30,
            left: 10,
            right: 10,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: Colors.white.withOpacity(0.85),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 5,
                    spreadRadius: 2,
                  ),
                ],
              ),
              padding: const EdgeInsets.all(10),
              child: _isFetchingData
                  ? const Center(
                      child: CircularProgressIndicator(
                      color: Color.fromARGB(255, 0, 122, 255),
                    ))
                  : Column(
                      children: !_dataFetched
                          ? [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  const SizedBox(
                                    width: 13,
                                  ),
                                  Text(
                                    'Radius:',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontFamily:
                                            GoogleFonts.roboto().fontFamily),
                                  ),
                                  const SizedBox(
                                    width: 25,
                                  ),
                                  SizedBox(
                                    width: 212,
                                    child: Slider(
                                      activeColor: const Color.fromARGB(
                                          255, 0, 122, 255),
                                      inactiveColor: const Color.fromARGB(
                                          255, 200, 200, 200),
                                      value: _radius,
                                      min: 100,
                                      max: 700,
                                      divisions: 6,
                                      label: '${_radius.round().toString()}m',
                                      onChanged: (double value) {
                                        setState(() {
                                          _radius = value;
                                          if (_selectedPoint != null) {
                                            _updateCircle(
                                                _selectedPoint!, _radius);
                                          }
                                        });
                                      },
                                    ),
                                  ),
                                  Text(
                                    '$_radius m',
                                    style: TextStyle(
                                        fontSize: 12,
                                        fontFamily:
                                            GoogleFonts.roboto().fontFamily),
                                  ),
                                ],
                              ),
                              Row(children: [
                                const SizedBox(
                                  width: 13,
                                ),
                                Text(
                                  'Transport:',
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily),
                                ),
                                const SizedBox(
                                  width: 30,
                                ),
                                ToggleButtons(
                                  direction: Axis.horizontal,
                                  onPressed: (int index) {
                                    setState(() {
                                      for (int i = 0;
                                          i < _selectedTransPattern.length;
                                          i++) {
                                        _selectedTransPattern[i] = i == index;
                                      }
                                      _selectedMode = _selectedTransPattern
                                                  .indexWhere(
                                                      (element) => element) ==
                                              0
                                          ? 'walk'
                                          : _selectedTransPattern.indexWhere(
                                                      (element) => element) ==
                                                  1
                                              ? 'drive'
                                              : 'bike';
                                    });
                                  },
                                  borderRadius: const BorderRadius.all(
                                      Radius.circular(8)),
                                  selectedBorderColor: Colors.blue[700],
                                  selectedColor: Colors.white,
                                  fillColor:
                                      const Color.fromARGB(255, 0, 122, 255),
                                  color: Colors.grey[600],
                                  constraints: const BoxConstraints(
                                    minHeight: 25.0,
                                    minWidth: 55.0,
                                  ),
                                  isSelected: _selectedTransPattern,
                                  children: _transModes,
                                ),
                                const SizedBox(
                                  width: 22,
                                ),
                                // Display the selected transport mode
                                Text(
                                  _selectedMode.toUpperCase(),
                                  style: TextStyle(
                                      fontSize: 12,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily),
                                ),
                              ]),
                              const SizedBox(
                                height: 10,
                              ),
                              ElevatedButton(
                                style: ButtonStyle(
                                  backgroundColor: WidgetStateProperty.all<
                                          Color>(
                                      const Color.fromARGB(255, 0, 122, 255)),
                                ),
                                onPressed: _fetchAndDisplayRoads,
                                child: Text(
                                  'Fetch Road',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      fontFamily:
                                          GoogleFonts.roboto().fontFamily),
                                ),
                              ),
                            ]
                          : [
                              if (_showCleanRouteGuide)
                                Text('Tap on a route to remove it',
                                    style: TextStyle(
                                        fontSize: 13,
                                        fontFamily:
                                            GoogleFonts.roboto().fontFamily)),
                              if (_showCleanRouteGuide)
                                const SizedBox(height: 10),
                              _routeProcessed
                                  ? Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.center,
                                      children: [
                                        const SizedBox(height: 10),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Street Length:',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily:
                                                      GoogleFonts.roboto()
                                                          .fontFamily),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              streetLength,
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily:
                                                      GoogleFonts.roboto()
                                                          .fontFamily),
                                            ),
                                            const SizedBox(width: 10),
                                            Text('km',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontFamily:
                                                        GoogleFonts.roboto()
                                                            .fontFamily)),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              'Route Length:',
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontFamily:
                                                      GoogleFonts.roboto()
                                                          .fontFamily),
                                            ),
                                            const SizedBox(width: 10),
                                            Text(
                                              routeLength,
                                              style: TextStyle(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  fontFamily:
                                                      GoogleFonts.roboto()
                                                          .fontFamily),
                                            ),
                                            const SizedBox(width: 10),
                                            Text('km',
                                                style: TextStyle(
                                                    fontSize: 14,
                                                    fontFamily:
                                                        GoogleFonts.roboto()
                                                            .fontFamily)),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                    )
                                  : Column(
                                      children: [
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            fixedSize:
                                                WidgetStateProperty.all<Size>(
                                              const Size.fromWidth(140),
                                            ),
                                            backgroundColor:
                                                WidgetStateProperty.all<Color>(
                                              const Color.fromARGB(
                                                  255, 0, 122, 255),
                                            ),
                                          ),
                                          onPressed: _isProcessingPath
                                              ? null
                                              : _toggleDeleteMode,
                                          child: _isProcessingPath
                                              ? const CircularProgressIndicator(
                                                  valueColor:
                                                      AlwaysStoppedAnimation<
                                                          Color>(Colors.white),
                                                )
                                              : Text(
                                                  _isDeletingPath
                                                      ? 'Process Route'
                                                      : 'Clean Route',
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 14,
                                                    fontFamily:
                                                        GoogleFonts.roboto()
                                                            .fontFamily,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                        ),
                                        const SizedBox(height: 10),
                                        ElevatedButton(
                                          style: ButtonStyle(
                                            fixedSize:
                                                WidgetStateProperty.all<Size>(
                                                    const Size.fromWidth(140)),
                                            backgroundColor:
                                                WidgetStateProperty.all<Color>(
                                                    const Color.fromARGB(
                                                        255, 255, 255, 255)),
                                          ),
                                          onPressed: _reset,
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              const Icon(
                                                Icons.refresh,
                                                color: Color.fromARGB(
                                                    255, 255, 59, 48),
                                                size: 20,
                                              ),
                                              const SizedBox(width: 5),
                                              Text(
                                                'Cancel',
                                                style: TextStyle(
                                                  color: const Color.fromARGB(
                                                      255, 255, 59, 48),
                                                  fontSize: 14,
                                                  fontFamily:
                                                      GoogleFonts.roboto()
                                                          .fontFamily,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                            ],
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
