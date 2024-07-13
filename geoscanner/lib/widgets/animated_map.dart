import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart';

class AnimatedMap extends StatefulWidget {
  const AnimatedMap(
      {super.key,
      required this.routeCoordinates,
      required this.showLocationMarker});

  final List<LatLng> routeCoordinates;
  final bool showLocationMarker;

  @override
  State<AnimatedMap> createState() => _AnimatedMapState();
}

class _AnimatedMapState extends State<AnimatedMap> {
  late GoogleMapController _controller;
  Location _location = Location();
  Marker? _currentLocationMarker;

  @override
  void initState() {
    super.initState();
    if (widget.showLocationMarker) {
      _location.onLocationChanged.listen((LocationData currentLocation) {
        _updateMarker(currentLocation);
      });
    }
  }

  void _updateMarker(LocationData currentLocation) {
    final marker = Marker(
      markerId: const MarkerId('current_location'),
      position: LatLng(currentLocation.latitude!, currentLocation.longitude!),
      infoWindow: const InfoWindow(title: 'Current Location'),
    );

    setState(() {
      _currentLocationMarker = marker;
    });
  }

  int _routeIndex = 0;

  bool _isManualAnimation = false;

  List<LatLng> _displayedRouteCoords = [];

  void _onMapCreated(GoogleMapController controller) {
    _controller = controller;
    _setMapStyle();
    _startRouteAnimation(16.0);
  }

  void _setMapStyle() async{
    String style =
        await DefaultAssetBundle.of(context).loadString('assets/silver_map_style.json');
    // ignore: deprecated_member_use
    _controller.setMapStyle(style);
  }

  void _startRouteAnimation(double zoomLevel) async {
    for (int i = 0; i < widget.routeCoordinates.length; i++) {
      await Future.delayed(const Duration(seconds: 1), () {
        setState(() {
          _routeIndex = i;
          _displayedRouteCoords =
              widget.routeCoordinates.sublist(0, _routeIndex + 1);
        });
        _controller.animateCamera(
          CameraUpdate.newLatLngZoom(
              widget.routeCoordinates[_routeIndex], zoomLevel),
        );
      });
      if (i == widget.routeCoordinates.length - 1) {
        _isManualAnimation = true;
      }
    }
  }

  void _manualAnimationBefore() {
    if (_routeIndex > 0) {
      setState(() {
        _routeIndex--;
        _displayedRouteCoords =
            widget.routeCoordinates.sublist(0, _routeIndex + 1);
      });
    }
    if (_routeIndex == 0) {
      setState(() {
        _routeIndex = widget.routeCoordinates.length - 1;
        _displayedRouteCoords =
            widget.routeCoordinates.sublist(0, _routeIndex + 1);
      });
    }
    _controller.animateCamera(
      CameraUpdate.newLatLng(widget.routeCoordinates[_routeIndex]),
    );
  }

  void _manualAnimationAfter() {
    if (_routeIndex < widget.routeCoordinates.length - 1) {
      setState(() {
        _routeIndex++;
        _displayedRouteCoords =
            widget.routeCoordinates.sublist(0, _routeIndex + 1);
      });
    }
    if (_routeIndex == widget.routeCoordinates.length - 1) {
      setState(() {
        _routeIndex = 0;
        _displayedRouteCoords =
            widget.routeCoordinates.sublist(0, _routeIndex + 1);
      });
    }
    _controller.animateCamera(
      CameraUpdate.newLatLng(widget.routeCoordinates[_routeIndex]),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.bottomCenter,
      children: [
        GoogleMap(
          onMapCreated: _onMapCreated,
          initialCameraPosition:
              CameraPosition(target: widget.routeCoordinates[0]),
          myLocationButtonEnabled: false,
          // show location marker if showLocationMarker is true
          markers: widget.showLocationMarker
              ? {
                  if (_currentLocationMarker != null) _currentLocationMarker!,
                }
              : {},
          polylines: {
            Polyline(
              polylineId: const PolylineId('route'),
              points: _displayedRouteCoords,
              color: Colors.blue,
              width: 5,
              startCap: Cap.roundCap,
              endCap: Cap.roundCap,
              jointType: JointType.mitered,
              geodesic: true,
            ),
          },
        ),
        // Put a center icon on the map
        Positioned(
          // Center the icon
          child: Center(
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
        ),
        if (_isManualAnimation)
          Positioned(
            bottom: 10,
            child: Container(
              decoration: BoxDecoration(color: Colors.white.withOpacity(0)),
              child: Row(
                children: [
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: _manualAnimationBefore,
                    child: const Icon(Icons.arrow_circle_left,
                        color: Colors.black),
                  ),
                  const SizedBox(width: 50),
                  ElevatedButton(
                    style: ButtonStyle(
                      backgroundColor:
                          WidgetStateProperty.all<Color>(Colors.white),
                    ),
                    onPressed: _manualAnimationAfter,
                    child: const Icon(Icons.arrow_circle_right,
                        color: Colors.black),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
