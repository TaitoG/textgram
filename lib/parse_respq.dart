// parse_respq_fixed.dart
// Robust parser for resPQ responses (MTProto).
// - Proper TL-string handling
// - Safe search for vector<long> constructor
// - Safe BigInt/Uint64 reading (no signed/overflow issues)

import 'dart:typed_data';

void main() {
  final hex = '''
19 00 00 00 00 00 00 00 00 01 94 ca 06 50 7c ea 68
50 00 00 00 63 24 16 05 f4 56 c9 77 88 70 75 04 ef
24 e9 43 a4 fa b0 24 44 c9 4c db 34 8f b7 f0 8c 8b
47 89 3e 1a ee cc 08 1c 71 3b ca de b2 c2 bf 00 00
00 15 c4 b5 1c 03 00 00 00 85 fd 64 de 85 1d 9d d0
a5 b7 f7 09 35 5f c3 0b 21 6b e8 6c 02 2b b4 c3
''';

  final bytes = _hexToBytes(hex);
  final reader = _BytesReader(bytes);

  // --- Handle abridged transport header (1 or 4 bytes)
  final first = reader.peekUint8(0);
  final headerSkip = (first < 0x7f) ? 1 : 4;
  if (bytes.length <= headerSkip) {
    print('Buffer too small for transport header');
    return;
  }
  final r = _BytesReader(bytes.sublist(headerSkip));

  // --- MTProto message header
  if (r.remainingLength < 8 + 8 + 4) {
    print('Buffer too small for MTProto header');
    return;
  }
  final authKeyId = r.readUint64LE();
  final msgId = r.readUint64LE();
  final msgLen = r.readUint32LE();
  print('auth_key_id: 0x${authKeyId.toRadixString(16)}');
  print('message_id:  0x${msgId.toRadixString(16)} ($msgId)');
  print('message_len: $msgLen bytes');

  // --- constructor
  if (r.remainingLength < 4) {
    print('Buffer too small for constructor');
    return;
  }
  final constructor = r.readUint32LE();
  print('constructor: 0x${constructor.toRadixString(16)}');
  if (constructor != 0x05162463) {
    print('Warning: constructor != resPQ (0x05162463). Still attempting to parse.');
  } else {
    print('-> Looks like ResPQ.');
  }

  // --- client_nonce (16) and server_nonce (16)
  if (r.remainingLength < 16 + 16) {
    print('Not enough data for nonces');
    return;
  }
  final clientNonce = r.readBytes(16);
  final serverNonce = r.readBytes(16);

  print('client nonce: ${_bytesToHex(clientNonce)}');
  print('server nonce: ${_bytesToHex(serverNonce)}');

  // --- pq is TL-string (bytes)
  if (r.remainingLength < 1) {
    print('Not enough data for pq');
    return;
  }
  final pqBytes = r.readTLString(); // safe TL reader
  print('pq (hex): ${_bytesToHex(pqBytes)}');

  // --- Now remaining bytes should contain vector<long> fingerprints and maybe extra data.
  final remaining = r.remainingBytes();
  if (remaining.isEmpty) {
    print('No remaining bytes after pq');
    return;
  }

  // search for vector constructor bytes: 0x1cb5c415 encoded as little-endian bytes [0x15,0xc4,0xb5,0x1c]
  final pattern = Uint8List.fromList([0x15, 0xc4, 0xb5, 0x1c]);
  final idx = _indexOfSubsequence(remaining, pattern);
  if (idx == -1) {
    print('Vector constructor not found. Remaining hex: ${_bytesToHex(remaining)}');
    return;
  }
  print('Found vector constructor at offset $idx within remaining payload.');

  // create a reader starting at that offset inside remaining bytes
  final rr = _BytesReader(remaining.sublist(idx));

  // read vector constructor (should be 0x1cb5c415)
  final vecConst = rr.readUint32LE();
  if (vecConst != 0x1cb5c415) {
    print('Odd: vecConst != expected 0x1cb5c415 (got 0x${vecConst.toRadixString(16)})');
    return;
  }

  if (rr.remainingLength < 4) {
    print('Not enough data for vector count');
    return;
  }
  final count = rr.readUint32LE();
  print('fingerprints count: $count');

  // sanity check: avoid trying to read an enormous count that would overflow buffer
  if (count > 1024) {
    print('Count suspiciously large ($count). Aborting to avoid OOM or out-of-range reads.');
    return;
  }

  final fps = <String>[];
  for (int i = 0; i < count; i++) {
    if (rr.remainingLength < 8) {
      print('Not enough bytes for fingerprint #$i — stopping.');
      break;
    }
    final fp = rr.readUint64LEBigInt(); // return BigInt to avoid signed issues
    // Convert to 8-byte little-endian hex (16 hex chars)
    final fpBytes = _u64ToBytesLE(fp);
    final fpHex = _bytesToHex(fpBytes);
    fps.add(fpHex);
    print('fingerprint[$i]: 0x$fpHex');
  }

  final left = rr.remainingBytes();
  print('remaining after vector: ${left.length} bytes; hex: ${_bytesToHex(left)}');
}

/// ---------- helpers & reader ----------

Uint8List _hexToBytes(String hex) {
  final cleaned = hex.replaceAll(RegExp(r'[^0-9a-fA-F]'), '');
  if (cleaned.length % 2 != 0) {
    throw FormatException('Hex string length must be even');
  }
  final out = Uint8List(cleaned.length ~/ 2);
  for (int i = 0; i < cleaned.length; i += 2) {
    out[i ~/ 2] = int.parse(cleaned.substring(i, i + 2), radix: 16);
  }
  return out;
}

String _bytesToHex(Uint8List b) => b.map((e) => e.toRadixString(16).padLeft(2, '0')).join();

int _indexOfSubsequence(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty) return 0;
  if (haystack.length < needle.length) return -1;
  for (int i = 0; i <= haystack.length - needle.length; i++) {
    var ok = true;
    for (int j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) {
        ok = false;
        break;
      }
    }
    if (ok) return i;
  }
  return -1;
}

Uint8List _u64ToBytesLE(BigInt v) {
  final out = Uint8List(8);
  BigInt tmp = v;
  for (int i = 0; i < 8; i++) {
    out[i] = (tmp & BigInt.from(0xFF)).toInt();
    tmp = tmp >> 8;
  }
  return out;
}

class _BytesReader {
  final Uint8List data;
  int pos = 0;
  _BytesReader(this.data);

  int get remainingLength => data.length - pos;

  int peekUint8(int atOffset) {
    final idx = atOffset;
    if (idx < 0 || idx >= data.length) throw RangeError.index(idx, data);
    return data[idx];
  }

  int readUint8() {
    if (pos >= data.length) throw RangeError.index(pos, data);
    return data[pos++];
  }

  int readUint32LE() {
    if (pos + 4 > data.length) throw RangeError.index(pos + 3, data);
    final v = data.buffer.asByteData().getUint32(pos, Endian.little);
    pos += 4;
    return v;
  }

  BigInt readUint64LEBigInt() {
    if (pos + 8 > data.length) throw RangeError.index(pos + 7, data);
    // read bytes little-endian and produce BigInt
    BigInt v = BigInt.zero;
    for (int i = 0; i < 8; i++) {
      v |= (BigInt.from(data[pos + i]) << (8 * i));
    }
    pos += 8;
    return v;
  }

  int readUint64LE() {
    // convenience — might overflow on some platforms; prefer BigInt version above
    final bi = readUint64LEBigInt();
    return bi.toInt();
  }

  Uint8List readBytes(int n) {
    if (n < 0) throw ArgumentError('n < 0');
    if (pos + n > data.length) throw RangeError.index(pos + n - 1, data);
    final res = data.sublist(pos, pos + n);
    pos += n;
    return Uint8List.fromList(res);
  }

  Uint8List remainingBytes() => data.sublist(pos);

  /// Read TL-string (as bytes). Handles short and 254-case and padding.
  Uint8List readTLString() {
    if (pos >= data.length) throw RangeError.index(pos, data);
    final first = readUint8();
    int len;
    if (first == 254) {
      if (pos + 3 > data.length) throw RangeError.index(pos + 2, data);
      final b1 = readUint8();
      final b2 = readUint8();
      final b3 = readUint8();
      len = b1 | (b2 << 8) | (b3 << 16);
    } else {
      len = first;
    }
    if (pos + len > data.length) throw RangeError.index(pos + len - 1, data);
    final bytes = readBytes(len);
    final pad = (4 - (len % 4)) % 4;
    if (pad > 0) {
      if (pos + pad > data.length) throw RangeError.index(pos + pad - 1, data);
      readBytes(pad);
    }
    return bytes;
  }
}
