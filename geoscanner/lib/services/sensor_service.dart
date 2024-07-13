import 'dart:async';
import 'package:location/location.dart';
import 'package:noise_meter/noise_meter.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

class SensorService {
  bool isReady = false;
  Location _location = Location();
  NoiseMeter _noiseMeter = NoiseMeter();
  StreamSubscription<LocationData>? _locationSubscription;

  Future<void> checkPermissions(Function(bool) callback) async {
    // Check location permission
    PermissionStatus locationPermission = await _location.requestPermission();
    bool serviceEnabled = await _location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await _location.requestService();
    }

    // Check microphone permission
    ph.PermissionStatus microphonePermissionStatus =
        await ph.Permission.microphone.request();

    callback(locationPermission == PermissionStatus.granted &&
        serviceEnabled &&
        microphonePermissionStatus == ph.PermissionStatus.granted);
  }

  void startLocationAndNoiseTracking(Function(LocationData, double?) callback) {
    _location.enableBackgroundMode(enable: true);
    _locationSubscription =
        _location.onLocationChanged.listen((LocationData locationData) async {
      final noiseReading = await _getNoiseLevel();
      callback(locationData, noiseReading?.meanDecibel);
    });
  }

  Future<NoiseReading?> _getNoiseLevel() async {
    try {
      return await _noiseMeter.noise.first;
    } catch (err) {
      print(err);
      return null;
    }
  }

  void stopTracking() {
    _locationSubscription?.cancel();
  }
}
