// req_dh_params.dart
// Dart — сборка p_q_inner_data, поиск RSA ключа, шифрование и отправка req_DH_params
// Требует:
//   pointycastle: ^3.7.0
//   basic_utils: ^2.7.1
//   convert: ^3.0.2

import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:pointycastle/export.dart';
import 'package:basic_utils/basic_utils.dart';
import 'package:convert/convert.dart';

final String dcIp = '149.154.167.40';
final int dcPort = 443;
final Duration readTimeout = Duration(seconds: 6);

// значения из ResPQ
final Uint8List clientNonce = Uint8List.fromList(hex.decode('f456c97788707504ef24e943a4fab024'));
final Uint8List serverNonce = Uint8List.fromList(hex.decode('44c94cdb348fb7f08c8b47893e1aeecc'));
final String pqHex = '1c713bcadeb2c2bf';

// PEM-файл с публичными ключами Telegram (скачайте и положите рядом)
final String serverKeysPemFile = 'server_public_keys.pem';

// Fingerprints, полученные в ResPQ (8 байт, hex, little-endian)
final List<String> serverFingerprintsHex = [
  '85fd64de851d9dd0',
  'a5b7f709355fc30b',
  '216be86c022bb4c3',
];

void main() async {
  print('1) Factor pq...');
  final pq = BigInt.parse(pqHex, radix: 16);
  final factors = _factorBigInt(pq);
  if (factors.length != 2) {
    print('Не удалось найти два фактора: ${factors}');
    return;
  }
  BigInt p = factors[0];
  BigInt q = factors[1];
  if (p > q) { final t = p; p = q; q = t; }
  print('pq = $pqHex -> p = $p, q = $q');

  final newNonce = _randomBytes(32);
  print('new_nonce: ${hex.encode(newNonce)}');

  final pqBytes = _tlBytesFromBigInt(pq);
  final pBytes = _tlBytesFromBigInt(p);
  final qBytes = _tlBytesFromBigInt(q);

  final data = BytesBuilder();
  data.add(_intToBytesLE(0xA9F55F95, 4)); // constructor p_q_inner_data_dc
  data.add(pqBytes);
  data.add(pBytes);
  data.add(qBytes);
  data.add(clientNonce);
  data.add(serverNonce);
  data.add(newNonce);
  data.add(_intToBytesLE(2, 4)); // DC id
  final p_q_inner_data = data.toBytes();
  print('p_q_inner_data (len=${p_q_inner_data.length}): ${hex.encode(p_q_inner_data)}');

  // 4) Загрузка PEM ключей
  final keysPem = await _loadPemKeys(serverKeysPemFile);
  if (keysPem.isEmpty) {
    print('Не найден PEM файл с ключами: $serverKeysPemFile');
    return;
  }

  RSAPublicKey? chosenKey;
  String? chosenFp;
  for (final pem in keysPem) {
    try {
      final RSAPublicKey key = CryptoUtils.rsaPublicKeyFromPem(pem);
      final fpHex = _mtprotoFingerprint(key);
      print('Found key fingerprint candidate: $fpHex');
      if (serverFingerprintsHex.contains(fpHex)) {
        chosenKey = key;
        chosenFp = fpHex.toRadixString(16);
        break;
      }
    } catch (_) {}
  }

  if (chosenKey == null) {
    print('Не удалось найти подходящий RSA ключ среди PEM.');
    return;
  }
  print('Selected RSA key fingerprint: $chosenFp');

  // 5) SHA1 + p_q_inner_data + padding → RSA PKCS#1 v1.5
  final sha1 = Digest('SHA-1');
  final dataWithHash = BytesBuilder();
  final hash = sha1.process(p_q_inner_data);
  dataWithHash.add(hash);
  dataWithHash.add(p_q_inner_data);
  final encrypted = _rsaEncryptPKCS1v15(chosenKey, dataWithHash.toBytes());
  if (encrypted == null) {
    print('RSA encryption failed.');
    return;
  }
  print('encrypted_data len=${encrypted.length}');

  // 6) Формируем req_DH_params (TL)
  final req = BytesBuilder();
  req.add(clientNonce);
  req.add(serverNonce);
  req.add(pqBytes);
  req.add(_tlBytesFromBytes(encrypted));
  final body = req.toBytes();

  // 7) Отправка через Socket (Abridged)
  print('Connecting to $dcIp:$dcPort ...');
  try {
    final socket = await Socket.connect(dcIp, dcPort, timeout: Duration(seconds: 6));
    socket.add(Uint8List.fromList([0xEF])); // Abridged prefix
    socket.add(_abridgedWrap(body));
    await socket.flush();
    print('Sent req_DH_params, waiting for response...');
    socket.listen((data) {
      print('Received ${data.length} bytes: ${hex.encode(data)}');
    }, onDone: () {
      print('Socket done.');
    });
    await Future.delayed(Duration(seconds: 6));
    await socket.close();
  } catch (e) {
    print('Network error: $e');
  }
}

Future<void> dh() async {
  print('1) Factor pq...');
  final pq = BigInt.parse(pqHex, radix: 16);
  final factors = _factorBigInt(pq);
  if (factors.length != 2) {
    print('Не удалось найти два фактора: ${factors}');
    return;
  }
  BigInt p = factors[0];
  BigInt q = factors[1];
  if (p > q) { final t = p; p = q; q = t; }
  print('pq = $pqHex -> p = $p, q = $q');

  final newNonce = _randomBytes(32);
  print('new_nonce: ${hex.encode(newNonce)}');

  final pqBytes = _tlBytesFromBigInt(pq);
  final pBytes = _tlBytesFromBigInt(p);
  final qBytes = _tlBytesFromBigInt(q);

  final data = BytesBuilder();
  data.add(_intToBytesLE(0xA9F55F95, 4)); // constructor p_q_inner_data_dc
  data.add(pqBytes);
  data.add(pBytes);
  data.add(qBytes);
  data.add(clientNonce);
  data.add(serverNonce);
  data.add(newNonce);
  data.add(_intToBytesLE(2, 4)); // DC id
  final p_q_inner_data = data.toBytes();
  print('p_q_inner_data (len=${p_q_inner_data.length}): ${hex.encode(p_q_inner_data)}');

  // 4) Загрузка PEM ключей
  final keysPem = await _loadPemKeys(serverKeysPemFile);
  if (keysPem.isEmpty) {
    print('Не найден PEM файл с ключами: $serverKeysPemFile');
    return;
  }

  RSAPublicKey? chosenKey;
  String? chosenFp;
  for (final pem in keysPem) {
    try {
      final RSAPublicKey key = CryptoUtils.rsaPublicKeyFromPem(pem);
      final fpHex = _mtprotoFingerprint(key);
      print('Found key fingerprint candidate: $fpHex');
      if (serverFingerprintsHex.contains(fpHex)) {
        chosenKey = key;
        chosenFp = fpHex.toRadixString(16);
        break;
      }
    } catch (_) {}
  }

  if (chosenKey == null) {
    print('Не удалось найти подходящий RSA ключ среди PEM.');
    return;
  }
  print('Selected RSA key fingerprint: $chosenFp');

  // 5) SHA1 + p_q_inner_data + padding → RSA PKCS#1 v1.5
  final sha1 = Digest('SHA-1');
  final dataWithHash = BytesBuilder();
  final hash = sha1.process(p_q_inner_data);
  dataWithHash.add(hash);
  dataWithHash.add(p_q_inner_data);
  final encrypted = _rsaEncryptPKCS1v15(chosenKey, dataWithHash.toBytes());
  if (encrypted == null) {
    print('RSA encryption failed.');
    return;
  }
  print('encrypted_data len=${encrypted.length}');

  // 6) Формируем req_DH_params (TL)
  final req = BytesBuilder();
  req.add(clientNonce);
  req.add(serverNonce);
  req.add(pqBytes);
  req.add(_tlBytesFromBytes(encrypted));
  final body = req.toBytes();

  // 7) Отправка через Socket (Abridged)
  print('Connecting to $dcIp:$dcPort ...');
  try {
    final socket = await Socket.connect(dcIp, dcPort, timeout: Duration(seconds: 6));
    socket.add(Uint8List.fromList([0xEF])); // Abridged prefix
    socket.add(_abridgedWrap(body));
    await socket.flush();
    print('Sent req_DH_params, waiting for response...');
    socket.listen((data) {
      print('Received ${data.length} bytes: ${hex.encode(data)}');
    }, onDone: () {
      print('Socket done.');
    });
    await Future.delayed(Duration(seconds: 6));
    await socket.close();
  } catch (e) {
    print('Network error: $e');
  }
}

/// ----------------- Helpers -----------------

Uint8List _tlBytesFromBigInt(BigInt n) {
  final bytes = _bigIntToBytes(n);
  return _tlBytesFromBytes(bytes);
}

Uint8List _bigIntToBytes(BigInt n) {
  final b = <int>[];
  var v = n;
  while (v > BigInt.zero) {
    b.add((v & BigInt.from(0xFF)).toInt());
    v = v >> 8;
  }
  if (b.isEmpty) b.add(0);
  return Uint8List.fromList(b.reversed.toList());
}

Uint8List _tlBytesFromBytes(Uint8List b) {
  final builder = BytesBuilder();
  if (b.length < 254) {
    builder.add([b.length]);
    builder.add(b);
    builder.add(Uint8List((4 - (b.length % 4)) % 4));
  } else {
    builder.add([254]);
    builder.add(_intToBytesLE(b.length, 3));
    builder.add(b);
    builder.add(Uint8List((4 - (b.length % 4)) % 4));
  }
  return builder.toBytes();
}

Uint8List _randomBytes(int n) {
  final rnd = Random.secure();
  return Uint8List.fromList(List.generate(n, (_) => rnd.nextInt(256)));
}
BigInt _randomBigInt(BigInt max) {
  final rnd = Random.secure();
  BigInt result = BigInt.zero;
  final bytes = (max.bitLength + 7) ~/ 8; // сколько байт нужно
  while (result >= max || result == BigInt.zero) {
    final b = Uint8List(bytes);
    for (int i = 0; i < bytes; i++) b[i] = rnd.nextInt(256);
    result = BigInt.parse(hex.encode(b), radix: 16);
  }
  return result;
}
// Pollard Rho
List<BigInt> _factorBigInt(BigInt n) {
  if (n <= BigInt.one) return [];
  if (_isProbablePrime(n)) return [n];
  final d = _pollardRho(n);
  if (d == n) return [n];
  final a = _factorBigInt(d);
  final b = _factorBigInt(n ~/ d);
  return [...a, ...b]..sort((x, y) => x.compareTo(y));
}

bool _isProbablePrime(BigInt n, {int k = 8}) {
  if (n < BigInt.from(2)) return false;
  final small = [2,3,5,7,11,13,17,19,23];
  for (final p in small) {
    if (n == BigInt.from(p)) return true;
    if (n % BigInt.from(p) == BigInt.zero) return false;
  }
  final rng = Random.secure();
  BigInt d = n - BigInt.one;
  int s = 0;
  while (d % BigInt.two == BigInt.zero) { s++; d ~/= BigInt.two; }
  for (int i = 0; i < k; i++) {
    final a = _randomBigInt(n - BigInt.from(4)) + BigInt.from(2);
    BigInt x = a.modPow(d, n);
    if (x == BigInt.one || x == n - BigInt.one) continue;
    bool cont = false;
    for (int r = 1; r < s; r++) {
      x = x.modPow(BigInt.two, n);
      if (x == n - BigInt.one) { cont = true; break; }
    }
    if (cont) continue;
    return false;
  }
  return true;
}

BigInt _pollardRho(BigInt n) {
  if (n % BigInt.two == BigInt.zero) return BigInt.two;
  final rnd = Random.secure();
  BigInt f(BigInt x, BigInt c) => (x * x + c) % n;
  while (true) {
    BigInt x = BigInt.from(rnd.nextInt(1 << 30));
    BigInt y = x;
    final c = BigInt.from(rnd.nextInt(1 << 30));
    BigInt d = BigInt.one;
    while (d == BigInt.one) {
      x = f(x, c);
      y = f(f(y, c), c);
      d = (x - y).abs().gcd(n);
      if (d == n) break;
    }
    if (d > BigInt.one && d < n) return d;
  }
}

int _mtprotoFingerprint(RSAPublicKey key) {
  final n = _bigIntToBytes(key.modulus!);
  final e = _bigIntToBytes(key.exponent!);
  final b = BytesBuilder();
  b.add(_tlBytesFromBytes(n));
  b.add(_tlBytesFromBytes(e));
  final h = Digest('SHA-1').process(b.toBytes());
  final last8 = h.sublist(h.length - 8);
  // Little-endian uint64
  int fp = 0;
  for (int i = 0; i < 8; i++) fp |= last8[i] << (8 * i);
  return fp;
}

Uint8List _rsaEncryptPKCS1v15(RSAPublicKey key, Uint8List data) {
  final cipher = RSAEngine()
    ..init(true, PublicKeyParameter<RSAPublicKey>(key));
  return cipher.process(data);
}

Uint8List _intToBytesLE(int v, int len) =>
    Uint8List.fromList(List.generate(len, (i) => (v >> (8 * i)) & 0xFF));

Uint8List _abridgedWrap(Uint8List body) {
  final len = body.length;
  if (len < 127) return Uint8List.fromList([len] + body.toList());
  final l = Uint8List(4);
  l[0] = len & 0x7F | 0x80;
  l[1] = (len >> 8) & 0xFF;
  l[2] = (len >> 16) & 0xFF;
  l[3] = (len >> 24) & 0xFF;
  return Uint8List.fromList(l + body.toList());
}

Future<List<String>> _loadPemKeys(String file) async {
  final content = await File(file).readAsString();
  final regex = RegExp(r'-----BEGIN RSA PUBLIC KEY-----.*?-----END RSA PUBLIC KEY-----', dotAll: true);
  return regex.allMatches(content).map((m) => m.group(0)!).toList();
}
