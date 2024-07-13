// websocket_service.dart
import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';

class WebSocketService {
  final String serverIp;
  IOWebSocketChannel? _channel;
  Function(Uint8List data)? onBinaryMessage;
  Function(bool isConnected)? onConnectionChange;
  Function(String message)? onTextMessage;

  WebSocketService(this.serverIp);

  void connect(Function(Uint8List data) onBinaryMessageCallback,
      Function(bool isConnected) onConnectionChangeCallback,
      {Function(String message)? onTextMessageCallback}) {
    onBinaryMessage = onBinaryMessageCallback;
    onConnectionChange = onConnectionChangeCallback;
    onTextMessage = onTextMessageCallback;

    _channel = IOWebSocketChannel.connect('ws://$serverIp:81');
    _channel?.stream.listen((message) {
      if (message is List<int>) {
        if (onBinaryMessage != null) {
          onBinaryMessage!(Uint8List.fromList(message));
        }
      } else if (message is String) {
        if (onTextMessage != null) {
          onTextMessage!(message);
        }
      }
      onConnectionChange?.call(true);
    }, onDone: () {
      onConnectionChange?.call(false);
      print('WebSocket connection closed');
    }, onError: (error) {
      onConnectionChange?.call(false);
      print('WebSocket error: $error');
    });
  }

  void disconnect() {
    print('Disconnecting WebSocket...');
    _channel?.sink.close();
    _channel = null;
  }

  void sendStartCommand() {
    _channel?.sink.add('start');
  }

  void sendStopCommand() {
    _channel?.sink.add('stop');
  }
}
