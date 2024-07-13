import 'package:flutter/material.dart';

class TestPage extends StatefulWidget {
  const TestPage({Key? key}) : super(key: key);

  @override
  State<TestPage> createState() => _TestPageState();
}

class _TestPageState extends State<TestPage> with SingleTickerProviderStateMixin {
  bool _isRecording = false;
  bool _isRecordingPaused = false;
  late AnimationController _controller;
  late Animation<double> _borderAnimation;
  late Animation<Color?> _colorAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 1),
      vsync: this,
    )..repeat(reverse: true);

    _borderAnimation = Tween<double>(begin: 5.0, end: 8.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _colorAnimation = ColorTween(begin: Colors.white, end: const Color.fromARGB(255, 255, 243, 245)).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _toggleRecording() {
    setState(() {
      if (!_isRecording) {
        _isRecording = true;
        _isRecordingPaused = false;
        _controller.repeat(reverse: true);
      } else if (_isRecording && !_isRecordingPaused) {
        _isRecordingPaused = true;
        _controller.stop();
      } else if (_isRecording && _isRecordingPaused) {
        _isRecordingPaused = false;
        _controller.repeat(reverse: true);
      }
    });
  }

  BoxDecoration _buildDecoration() {
    if (_isRecording && !_isRecordingPaused) {
      return BoxDecoration(
        color: _colorAnimation.value,
        shape: BoxShape.circle,
        border: Border.all(
          color: Colors.red,
          width: _borderAnimation.value,
        ),
      );
    } else {
      return BoxDecoration(
        color: _isRecording
            ? (_isRecordingPaused ? Colors.red.shade50 : Colors.white)
            : Colors.red,
        shape: BoxShape.circle,
        border: Border.all(
        color: _isRecording
            ? (_isRecordingPaused ? Colors.red : Colors.red)
            : Colors.grey.shade300,
          width: 5.0,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: GestureDetector(
        onTap: _toggleRecording,
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 70,
              height: 70,
              decoration: _buildDecoration(),
              child: Center(
                child: !_isRecording
                    ? null
                    : (_isRecordingPaused
                        ? const Icon(
                            Icons.restart_alt,
                            color: Colors.red,
                            size: 35,
                          )
                        : const  Icon(
                            Icons.pause,
                            color: Colors.red,
                            size: 35,
                          )),
              ),
            );
          },
        ),
      ),
    );
  }
}
