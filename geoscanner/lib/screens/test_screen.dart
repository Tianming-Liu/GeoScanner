import 'package:flutter/material.dart';
import 'package:geoscanner/widgets/animated_history.dart'; 

class TestScreen extends StatefulWidget {
  const TestScreen({Key? key}) : super(key: key);

  @override
  _TestScreenState createState() => _TestScreenState();
}

class _TestScreenState extends State<TestScreen> {
  final GlobalKey<AnimatedHistoryState> _animatedHistoryKey =
      GlobalKey<AnimatedHistoryState>();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(color: Colors.white),
      child: Column(
        
        children: [
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.addItem('image');
            },
            child: const Text('image'),
          ),
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.addItem('espSensor');
            },
            child: const Text('espSensor'),
          ),
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.addItem('phoneSensor');
            },
            child: const Text('phoneSensor'),
          ),
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.toggleAnimation();
            },
            child: const Text('Pause/Resume'),
          ),
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.startAnimation();
            },
            child: const Text('Start'),
          ),
          ElevatedButton(
            onPressed: () {
              _animatedHistoryKey.currentState?.stopAnimation();
            },
            child: const Text('Stop'),
          ),
          const SizedBox(height: 20),
          AnimatedHistory(key: _animatedHistoryKey),
        ],
      ),
    );
  }
}
