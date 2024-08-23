import 'package:flutter/material.dart';

class AnimatedHistory extends StatefulWidget {
  const AnimatedHistory({Key? key}) : super(key: key);

  @override
  AnimatedHistoryState createState() => AnimatedHistoryState();
}

class AnimatedHistoryState extends State<AnimatedHistory>
    with TickerProviderStateMixin {
  final List<Map<String, dynamic>> _buttonHistory = [];
  late AnimationController _controller;
  final double trackWidth = 320.0;
  final double trackHeight = 75.0;
  final double horizontalPadding = 0.0;
  bool _isAnimating = false; // 初始化时不运行
  late DateTime _pauseTime;
  late Duration _pausedDuration;
  bool _isPaused = false; // 增加一个标志位来判断是否在暂停状态

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 5),
      vsync: this,
    )..addListener(() {
        setState(() {});
      });
    _pausedDuration = Duration.zero;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void addItem(String button) {
    final now = DateTime.now();
    setState(() {
      _buttonHistory.add({
        'timestamp': now.subtract(_pausedDuration),
        'button': button,
      });
      if (_isPaused) {
        print('Paused - Added item: $button at ${now.subtract(_pausedDuration)}');
      }
    });
  }

  void toggleAnimation() {
    setState(() {
      if (_isAnimating) {
        _controller.stop();
        _pauseTime = DateTime.now();
        _isPaused = true; // 设置为暂停状态
        print('Animation paused at $_pauseTime');
      } else {
        final now = DateTime.now();
        _pausedDuration += now.difference(_pauseTime);
        _controller.repeat();
        _isPaused = false; // 取消暂停状态
        print('Animation resumed at $now with paused duration $_pausedDuration');
      }
      _isAnimating = !_isAnimating;
    });
  }

  void startAnimation() {
    setState(() {
      _controller.repeat();
      _isAnimating = true;
      _isPaused = false; // 取消暂停状态
      print('Animation started');
    });
  }

  void stopAnimation() {
    setState(() {
      _controller.stop();
      _controller.value = 0.0;
      _isAnimating = false;
      _pausedDuration = Duration.zero;
      _isPaused = false; // 取消暂停状态
      print('Animation stopped');
    });
  }

  Widget _buildItem(DateTime timestamp, DateTime now, double height,
      {DateTime? previousTimestamp, String? previousButton, String? button}) {
    final millisecondsAgo =
        now.subtract(_pausedDuration).difference(timestamp).inMilliseconds;
    final position =
        (7750 - millisecondsAgo) / 7750 * (trackWidth - 2 * horizontalPadding) +
            horizontalPadding;
    const double verticalSpacing = 15.0; // 调整垂直间距

    final topPosition = button == 'image'
        ? height * (1 - verticalSpacing / height)
        : button == 'espSensor'
            ? height * verticalSpacing / height - 10
            : height * verticalSpacing / height;

    final previousPosition = previousTimestamp != null
        ? (7750 -
                    now
                        .subtract(_pausedDuration)
                        .difference(previousTimestamp)
                        .inMilliseconds) /
                7750 *
                (trackWidth - 2 * horizontalPadding) +
            horizontalPadding
        : null;

    Color? lineColor;
    if (previousButton != null &&
        (button == 'image' || button == 'espSensor')) {
      if (previousButton == 'image' && button == 'espSensor') {
        lineColor = Colors.grey.shade200; // image to espSensor
      } else if (previousButton == 'image' && button == 'image') {
        lineColor = Colors.red.shade200; // image to image
      } else if (previousButton == 'espSensor' && button == 'image') {
        lineColor = Colors.green; // espSensor to image
      } else if (previousButton == 'espSensor' && button == 'espSensor') {
        lineColor = Colors.green.shade200; // espSensor to espSensor
      }
    }

    if (_isPaused) {
      print('Paused - Building item: $button at $position');
    }

    return Stack(
      children: [
        if (previousPosition != null &&
            (previousButton == 'image' || previousButton == 'espSensor') &&
            (button == 'image' || button == 'espSensor'))
          Positioned(
            left: previousPosition,
            top: topPosition +
                (button == 'image'
                    ? -20
                    : button == 'espSensor'
                        ? 20
                        : 0),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                if (_isPaused) {
                  print('Paused - AnimatedBuilder called with value: ${_controller.value}');
                }
                // 不跳过重建，而是保持当前状态
                return Container(
                  width: position - previousPosition,
                  height: 7.5,
                  decoration: BoxDecoration(
                    color: lineColor,
                    borderRadius: BorderRadius.circular(5), // 圆头端点
                  ),
                );
              },
            ),
          ),
        Positioned(
          left: position,
          top: topPosition,
          child: Column(
            children: [
              if (button == 'image')
                const CircleAvatar(
                    radius: 5,
                    backgroundColor: Color.fromARGB(255, 10, 132, 255)),
              if (button == 'espSensor')
                const CircleAvatar(radius: 5, backgroundColor: Colors.green),
              if (button == 'phoneSensor')
                CircleAvatar(
                    radius: 5, backgroundColor: Colors.green.withOpacity(0.5)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTrack(List<Map<String, dynamic>> history) {
    if (_isPaused) {
      return Center(
        child: Text(
          'Record Paused...',
          style: TextStyle(fontSize: 20, color: Colors.red),
        ),
      );
    }

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final now = DateTime.now();
        DateTime? previousTimestamp;
        String? previousButton;
        if (_isPaused) {
          print('Paused - AnimatedBuilder rebuild at ${now.subtract(_pausedDuration)}');
        }
        return CustomPaint(
          size: Size(trackWidth, trackHeight),
          painter: TrackPainter(),
          child: Stack(
            children: history.map((entry) {
              final timestamp = entry['timestamp'] as DateTime;
              final button = entry['button'] as String;

              final item = _buildItem(
                timestamp,
                now,
                trackHeight,
                previousTimestamp: previousTimestamp,
                previousButton: previousButton,
                button: button,
              );

              if (button == 'image' || button == 'espSensor') {
                previousTimestamp = timestamp;
                previousButton = button;
              }

              return item;
            }).toList(),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: Colors.grey.shade100.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: List.generate(10, (index) {
          return BoxShadow(
            color: Colors.grey.shade100.withOpacity(0.1),
            spreadRadius: 1,
            blurRadius: 5,
            offset: const Offset(0, 3),
          );
        }),
      ),
      height: trackHeight,
      width: trackWidth,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        child: _buildTrack(_buttonHistory),
      ),
    );
  }
}

class TrackPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..strokeWidth = 0.25;

    // Draw the decoration lines
    const dashWidth = 1;
    const dashSpace = 2;
    double startX = 0;
    final middleY = size.height / 2;

    final timelineY1 = middleY - 7.5;
    final timelineY2 = middleY + 7.5;

    while (startX < size.width) {
      canvas.drawLine(Offset(startX, timelineY1),
          Offset(startX + dashWidth, timelineY1), paint);
      startX += dashWidth + dashSpace;
    }
    startX = 0;
    while (startX < size.width) {
      canvas.drawLine(Offset(startX, timelineY2),
          Offset(startX + dashWidth, timelineY2), paint);
      startX += dashWidth + dashSpace;
    }
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) {
    return false;
  }
}
