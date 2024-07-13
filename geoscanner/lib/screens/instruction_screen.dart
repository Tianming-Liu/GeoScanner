import 'package:flutter/material.dart';

class InstructionScreen extends StatelessWidget {
  const InstructionScreen({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16.0),
      children: const [
        StepCard(
          stepNumber: 1,
          icon: Icons.wifi_tethering,
          description:
              'Turn on your personal hotspot and ensure the maximum compatibility option is enabled. Otherwise, the ESP32 might not connect properly.',
        ),
        StepCard(
          stepNumber: 2,
          icon: Icons.settings_input_antenna,
          description:
              'Switch on the ESP32 device and configure the personal hotspot. Open Wi-Fi settings, connect to the network named ESP32_Config, and enter your personal hotspot\'s name and password on the configuration page.',
        ),
        StepCard(
          stepNumber: 3,
          icon: Icons.sync,
          description:
              'Once the network is connected, press the Initializing button to establish communication with the device. You will see a white light on the side of the device turn on.',
        ),
        StepCard(
          stepNumber: 4,
          icon: Icons.sensor_window,
          description: 'Start Sensing!',
        ),
      ],
    );
  }
}

class StepCard extends StatelessWidget {
  const StepCard(
      {Key? key,
      required this.stepNumber,
      required this.icon,
      required this.description})
      : super(key: key);
  final int stepNumber;
  final IconData icon;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8.0),
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              icon,
              size: 40.0,
              color: Colors.blue,
            ),
            const SizedBox(width: 16.0),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Step $stepNumber',
                    style: const TextStyle(
                      fontSize: 20.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8.0),
                  Text(
                    description,
                    style: const TextStyle(fontSize: 16.0),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
