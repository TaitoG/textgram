// lib/core/network/mtproto_client.dart
import 'dart:io';
import 'dart:typed_data';

class MTProtoClient {
  final String host;
  final int port;
  late Socket _socket;

  MTProtoClient({this.host = "149.154.167.50", this.port = 443}); // Telegram DC1

  Future<void> connect() async {
    _socket = await Socket.connect(host, port);
    print("✅ Connected to Telegram MTProto: $host:$port");
  }

  void send(Uint8List bytes) {
    _socket.add(bytes);
  }

  void listen(void Function(Uint8List) onData) {
    _socket.listen(onData);
  }

  void close() {
    _socket.close();
  }
}