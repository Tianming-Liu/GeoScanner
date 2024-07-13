import 'dart:typed_data';
import 'package:web_socket_channel/io.dart';

class AWSWebSocketService {
  final String serverIp;
  IOWebSocketChannel? _channel;
  Function(Uint8List data)? onBinaryMessage;
  Function(bool isConnected)? onConnectionChange;
  Function(String message)? onTextMessage;
  Function(String filename)? onSaveConfirmation;

  AWSWebSocketService(this.serverIp);

  IOWebSocketChannel? get channel => _channel;

  void connect(Function(Uint8List data) onBinaryMessageCallback,
      Function(bool isConnected) onConnectionChangeCallback,
      {Function(String message)? onTextMessageCallback,
      Function(String filename)? onSaveConfirmationCallback}) {
    if (_channel != null) {
      print('Already connected to AWS WebSocket');
      return;
    }

    onBinaryMessage = onBinaryMessageCallback;
    onConnectionChange = onConnectionChangeCallback;
    onTextMessage = onTextMessageCallback;
    onSaveConfirmation = onSaveConfirmationCallback;

    try {
      print('Attempting to connect to ws://$serverIp:8765');
      _channel = IOWebSocketChannel.connect('ws://$serverIp:8765');
      _channel?.stream.listen((message) {
        if (message is List<int>) {
          onBinaryMessage?.call(Uint8List.fromList(message));
        } else if (message is String) {
          onTextMessage?.call(message);
          if (onSaveConfirmation != null && message.startsWith('Saved')) {
            onSaveConfirmation!(message);
          }
        }
        onConnectionChange?.call(true);
        print('Connected to AWS WebSocket');
      }, onDone: () {
        onConnectionChange?.call(false);
        print('WebSocket connection closed');
      }, onError: (error) {
        onConnectionChange?.call(false);
        print('WebSocket error: $error');
      });
    } catch (e) {
      onConnectionChange?.call(false);
      print('Exception during WebSocket connection: $e');
    }
  }

  void disconnect() {
    print('Disconnecting WebSocket...');
    _channel?.sink.close();
    _channel = null;
    onConnectionChange?.call(false);
  }

  void sendImage(Uint8List imageData) {
    if (_channel != null && _channel?.sink != null) {
      _channel?.sink.add(imageData);
      print('Image data sent to WebSocket');
    } else {
      print('WebSocket is not connected. Unable to send image data.');
    }
  }
}
