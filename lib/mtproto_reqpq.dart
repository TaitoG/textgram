// mtproto_reqpq.dart
import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'parse_respq.dart';
const String dcIp = '149.154.167.40';
const int dcPort = 443;
const Duration readTimeout = Duration(seconds: 6);

void main() async {

}

Future<void> reqpq() async {
  print('Try transports to $dcIp:$dcPort');

  // build single req_pq_multi message (message bytes without transport prefix)
  final Uint8List reqPqPayload = _buildReqPqMulti();

  // Try Abridged (with initial 0xEF)
  print('\n== Trying Abridged (prefix 0xEF) ==');
  var resp = await _connectAndSend(prefixType: _PrefixType.abridged, payload: reqPqPayload);
  if (resp != null) {
    final hex = _bytesToHex(resp);
    parse_respq(hex);
    return;
  }

  // Try Intermediate (with initial 0xEEEEEEEE)
  print('\n== Trying Intermediate (prefix 0xEEEEEEEE) ==');
  resp = await _connectAndSend(prefixType: _PrefixType.intermediate, payload: reqPqPayload);
  if (resp != null) {
    final hex = _bytesToHex(resp);
    parse_respq(hex);
    return;
  }

  // Try Padded Intermediate (with initial 0xDDDDDDDD)
  print('\n== Trying Padded Intermediate (prefix 0xDDDDDDDD) ==');
  resp = await _connectAndSend(prefixType: _PrefixType.paddedIntermediate, payload: reqPqPayload);
  if (resp != null) {
    final hex = _bytesToHex(resp);
    parse_respq(hex);
    return;
  }

  print('\nNo response received with these transports. Next step — implement obfuscated transport (requires secret or implementation ported from clients).');
}

/// Transport prefix types
enum _PrefixType { abridged, intermediate, paddedIntermediate }

/// Now returns received bytes (Uint8List) or null on failure/timeout.
Future<Uint8List?> _connectAndSend({required _PrefixType prefixType, required Uint8List payload}) async {
  Socket? socket;
  try {
    socket = await Socket.connect(dcIp, dcPort, timeout: Duration(seconds: 5));
    print('Connected.');

    // send initial prefix if required
    switch (prefixType) {
      case _PrefixType.abridged:
        socket.add(Uint8List.fromList([0xEF])); // single byte prefix
        break;
      case _PrefixType.intermediate:
        socket.add(_intToBytesLE(0xEEEEEEEE, 4)); // 4-byte prefix
        break;
      case _PrefixType.paddedIntermediate:
        socket.add(_intToBytesLE(0xDDDDDDDD, 4)); // 4-byte prefix
        break;
    }

    // wrap payload according to transport rules
    final Uint8List wrapped;
    if (prefixType == _PrefixType.abridged) {
      wrapped = _abridgedWrap(payload);
    } else {
      wrapped = _intermediateWrap(payload);
    }

    socket.add(wrapped);
    await socket.flush();
    print('Sent payload. Waiting for response (timeout: ${readTimeout.inSeconds}s)...');

    // wait for response with timeout
    final completer = Completer<Uint8List?>();
    final buffer = BytesBuilder();
    bool got = false;
    StreamSubscription<Uint8List>? sub;

    void onData(Uint8List data) {
      got = true;
      buffer.add(data);
      // We resolve on first chunk (if you want to wait for full message,
      // adjust logic to parse length & wait more)
      final b = buffer.toBytes();
      print('>>> Received ${b.length} bytes (hex):');
      print(_bytesToHex(b));
      if (!completer.isCompleted) completer.complete(b);
    }

    sub = socket.listen(onData,
        onError: (e) {
          print('Socket error: $e');
          if (!completer.isCompleted) completer.complete(null);
        },
        onDone: () {
          if (!got) {
            print('Socket done without data.');
            if (!completer.isCompleted) completer.complete(null);
          }
        },
        cancelOnError: true);

    // timeout
    final timer = Timer(readTimeout, () {
      if (!completer.isCompleted) completer.complete(null);
    });

    final result = await completer.future;
    timer.cancel();
    await sub?.cancel();
    try {
      await socket.close();
    } catch (_) {}
    return result;
  } catch (e) {
    print('Connection/send error: $e');
    try {
      await socket?.close();
    } catch (e) {}
    return null;
  }
}

/// Build actual MTProto message (auth_key_id=0, message_id, length, body(req_pq_multi))
Uint8List _buildReqPqMulti() {
  final constructor = 0xBE7E8EF1;
  final nonce = _randomBytes(16);

  final bodyBuilder = BytesBuilder();
  bodyBuilder.add(_intToBytesLE(constructor, 4));
  bodyBuilder.add(nonce);
  final body = bodyBuilder.toBytes();

  final header = BytesBuilder();
  header.add(_int64ToBytesLE(0)); // auth_key_id = 0
  final messageId = _generateMessageId();
  header.add(_int64ToBytesLE(messageId));
  header.add(_intToBytesLE(body.length, 4));
  header.add(body);

  final message = header.toBytes();
  // pad message to multiple of 4 bytes
  return _padTo4(message);
}

/// Abridged wrapping: single-byte length if len/4 < 127, else 0x7f + 3 bytes little-endian of length
Uint8List _abridgedWrap(Uint8List payload) {
  final lenDiv4 = payload.length ~/ 4;
  final builder = BytesBuilder();
  if (lenDiv4 < 0x7f) {
    builder.add([lenDiv4]);
  } else {
    builder.add([0x7f]);
    builder.add(_intToBytesLE(payload.length, 3));
  }
  builder.add(payload);
  return builder.toBytes();
}

/// Intermediate wrapping: 4-byte little-endian length followed by payload
Uint8List _intermediateWrap(Uint8List payload) {
  final builder = BytesBuilder();
  builder.add(_intToBytesLE(payload.length, 4));
  builder.add(payload);
  return builder.toBytes();
}

/// helpers
Uint8List _randomBytes(int n) {
  final rng = Random.secure();
  final b = Uint8List(n);
  for (int i = 0; i < n; i++) b[i] = rng.nextInt(256);
  return b;
}

Uint8List _intToBytesLE(int value, int length) {
  final bb = ByteData(length);
  for (int i = 0; i < length; i++) {
    bb.setUint8(i, (value >> (8 * i)) & 0xFF);
  }
  return bb.buffer.asUint8List();
}

Uint8List _int64ToBytesLE(int value) {
  final bb = ByteData(8);
  var v = value;
  for (int i = 0; i < 8; i++) {
    bb.setUint8(i, (v & 0xFF));
    v = v >> 8;
  }
  return bb.buffer.asUint8List();
}

BigInt _generateMessageIdBig() {
  final ms = DateTime.now().toUtc().millisecondsSinceEpoch;
  // message_id is 64-bit: unix_seconds << 32 | (ms_part << 2) ... keep simple
  final seconds = BigInt.from(ms ~/ 1000);
  final mid = (seconds << 32) | BigInt.zero;
  return mid;
}

int _generateMessageId() {
  // convert BigInt to int (platform-dependent). This is acceptable for tests on 64-bit.
  return _generateMessageIdBig().toInt();
}

Uint8List _padTo4(Uint8List bytes) {
  final pad = (4 - (bytes.length % 4)) % 4;
  if (pad == 0) return bytes;
  final b = BytesBuilder();
  b.add(bytes);
  b.add(Uint8List(pad));
  return b.toBytes();
}

String _bytesToHex(Uint8List data) {
  final sb = StringBuffer();
  for (final b in data) {
    sb.write(b.toRadixString(16).padLeft(2, '0'));
    sb.write(' ');
  }
  return sb.toString();
}
