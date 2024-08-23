import 'dart:async';
import 'dart:typed_data';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart';
import 'package:uuid/uuid.dart';
import 'package:loading_animation_widget/loading_animation_widget.dart';
import 'package:http/http.dart' as http;
import 'package:google_fonts/google_fonts.dart';

import 'package:geoscanner/widgets/workflow.dart';
import 'package:geoscanner/widgets/animated_history.dart';
import 'package:geoscanner/services/websocket_service.dart';
import 'package:geoscanner/services/sensor_service.dart';
import 'package:geoscanner/services/aws_websocket_service.dart';
import 'package:geoscanner/model/image_data.dart';

class TrackScreen extends StatefulWidget {
  const TrackScreen({super.key});

  @override
  State<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends State<TrackScreen> {
  late SensorService _sensorService;
  late WebSocketService _espWebSocketService;
  late AWSWebSocketService _awsWebSocketService;
  // ignore: unused_field
  late FirebaseFirestore _firestore;
  // AnimationController? _animationController;
  Uuid uuid = const Uuid();

  final GlobalKey<AnimatedHistoryState> _animatedHistoryKey =
      GlobalKey<AnimatedHistoryState>();

  //--Status variables--//
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  bool _initialSwitchDisabled = false; // Control the initial switch status
  bool _isEspWSConnected = false;
  String _sensorStatus = 'Unknown';
  // ignore: unused_field
  bool _isEspWSConnecting = false;

  bool _showUploadButton = false;
  bool _isUploading2Aws = false;
  bool _isUploading2Fb = false;
  bool _isImageUploadComplete = false;
  bool _isSensorUploadComplete = false;
  double _uploadImageProgress = 0.0;

  bool _isSyncingData = false;
  bool _isDataSyncComplete = false;

  //--Data variables--//
  String _currentRecordId = '';
  String _currentTime = '';
  String _startTime = '';
  String _endTime = '';
  String email = '';
  String userId = '';
  LocationData? _currentLocation;
  double? _noiseLevel;
  List<String> notes = [];
  List<ImageData> _imageDataList = [];
  List<Map<String, dynamic>> _totalSensorData = [];

  //Define the Workflow Steps
  List<WorkflowStep> _initialSteps = [
    WorkflowStep(
      'Network Setting Initialization',
      icon: Icons.wifi_tethering,
    ),
    WorkflowStep(
      'Sensing Module Initialization',
      icon: Icons.sensors,
      subSteps: [
        WorkflowSubStep(
          'Local Sensor Module',
          icon: Icons.phonelink_ring,
        ),
        WorkflowSubStep(
          'ESP32 Sensor Module',
          icon: Icons.sunny_snowing,
        ),
      ],
    ),
    WorkflowStep(
      'Data Transmission Initialization',
      icon: Icons.data_usage,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getUserInfo();
    _initializeFirebase();
    _sensorService = SensorService();
    _initializeLocalSensor();
    _espWebSocketService = WebSocketService('esp32.local');
    _awsWebSocketService = AWSWebSocketService('35.178.35.159');
    // _animationController =
    //     AnimationController(vsync: this, duration: const Duration(seconds: 1))
    //       ..repeat(reverse: true);
  }

  void _getUserInfo() {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      email = user.email ?? '';
      userId = user.uid;
    }
  }

  void _initializeFirebase() {
    _firestore = FirebaseFirestore.instance;
  }

  void _initializeLocalSensor() {
    _sensorService.checkPermissions((isReady) {
      setState(() {
        _sensorService.isReady = isReady;
      });
    });
  }

  Future<void> _connectWebSocket() async {
    setState(() {
      _isEspWSConnecting = true;
      // _isEspWSConnected = true; // Update the switch state immediately
    });

    _espWebSocketService.connect(handleBinaryData, (isConnected) {
      setState(
        () {
          _isEspWSConnected = isConnected;
          _initialSteps[0].isError = !isConnected;
          _isEspWSConnecting = false;
          _updateWorkflowSteps();
        },
      );
    }, onTextMessageCallback: handleTextMessage);

    // if (_isEspWSConnected) {

    // }
  }

  void _disconnectWebSocket() {
    _espWebSocketService.disconnect();
    setState(() {
      _isEspWSConnected = false;
      _sensorStatus = 'Unknown';
      _sensorService.isReady = false;
      _resetWorkflowSteps();
    });
  }

  void handleTextMessage(String message) {
    print('Received text message: $message');
    setState(() {
      _sensorStatus = message;
    });
  }

  Future<void> _updateWorkflowSteps() async {
    // Network Setting
    setState(() {
      _initialSteps[0].isCompleted = _isEspWSConnected;
      _initialSteps[0].isError =
          !_isEspWSConnected; // Update Network Setting Error Status
    });
    await Future.delayed(const Duration(seconds: 1));

    // Local Sensor Module
    setState(() {
      _initialSteps[1].subSteps[0].isCompleted = _sensorService.isReady;
      _initialSteps[1].subSteps[0].isError =
          !_sensorService.isReady; // Update Local Sensor Module Error Status
    });
    await Future.delayed(const Duration(seconds: 1));

    // External Sensor Module
    setState(() {
      _initialSteps[1].subSteps[1].isCompleted =
          _sensorStatus == 'Both sensors initialized.';
      _initialSteps[1].subSteps[1].isError = _sensorStatus !=
          'Both sensors initialized.'; // Update External Sensor Module Error Status
    });

    // Sensing Module Initialization
    setState(() {
      _initialSteps[1].isCompleted =
          _initialSteps[1].subSteps.every((subStep) => subStep.isCompleted);
      _initialSteps[1].isError = !_initialSteps[1]
          .isCompleted; // Update Sensing Module Initialization error status
    });
    await Future.delayed(const Duration(seconds: 1));

    // Data Transmission Initialization
    setState(() {
      _initialSteps[2].isCompleted =
          _initialSteps[0].isCompleted && _initialSteps[1].isCompleted;
    });
  }

  void _toggleRecording() {
    setState(() {
      _initialSwitchDisabled = true; // Disable the switch
      if (_isRecording) {
        _isRecordingPaused = !_isRecordingPaused;
        if (_isRecordingPaused) {
          _espWebSocketService.sendStopCommand();
          _animatedHistoryKey.currentState
              ?.toggleAnimation(); // Pause the animation
        } else {
          _espWebSocketService
              .sendStartCommand(); // Send start command to ESP32
          _animatedHistoryKey.currentState
              ?.toggleAnimation(); // Resume the animation
        }
      } else {
        // Initialize the recording status parameters
        _isRecording = true;
        _isRecordingPaused = false;
        _isImageUploadComplete = false;
        _isSensorUploadComplete = false;
        _isSyncingData = false;
        _isDataSyncComplete = false;

        // Initialize the record information
        _currentRecordId = uuid.v7();
        _startTime = _formatCurrentTime();
        _animatedHistoryKey.currentState
            ?.startAnimation(); // Start the data receiving animation
        _sensorService.startLocationAndNoiseTracking(
          (locationData, noiseLevel) {
            setState(() {
              _currentLocation = locationData;
              _noiseLevel = noiseLevel;
            });
          },
        );
        _espWebSocketService.sendStartCommand(); // Send start command to ESP32
      }
    });
  }

  void handleBinaryData(Uint8List data) {
    if (_isRecording && !_isRecordingPaused) {
      // Only process data when recording and not paused
      if (data.length > 1000) {
        final imageData = ImageData(data, _currentTime, _currentRecordId);
        _imageDataList.add(imageData);
        _animatedHistoryKey.currentState?.addItem('image');
        print('Image Data Received, Total: ${_imageDataList.length}');
      } else {
        _currentTime = _formatCurrentTime();
        Float32List floatData =
            Float32List.fromList(data.buffer.asFloat32List());

        Map<String, dynamic> sensorData = {
          't': floatData[0],
          'h': floatData[1],
          'p': floatData[2],
          'g': floatData[3],
        };

        _animatedHistoryKey.currentState?.addItem('espSensor');

        Map<String, dynamic>? phoneData;
        if (_currentLocation != null && _noiseLevel != null) {
          phoneData = {
            'la': _currentLocation!.latitude,
            'lo': _currentLocation!.longitude,
            'no': _noiseLevel,
          };
          _animatedHistoryKey.currentState?.addItem('phoneSensor');
        }

        _totalSensorData.add({
          'time': _currentTime,
          'sensorData': sensorData,
          'phoneData': phoneData,
        });
        print('Total Sensor Data Updated');
      }
    }
  }

  Future<void> _connectAWSWebSocket() async {
    if (_awsWebSocketService.channel != null) {
      print('Already connected to AWS WebSocket');
      return;
    }

    _awsWebSocketService.connect(
      handleBinaryData,
      (isConnected) {
        setState(() {
          if (isConnected) {
            print('AWS WebSocket is connected');
          } else {
            print('AWS WebSocket connection lost');
          }
        });
      },
      onTextMessageCallback: (message) {
        print('Text message from AWS WebSocket: $message');
      },
      onSaveConfirmationCallback: _handleSaveConfirmation,
    );
  }

  void _handleSaveConfirmation(String message) {
    setState(() {
      _uploadImageProgress += 1 / _imageDataList.length;
      if (_uploadImageProgress >= 0.98) {
        _isUploading2Aws = false; // Upload complete, hide progress bar
        _isImageUploadComplete =
            true; // Image data upload complete, display check icon
        _awsWebSocketService
            .disconnect(); // Upload complete, disconnect from AWS WebSocket
        _checkDataSync(); // Check if all data is uploaded
      }
    });
    print(message); // Print the confirmation message
  }

  void _resetWorkflowSteps() {
    setState(() {
      for (var step in _initialSteps) {
        step.isCompleted = false;
        step.isError = false; // Reset error status
        for (var subStep in step.subSteps) {
          subStep.isCompleted = false;
          subStep.isError = false; // Reset error status
        }
      }
    });
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        AnimatedHistory(key: _animatedHistoryKey),
        const SizedBox(
          height: 25,
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              style: ButtonStyle(
                fixedSize: WidgetStateProperty.all(const Size(125, 40)),
                backgroundColor: WidgetStateProperty.all(
                    const Color.fromARGB(255, 255, 255, 255)),
              ),
              onPressed: _toggleRecording,
              child: Icon(
                _isRecording
                    ? (_isRecordingPaused ? Icons.play_arrow : Icons.pause)
                    : Icons.fiber_manual_record,
                color: _isRecording
                    ? (_isRecordingPaused ? Colors.green : Colors.yellow)
                    : Colors.red,
              ),
            ),
            ElevatedButton(
              style: ButtonStyle(
                fixedSize: WidgetStateProperty.all(const Size(125, 40)),
                backgroundColor: WidgetStateProperty.all(
                    const Color.fromARGB(255, 0, 122, 255)),
              ),
              onPressed: _finishRecording,
              child: Text(
                'Done',
                style: GoogleFonts.roboto(
                    fontSize: 14,
                    color: const Color.fromARGB(255, 255, 255, 255),
                    fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _finishRecording() {
    setState(() {
      _isRecording = false;
      _showUploadButton = true; // Show the upload button
      _initialSwitchDisabled = true; // Disable the switch
    });
    _endTime = _formatCurrentTime();
    _sensorService.stopTracking(); // Stop tracking the location and noise
    _espWebSocketService.sendStopCommand(); // Send stop command to ESP32
    _animatedHistoryKey.currentState
        ?.stopAnimation(); // Stop the data receiving animation
    _espWebSocketService.disconnect();
    _resetWorkflowSteps();
  }

  Future<void> _uploadSensorData() async {
    try {
      CollectionReference userCollection = FirebaseFirestore.instance
          .collection('data')
          .doc(userId)
          .collection('records');

      DocumentReference recordDoc = userCollection.doc(_currentRecordId);

      await recordDoc.set({
        'sensorData': _totalSensorData,
        'startTime': _startTime,
        'endTime': _endTime,
      });

      // Set delay time to simulate the uploading in case the data is too small
      await Future.delayed(const Duration(seconds: 1));

      setState(() {
        _isSensorUploadComplete = true; // Upload successful, display check icon
      });
    } catch (e) {
      setState(() {
        _isSensorUploadComplete = false; // Upload failed
      });
      print('Failed to upload sensor data: $e');
    }
  }

  void _saveData() {
    setState(() {
      _uploadImageProgress = 0.0; // Reset image upload progress
      _isUploading2Aws = true; // Display image data upload progress bar
      _isUploading2Fb = true; // Display sensor data upload progress bar
      _isSyncingData = false; // Initialize data sync status
      _isDataSyncComplete = false; // Initialize data sync status
      _isImageUploadComplete = false;
      _isSensorUploadComplete = false;
    });

    // Upload sensor data to Firebase
    _uploadSensorData().then((_) {
      setState(() {
        _isSensorUploadComplete = true;
        _isUploading2Fb = false; // Hide progress bar after upload
      });
      _checkDataSync();
    }).catchError((error) {
      print('Failed to upload sensor data: $error');
      setState(() {
        _isSensorUploadComplete = false;
        _isUploading2Fb = false; // Upload failed, hide progress bar
      });
    });

    // Connect to AWS WebSocket and send image data
    _connectAWSWebSocket().then((_) {
      for (var imageData in _imageDataList) {
        _awsWebSocketService.sendImage(imageData.toBytes());
      }
    }).catchError((error) {
      print('Failed to connect to AWS WebSocket: $error');
      setState(() {
        _isImageUploadComplete = false;
        _isUploading2Aws = false; // Upload failed, hide progress bar
      });
    });
  }

  void _checkDataSync() {
    if (_isSensorUploadComplete && _isImageUploadComplete) {
      _syncData();
    }
  }

  Future<void> _syncData() async {
    setState(() {
      _isSyncingData = true; // Display sync status
    });

    try {
      // ignore: unused_local_variable
      final response = await http.post(
        Uri.parse('http://35.178.35.159:5002/process_images'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'userId': userId, 'recordId': _currentRecordId}),
      );

      // Set delay time to simulate the sync process
      await Future.delayed(const Duration(seconds: 1));
      setState(() {
        _isDataSyncComplete = true; // Sync Complete
        _isSyncingData = false; // Hide sync status
      });

      // if (response.statusCode == 200) {
      //   setState(() {
      //     _isDataSyncComplete = true; // Sync Complete
      //     _isSyncingData = false; // Hide sync status
      //   });
      // } else {
      //   print('Failed to sync data: ${response.body}');
      //   setState(() {
      //     _isSyncingData = false; // Hide sync status
      //   });
      // }
    } catch (e) {
      print('Error syncing data: $e');
      setState(() {
        _isSyncingData = false; // Hide sync status
      });
    }
  }

  void _cancelData() {
    setState(() {
      _imageDataList.clear();
      _totalSensorData.clear();
      _showUploadButton = false; // Hide the upload button
      _initialSwitchDisabled = false; // Enable the switch
    });
  }

  String _formatCurrentTime() {
    final now = DateTime.now();
    return "${now.year}-${now.month}-${now.day}_${now.hour}:${now.minute}:${now.second}:${now.millisecond}";
  }

  @override
  void dispose() {
    _sensorService.stopTracking();
    _espWebSocketService.disconnect();
    // _animationController?.dispose();
    super.dispose();
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
        body: Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(
                height: 20,
              ),
              Workflow(
                initialSteps: _initialSteps,
                onStepCompleted: (int stepIndex, [int? subStepIndex]) {},
              ),
              const SizedBox(
                height: 10,
              ),
              Container(
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(15.0),
                  boxShadow: List.from([
                    BoxShadow(
                      color: Colors.grey.withOpacity(0.1),
                      spreadRadius: 5,
                      blurRadius: 5,
                      offset: const Offset(0, 3),
                    ),
                  ]),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    if (_isEspWSConnecting)
                      LoadingAnimationWidget.beat(
                        color: Colors.black,
                        size: 20,
                      ),
                    const Text('Initializing:'),
                    Switch(
                      value: _isEspWSConnected,
                      onChanged: _initialSwitchDisabled
                          ? null
                          : (value) {
                              if (!_isRecording) {
                                if (value) {
                                  _connectWebSocket();
                                } else {
                                  _disconnectWebSocket();
                                }
                              }
                            },
                      activeColor: Colors.green,
                      thumbIcon: WidgetStateProperty.resolveWith<Icon?>(
                        (Set<WidgetState> states) {
                          if (_isEspWSConnected) {
                            return const Icon(
                                Icons.check); // Connected state icon
                          } else {
                            return const Icon(
                                Icons.cancel); // Disconnected state icon
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                height: 15,
              ),
              if (_initialSteps[2].isCompleted)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: _buildRecordingControls(),
                ),
              if (_showUploadButton)
                Padding(
                  padding: const EdgeInsets.only(top: 16.0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          ElevatedButton.icon(
                            onPressed: _saveData,
                            style: ButtonStyle(
                              fixedSize: WidgetStateProperty.all(
                                const Size(125, 20),
                              ),
                              backgroundColor: WidgetStateProperty.all(
                                const Color.fromARGB(255, 0, 122, 255),
                              ),
                            ),
                            icon: const Icon(
                              Icons.cloud,
                              color: Colors.white,
                            ),
                            label: const Text(
                              'Save',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ElevatedButton.icon(
                            onPressed: _cancelData,
                            style: ButtonStyle(
                              fixedSize: WidgetStateProperty.all(
                                const Size(125, 20),
                              ),
                              backgroundColor: WidgetStateProperty.all(
                                const Color.fromARGB(255, 255, 255, 255),
                              ),
                              side: WidgetStateProperty.all(
                                const BorderSide(
                                    color: Color.fromARGB(255, 235, 237, 240)),
                              ),
                            ),
                            icon: const Icon(
                              Icons.cancel,
                              color: Color.fromARGB(255, 72, 94, 117),
                            ),
                            label: const Text(
                              'Cancel',
                              style: TextStyle(
                                  color: Color.fromARGB(255, 72, 94, 117)),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(
                        height: 15,
                      ),
                      Padding(
                        padding: const EdgeInsets.only(top: 16.0),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                if (_isUploading2Aws)
                                  Row(
                                    children: [
                                      const Text('Image: '),
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      LoadingAnimationWidget.inkDrop(
                                          color: Colors.black, size: 20),
                                    ],
                                  )
                                else if (_isImageUploadComplete)
                                  const Row(
                                    children: [
                                      Text('Image: '),
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                const VerticalDivider(
                                  color: Color.fromARGB(255, 8, 8, 8),
                                  thickness: 20,
                                  width: 10,
                                ),
                                if (_isUploading2Fb)
                                  Row(
                                    children: [
                                      const Text('Sensor: '),
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      LoadingAnimationWidget.inkDrop(
                                          color: Colors.black, size: 20),
                                    ],
                                  )
                                else if (_isSensorUploadComplete)
                                  const Row(
                                    children: [
                                      Text('Sensor: '),
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                const VerticalDivider(
                                  color: Color.fromARGB(255, 8, 8, 8),
                                  thickness: 20,
                                  width: 10,
                                ),
                                if (_isSyncingData)
                                  Row(
                                    children: [
                                      const Text('Syncing: '),
                                      const SizedBox(
                                        width: 15,
                                      ),
                                      LoadingAnimationWidget.inkDrop(
                                          color: Colors.black, size: 20),
                                    ],
                                  )
                                else if (_isDataSyncComplete)
                                  const Row(
                                    children: [
                                      Text('Syncing: '),
                                      SizedBox(
                                        width: 15,
                                      ),
                                      Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                        size: 22,
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ));
  }
}
