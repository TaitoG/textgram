// lib/core/network/mtproto_utils.dart
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

Uint8List getRandomBytes(int length) {
  final random = Random.secure();
  final bytes = List<int>.generate(length, (_) => random.nextInt(256));
  return Uint8List.fromList(bytes);
}

Uint8List leIntToBytes(BigInt number, int length) {
  final bytes = Uint8List(length);
  var temp = number;
  for (int i = 0; i < length; i++) {
    bytes[i] = (temp & BigInt.from(0xFF)).toInt();
    temp = temp >> 8;
  }
  return bytes;
}

BigInt leBytesToInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (int i = bytes.length - 1; i >= 0; i--) {
    result = (result << 8) | BigInt.from(bytes[i]);
  }
  return result;
}

BigInt beBytesToInt(Uint8List bytes) {
  BigInt result = BigInt.zero;
  for (var b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

Uint8List beBigIntToBytes(BigInt number) {
  if (number == BigInt.zero) {
    return Uint8List.fromList([0]);
  }
  int length = (number.bitLength + 7) ~/ 8;
  final bytes = Uint8List(length);
  var temp = number;
  for (int i = length - 1; i >= 0; i--) {
    bytes[i] = (temp & BigInt.from(0xFF)).toInt();
    temp = temp >> 8;
  }
  return bytes;
}

Uint8List serializeString(Uint8List data) {
  int len = data.length;
  BytesBuilder builder = BytesBuilder();
  if (len < 254) {
    builder.add(leIntToBytes(BigInt.from(len), 1));
    builder.add(data);
    int pad = (len + 1) % 4;
    if (pad > 0) {
      pad = 4 - pad;
      builder.add(Uint8List(pad));
    }
  } else {
    builder.add(leIntToBytes(BigInt.from(254), 1));
    builder.add(leIntToBytes(BigInt.from(len), 3));
    builder.add(data);
    int pad = (len + 4) % 4;
    if (pad > 0) {
      pad = 4 - pad;
      builder.add(Uint8List(pad));
    }
  }
  return builder.toBytes();
}

List<BigInt> factorPq(BigInt pq) {
  BigInt two = BigInt.from(2);
  if (pq % two == BigInt.zero) {
    BigInt p = two;
    BigInt q = pq ~/ p;
    return p < q ? [p, q] : [q, p];
  }
  BigInt i = BigInt.from(3);
  BigInt limit = bigIntSqrt(pq) + BigInt.one;
  while (i <= limit) {
    if (pq % i == BigInt.zero) {
      BigInt p = i;
      BigInt q = pq ~/ p;
      return p < q ? [p, q] : [q, p];
    }
    i += two;
  }
  throw Exception("Failed to factor pq");
}

BigInt bigIntSqrt(BigInt n) {
  if (n < BigInt.zero) {
    throw ArgumentError('Square root of negative number');
  }
  if (n == BigInt.zero || n == BigInt.one) return n;
  BigInt start = BigInt.one;
  BigInt end = n;
  while (start <= end) {
    BigInt mid = (start + end) ~/ BigInt.two;
    BigInt sq = mid * mid;
    if (sq == n) return mid;
    if (sq < n) {
      start = mid + BigInt.one;
    } else {
      end = mid - BigInt.one;
    }
  }
  return end;
}

bool bytesEqual(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}