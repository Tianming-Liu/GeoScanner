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

class _TrackScreenState extends State<TrackScreen>
    with SingleTickerProviderStateMixin {
  late SensorService _sensorService;
  late WebSocketService _espWebSocketService;
  late AWSWebSocketService _awsWebSocketService;
  // ignore: unused_field
  late FirebaseFirestore _firestore;
  AnimationController? _animationController;
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
    _animationController =
        AnimationController(vsync: this, duration: const Duration(seconds: 1))
          ..repeat(reverse: true);
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
          _initialSteps[0].isError = !isConnected; // 更新 Network Setting 错误状态
          _isEspWSConnecting = false; // 完成连接后取消加载状态
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
      _sensorService.isReady = false; // 确保Local Sensor Module步骤重置
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
      _initialSteps[0].isError = !_isEspWSConnected; // 更新 Network Setting 错误状态
    });
    await Future.delayed(const Duration(seconds: 1));

    // Local Sensor Module
    setState(() {
      _initialSteps[1].subSteps[0].isCompleted = _sensorService.isReady;
      _initialSteps[1].subSteps[0].isError =
          !_sensorService.isReady; // 更新 Local Sensor Module 错误状态
    });
    await Future.delayed(const Duration(seconds: 1));

    // External Sensor Module
    setState(() {
      _initialSteps[1].subSteps[1].isCompleted =
          _sensorStatus == 'Both sensors initialized.';
      _initialSteps[1].subSteps[1].isError = _sensorStatus !=
          'Both sensors initialized.'; // 更新 External Sensor Module 错误状态
    });

    // Sensing Module Initialization
    setState(() {
      _initialSteps[1].isCompleted =
          _initialSteps[1].subSteps.every((subStep) => subStep.isCompleted);
      _initialSteps[1].isError = !_initialSteps[1]
          .isCompleted; // 更新 Sensing Module Initialization 错误状态
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
      _initialSwitchDisabled = true; // 禁用滑块
      if (_isRecording) {
        _isRecordingPaused = !_isRecordingPaused;
        if (_isRecordingPaused) {
          _espWebSocketService.sendStopCommand(); //
          _animatedHistoryKey.currentState?.toggleAnimation(); // 暂停动画
        } else {
          _espWebSocketService.sendStartCommand(); // 发送开始命令
          _animatedHistoryKey.currentState?.toggleAnimation(); // 继续动画
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
        _espWebSocketService.sendStartCommand(); // 初次开始时发送开始命令
      }
    });
  }

  void handleBinaryData(Uint8List data) {
    if (data.length > 1000) {
      final imageData = ImageData(data, _currentTime, _currentRecordId);
      _imageDataList.add(imageData);
      _animatedHistoryKey.currentState?.addItem('image');
      print('Image Data Received, Total: ${_imageDataList.length}');
    } else {
      _currentTime =
          _formatCurrentTime(); // Update the time immediately after receiving sensor data
      Float32List floatData = Float32List.fromList(data.buffer.asFloat32List());

      Map<String, dynamic> sensorData = {
        't': floatData[0], // temperature from BME680
        'h': floatData[1], // humidity from BME680
        'p': floatData[2], // pressure from BME680
        'g': floatData[3], // gas resistance from BME680
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

      if (_isRecording && !_isRecordingPaused) {
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
      if (_uploadImageProgress >= 1.0) {
        _isUploading2Aws = false; // 上传完成，隐藏进度条
        _isImageUploadComplete = true; // 图像数据上传完成
        _awsWebSocketService.disconnect(); // 上传完成后断开连接
        _checkDataSync(); // 检查数据同步
      }
    });
    print(message); // 打印确认消息
  }

  void _resetWorkflowSteps() {
    setState(() {
      for (var step in _initialSteps) {
        step.isCompleted = false;
        step.isError = false; // 重置错误状态
        for (var subStep in step.subSteps) {
          subStep.isCompleted = false;
          subStep.isError = false; // 重置错误状态
        }
      }
    });
  }

  Widget _buildRecordingControls() {
    return Column(
      children: [
        AnimatedHistory(key: _animatedHistoryKey),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
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
              onPressed: _finishRecording,
              child: const Text('Done'),
            ),
          ],
        ),
      ],
    );
  }

  void _finishRecording() {
    setState(() {
      _isRecording = false;
      _showUploadButton = true; // 显示上传按钮
      _initialSwitchDisabled = true; // 禁用滑块
    });
    _endTime = _formatCurrentTime();
    _sensorService.stopTracking(); // 停止跟踪
    _espWebSocketService.sendStopCommand(); // 发送停止命令
    _animatedHistoryKey.currentState?.stopAnimation(); // 停止动画
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

      // 设置传感器数据
      await recordDoc.set({
        'sensorData': _totalSensorData,
        'startTime': _startTime,
        'endTime': _endTime,
      });

      // Set delay time to simulate the upload process
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
      _uploadImageProgress = 0.0; // 重置上传进度
      _isUploading2Aws = true; // 显示图像上传进度条
      _isUploading2Fb = true; // 显示传感器数据上传进度条
      _isSyncingData = false; // 初始化数据同步状态
      _isDataSyncComplete = false; // 初始化数据同步完成状态
      _isImageUploadComplete = false;
      _isSensorUploadComplete = false;
    });

    // 上传传感器数据到Firestore
    _uploadSensorData().then((_) {
      setState(() {
        _isSensorUploadComplete = true;
        _isUploading2Fb = false; // 隐藏传感器数据上传进度条
      });
      _checkDataSync();
    }).catchError((error) {
      print('Failed to upload sensor data: $error');
      setState(() {
        _isSensorUploadComplete = false;
        _isUploading2Fb = false; // 上传失败，隐藏进度条
      });
    });

    // 连接AWS WebSocket并上传图像数据
    _connectAWSWebSocket().then((_) {
      for (var imageData in _imageDataList) {
        _awsWebSocketService.sendImage(imageData.toBytes());
      }
      // 连接成功后发送所有图像数据
    }).catchError((error) {
      print('Failed to connect to AWS WebSocket: $error');
      setState(() {
        _isImageUploadComplete = false;
        _isUploading2Aws = false; // 连接失败，隐藏进度条
      });
    });
  }

  void _checkDataSync() {
    if (_isSensorUploadComplete && _isImageUploadComplete) {
      _syncData();
    }
  }

  // 数据同步函数
  Future<void> _syncData() async {
    setState(() {
      _isSyncingData = true; // 显示数据同步状态
    });

    try {
      final response = await http.post(
        Uri.parse('http://35.178.35.159:5002/process_images'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({'userId': userId, 'recordId': _currentRecordId}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _isDataSyncComplete = true; // 同步完成
          _isSyncingData = false; // 隐藏同步状态
        });
      } else {
        print('Failed to sync data: ${response.body}');
        setState(() {
          _isSyncingData = false; // 隐藏同步状态
        });
      }
    } catch (e) {
      print('Error syncing data: $e');
      setState(() {
        _isSyncingData = false; // 隐藏同步状态
      });
    }
  }

  void _cancelData() {
    setState(() {
      _imageDataList.clear();
      _totalSensorData.clear();
      _showUploadButton = false; // 隐藏上传按钮
      _initialSwitchDisabled = false; // 启用滑块
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
    _animationController?.dispose();
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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Workflow(
                initialSteps: _initialSteps,
                onStepCompleted: (int stepIndex, [int? subStepIndex]) {},
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
