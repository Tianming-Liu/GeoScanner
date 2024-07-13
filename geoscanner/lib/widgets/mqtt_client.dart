import 'dart:async';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

class MqttService {
  late MqttServerClient client;
  final String broker;
  final int port;
  final String mqttUsername;
  final String mqttPassword;
  final String email;
  final Function(List<MqttReceivedMessage<MqttMessage>>) onMessage;
  final Function() onConnectedCallback;

  MqttService({
    required this.broker,
    required this.port,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.email,
    required this.onMessage,
    required this.onConnectedCallback,
  });

  Future<void> setupMqttClient() async {
    client = MqttServerClient(broker, '');
    client.port = port;
    client.secure = false;
    client.logging(on: true);
    client.keepAlivePeriod = 30;
    client.onDisconnected = _onDisconnected;
    client.onConnected = _onConnected;
    client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('FlutterClient')
        .startClean()
        .withWillQos(MqttQos.atMostOnce);
    client.connectionMessage = connMessage;

    try {
      await client.connect(mqttUsername, mqttPassword);
    } catch (e) {
      print('Exception: $e');
      client.disconnect();
    }
  }

  void _onConnected() {
    print('Connected');
    client.subscribe('$email/ESP32/Note', MqttQos.atMostOnce);
    client.updates!.listen(onMessage);
    onConnectedCallback();
  }

  void _onDisconnected() {
    print('Disconnected');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to $topic');
  }

  void disconnect() {
    client.disconnect();
  }

  void publishMessage(String topic, String message) {
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    client.publishMessage(topic, MqttQos.atMostOnce, builder.payload!);
  }
}
