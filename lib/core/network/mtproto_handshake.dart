import 'dart:math';
import 'dart:typed_data';
import 'dart:convert';
import 'mtproto_client.dart';
import 'mtproto_utils.dart';
import 'mtproto_crypto.dart';
import 'package:crypto/crypto.dart';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/asymmetric/rsa.dart';
import 'package:pointycastle/block/aes.dart';

class MTProtoHandshake {
  final MTProtoClient client;
  final int apiId = REMOVED;
  final String apiHash = "REMOVED";
  Uint8List? nonce;
  Uint8List? serverNonce;
  Uint8List? newNonce;
  BigInt? authKey;
  String? phoneNumber;
  String? phoneCodeHash;
  int seqNo = 0;
  Uint8List? authKeyId;
  bool handshakeComplete = false;

  MTProtoHandshake(this.client);

  BigInt _getMessageId() {
    int time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
    BigInt timeBig = BigInt.from(time) << 32;
    return timeBig | BigInt.from(seqNo * 2 + 1);
  }

  Uint8List _computeAuthKeyId(BigInt authKey) {
    Uint8List authKeyBytes = beBigIntToBytes(authKey);
    return Uint8List.fromList(sha1.convert(authKeyBytes).bytes.sublist(12, 20));
  }

  Uint8List _encryptMessage(Uint8List data, BigInt authKey, Uint8List msgKey) {
    Uint8List authKeyBytes = beBigIntToBytes(authKey);
    Uint8List aesKey = Uint8List.fromList([
      ...sha1.convert([...msgKey, ...authKeyBytes.sublist(8, 44)]).bytes,
    ]);
    Uint8List aesIv = Uint8List.fromList([
      ...sha1.convert([...authKeyBytes.sublist(48, 84), ...msgKey]).bytes.sublist(0, 12),
      ...sha1.convert([...msgKey, ...authKeyBytes.sublist(88, 120)]).bytes.sublist(0, 20),
    ]);

    int padLen = (data.length % 16 == 0) ? 0 : 16 - (data.length % 16);
    Uint8List pad = getRandomBytes(padLen);
    Uint8List dataWithPadding = Uint8List.fromList([...data, ...pad]);

    final aes = AESEngine();
    final ige = IGE(aes, aesKey, aesIv);
    return ige.process(true, dataWithPadding);
  }

  Uint8List _decryptMessage(Uint8List data, BigInt authKey, Uint8List msgKey) {
    Uint8List authKeyBytes = beBigIntToBytes(authKey);
    Uint8List aesKey = Uint8List.fromList([
      ...sha1.convert([...msgKey, ...authKeyBytes.sublist(8, 44)]).bytes,
    ]);
    Uint8List aesIv = Uint8List.fromList([
      ...sha1.convert([...authKeyBytes.sublist(48, 84), ...msgKey]).bytes.sublist(0, 12),
      ...sha1.convert([...msgKey, ...authKeyBytes.sublist(88, 120)]).bytes.sublist(0, 20),
    ]);

    final aes = AESEngine();
    final ige = IGE(aes, aesKey, aesIv);
    return ige.process(false, data);
  }

  Future<bool> start() async {
    int retries = 3;
    for (int i = 0; i < retries; i++) {
      try {
        print("🚀 Starting MTProto handshake (attempt ${i + 1})...");
        nonce = getRandomBytes(16);
        print("nonce: ${nonce!.map((e) => e.toRadixString(16)).join()}");
        final reqPQConstructor = 0x60469778; // req_pq#60469778
        final buffer = BytesBuilder();
        buffer.add(leIntToBytes(BigInt.zero, 8)); // auth_key_id = 0
        buffer.add(leIntToBytes(_getMessageId(), 8)); // message_id
        buffer.add(leIntToBytes(BigInt.from(20), 4)); // length
        buffer.add(leIntToBytes(BigInt.from(reqPQConstructor), 4));
        buffer.add(nonce!);

        final payload = buffer.toBytes();
        client.send(payload);
        return true;
      } catch (e) {
        print("Handshake attempt ${i + 1} failed: $e");
        if (i == retries - 1) return false;
        await Future.delayed(Duration(seconds: 2));
      }
    }
    return false;
  }

  void _onData(Uint8List data) {
    print("📩 Received ${data.length} bytes: ${data.map((e) => e.toRadixString(16)).join()}");
    int pos = 0;
    try {
      Uint8List receivedAuthKeyId = data.sublist(pos, pos + 8);
      pos += 8;
      BigInt msgId = leBytesToInt(data.sublist(pos, pos + 8));
      pos += 8;
      BigInt msgLen = leBytesToInt(data.sublist(pos, pos + 4));
      pos += 4;
      if (msgLen.toInt() != data.length - 20) {
        print("Error: invalid length");
        return;
      }

      if (bytesEqual(receivedAuthKeyId, Uint8List(8))) {
        BigInt constructor = leBytesToInt(data.sublist(pos, pos + 4));
        pos += 4;

        if (constructor == BigInt.from(0x05162463)) {
          // Handle resPQ
          Uint8List receivedNonce = data.sublist(pos, pos + 16);
          pos += 16;
          if (!bytesEqual(receivedNonce, nonce!)) {
            print("Error: nonce mismatch");
            return;
          }
          serverNonce = data.sublist(pos, pos + 16);
          pos += 16;
          int pqLen = data[pos];
          pos += 1;
          if (pqLen == 254) {
            pqLen = leBytesToInt(data.sublist(pos, pos + 3)).toInt();
            pos += 3;
          }
          Uint8List pqBytes = data.sublist(pos, pos + pqLen);
          pos += pqLen;
          BigInt pq = beBytesToInt(pqBytes);
          BigInt numFp = leBytesToInt(data.sublist(pos, pos + 4));
          pos += 4;
          List<BigInt> fingerprints = [];
          for (int i = 0; i < numFp.toInt(); i++) {
            fingerprints.add(leBytesToInt(data.sublist(pos, pos + 8)));
            pos += 8;
          }
          print("Parsed resPQ: pq=$pq, fingerprints=$fingerprints");
          _continueHandshake(pq, serverNonce!, fingerprints);
        } else if (constructor == BigInt.from(0xd0e8075c)) {
          _handleServerDHParams(data, pos);
        } else if (constructor == BigInt.from(0x3bcbf734)) {
          // Handle dh_gen_ok
          Uint8List receivedNonce = data.sublist(pos, pos + 16);
          pos += 16;
          if (!bytesEqual(receivedNonce, nonce!)) {
            print("Error: nonce mismatch in dh_gen_ok");
            return;
          }
          Uint8List receivedServerNonce = data.sublist(pos, pos + 16);
          pos += 16;
          if (!bytesEqual(receivedServerNonce, serverNonce!)) {
            print("Error: server_nonce mismatch in dh_gen_ok");
            return;
          }
          Uint8List newNonceHash1 = data.sublist(pos, pos + 16);
          pos += 16;
          authKeyId = _computeAuthKeyId(authKey!);
          handshakeComplete = true;
          print("🎉 DH handshake complete! Auth key: ${beBigIntToBytes(authKey!).map((e) => e.toRadixString(16)).join()}");
          _startAuthentication();
        } else {
          print("Error: unknown constructor ${constructor.toRadixString(16)}");
        }
      } else {
        if (authKey == null || authKeyId == null) {
          print("Error: auth_key or auth_key_id not set");
          return;
        }
        if (!bytesEqual(receivedAuthKeyId, authKeyId!)) {
          print("Error: auth_key_id mismatch");
          return;
        }
        Uint8List msgKey = data.sublist(pos, pos + 16);
        pos += 16;
        Uint8List encryptedData = data.sublist(pos);
        Uint8List decryptedData = _decryptMessage(encryptedData, authKey!, msgKey);

        Uint8List computedMsgKey = Uint8List.fromList(sha1.convert(decryptedData).bytes.sublist(4, 20));
        if (!bytesEqual(msgKey, computedMsgKey)) {
          print("Error: msg_key mismatch");
          return;
        }

        pos = 0;
        BigInt salt = leBytesToInt(decryptedData.sublist(pos, pos + 8));
        pos += 8;
        BigInt sessionId = leBytesToInt(decryptedData.sublist(pos, pos + 8));
        pos += 8;
        BigInt innerMsgId = leBytesToInt(decryptedData.sublist(pos, pos + 8));
        pos += 8;
        BigInt innerSeqNo = leBytesToInt(decryptedData.sublist(pos, pos + 4));
        pos += 4;
        BigInt innerMsgLen = leBytesToInt(decryptedData.sublist(pos, pos + 4));
        pos += 4;
        BigInt constructor = leBytesToInt(decryptedData.sublist(pos, pos + 4));
        pos += 4;

        if (constructor == BigInt.from(0x5e2ad36e)) {
          // Handle auth.sentCode
          print("Received auth.sentCode");
          Uint8List receivedNonce = decryptedData.sublist(pos, pos + 16);
          pos += 16;
          if (!bytesEqual(receivedNonce, nonce!)) {
            print("Error: nonce mismatch in auth.sentCode");
            return;
          }
          int phoneCodeHashLen = decryptedData[pos];
          pos += 1;
          if (phoneCodeHashLen == 254) {
            phoneCodeHashLen = leBytesToInt(decryptedData.sublist(pos, pos + 3)).toInt();
            pos += 3;
          }
          phoneCodeHash = utf8.decode(decryptedData.sublist(pos, pos + phoneCodeHashLen));
          print("Phone code hash: $phoneCodeHash");
        } else {
          print("Error: unknown constructor ${constructor.toRadixString(16)}");
        }
      }
    } catch (e) {
      print("Error parsing response: $e");
    }
  }

  void _continueHandshake(BigInt pq, Uint8List serverNonce, List<BigInt> fingerprints) async {
    BigInt fingerprint = BigInt.parse('0x216be86c022bb4c3', radix: 16);
    BigInt n = BigInt.parse(
        '0xc150023e2f70db7985ded064759cfecf0af328e69a41daf4d6f01b538135a6f91f8f8b2a0ec9ba9720ce352efcf6c5680ffc424bd634864902de0b4bd6d49f4e580230e3ae97d95c8b19442b3c0a10d8f5633fecedd6926a7f6dab0ddb7d457f9ea81b8465fcd6fffeed114011df91c059caedaf97625f6c96ecc74725556934ef781d866b34f011fce4d835a090196e9a5f0e4449af7eb697ddb9076494ca5f81104a305b6dd27665722c46b60e5df680fb16b210607ef217652e60236c255f6a28315f4083a96791d7214bf64c1df4fd0db1944fb26a2a57031b32eee64ad15a8ba68885cde74a5bfc920f6abf59ba5c75506373e7130f9042da922179251f',
        radix: 16);
    BigInt e = BigInt.from(65537);

    if (!fingerprints.contains(fingerprint)) {
      print("Error: No matching fingerprint");
      return;
    }

    List<BigInt> factors = factorPq(pq);
    BigInt p = factors[0];
    BigInt q = factors[1];
    print("Factored: p=$p, q=$q");

    newNonce = getRandomBytes(32);

    BytesBuilder innerBuffer = BytesBuilder();
    innerBuffer.add(leIntToBytes(BigInt.from(0x83c95aec), 4));
    innerBuffer.add(serializeString(beBigIntToBytes(pq)));
    innerBuffer.add(serializeString(beBigIntToBytes(p)));
    innerBuffer.add(serializeString(beBigIntToBytes(q)));
    innerBuffer.add(nonce!);
    innerBuffer.add(serverNonce);
    innerBuffer.add(newNonce!);
    Uint8List inner = innerBuffer.toBytes();

    Uint8List dataSha = Uint8List.fromList(sha1.convert(inner).bytes);
    int padLen = 255 - dataSha.length - inner.length;
    Uint8List pad = getRandomBytes(padLen);
    Uint8List dataWithSha = Uint8List.fromList([...dataSha, ...inner, ...pad]);

    RSAPublicKey rsaPublicKey = RSAPublicKey(n, e);
    RSAEngine rsaEngine = RSAEngine()..init(false, PublicKeyParameter<RSAPublicKey>(rsaPublicKey));
    Uint8List encryptedData = rsaEngine.process(dataWithSha);

    BytesBuilder buffer = BytesBuilder();
    buffer.add(leIntToBytes(BigInt.from(0xd712e4be), 4)); // req_DH_params
    buffer.add(nonce!);
    buffer.add(serverNonce);
    buffer.add(serializeString(beBigIntToBytes(p)));
    buffer.add(serializeString(beBigIntToBytes(q)));
    buffer.add(leIntToBytes(fingerprint, 8));
    buffer.add(serializeString(encryptedData));

    Uint8List msgData = buffer.toBytes();

    buffer = BytesBuilder();
    buffer.add(leIntToBytes(BigInt.zero, 8)); // auth_key_id = 0
    buffer.add(leIntToBytes(_getMessageId(), 8)); // message_id
    buffer.add(leIntToBytes(BigInt.from(msgData.length), 4)); // length
    buffer.add(msgData);

    client.send(buffer.toBytes());
    print("Sent req_DH_params");
  }

  void _handleServerDHParams(Uint8List data, int pos) {
    try {
      Uint8List receivedNonce = data.sublist(pos, pos + 16);
      pos += 16;
      if (!bytesEqual(receivedNonce, nonce!)) {
        print("Error: nonce mismatch");
        return;
      }
      Uint8List receivedServerNonce = data.sublist(pos, pos + 16);
      pos += 16;
      if (!bytesEqual(receivedServerNonce, serverNonce!)) {
        print("Error: server_nonce mismatch");
        return;
      }
      int encLen = data[pos];
      pos += 1;
      if (encLen == 254) {
        encLen = leBytesToInt(data.sublist(pos, pos + 3)).toInt();
        pos += 3;
      }
      Uint8List encryptedAnswer = data.sublist(pos, pos + encLen);
      pos += encLen;

      Uint8List tmpAesKey = Uint8List.fromList([
        ...sha1.convert([...newNonce!, ...serverNonce!]).bytes,
        ...sha1.convert([...serverNonce!, ...newNonce!]).bytes.sublist(0, 12),
      ]);
      Uint8List tmpAesIv = Uint8List.fromList([
        ...sha1.convert([...serverNonce!, ...newNonce!]).bytes.sublist(12),
        ...sha1.convert([...newNonce!, ...newNonce!]).bytes,
        ...newNonce!.sublist(0, 4),
      ]);

      final aes = AESEngine();
      final ige = IGE(aes, tmpAesKey, tmpAesIv);
      Uint8List decrypted = ige.process(false, encryptedAnswer);
      if (decrypted.length != encryptedAnswer.length) {
        print("Error: AES-IGE decryption failed");
        return;
      }

      Uint8List answerSha = decrypted.sublist(0, 20);
      Uint8List answerData = decrypted.sublist(20);
      Uint8List computedSha = Uint8List.fromList(sha1.convert(answerData).bytes);
      if (!bytesEqual(answerSha, computedSha)) {
        print("Error: SHA1 mismatch");
        return;
      }

      pos = 0;
      BigInt constructor = leBytesToInt(answerData.sublist(pos, pos + 4));
      pos += 4;
      if (constructor != BigInt.from(0xb5890c75)) {
        print("Error: not server_DH_inner_data");
        return;
      }
      Uint8List innerNonce = answerData.sublist(pos, pos + 16);
      pos += 16;
      if (!bytesEqual(innerNonce, nonce!)) {
        print("Error: nonce mismatch in inner_data");
        return;
      }
      Uint8List innerServerNonce = answerData.sublist(pos, pos + 16);
      pos += 16;
      if (!bytesEqual(innerServerNonce, serverNonce!)) {
        print("Error: server_nonce mismatch in inner_data");
        return;
      }
      BigInt g = leBytesToInt(answerData.sublist(pos, pos + 4));
      pos += 4;
      int dhPrimeLen = answerData[pos];
      pos += 1;
      if (dhPrimeLen == 254) {
        dhPrimeLen = leBytesToInt(answerData.sublist(pos, pos + 3)).toInt();
        pos += 3;
      }
      BigInt dhPrime = beBytesToInt(answerData.sublist(pos, pos + dhPrimeLen));
      pos += dhPrimeLen;
      int gALen = answerData[pos];
      pos += 1;
      if (gALen == 254) {
        gALen = leBytesToInt(answerData.sublist(pos, pos + 3)).toInt();
        pos += 3;
      }
      BigInt gA = beBytesToInt(answerData.sublist(pos, pos + gALen));
      pos += gALen;
      BigInt serverTime = leBytesToInt(answerData.sublist(pos, pos + 4));
      pos += 4;

      print("Parsed server_DH_inner_data: g=$g, dh_prime=$dhPrime, g_a=$gA, server_time=$serverTime");

      _performDHKeyExchange(g, dhPrime, gA);
    } catch (e) {
      print("Error in handleServerDHParams: $e");
    }
  }

  void _performDHKeyExchange(BigInt g, BigInt dhPrime, BigInt gA) {
    try {
      BigInt b = BigInt.from(Random.secure().nextInt(1 << 31));
      BigInt gB = g.modPow(b, dhPrime);
      authKey = gA.modPow(b, dhPrime);

      BytesBuilder innerBuffer = BytesBuilder();
      innerBuffer.add(leIntToBytes(BigInt.from(0x6643b654), 4)); // client_DH_inner_data
      innerBuffer.add(nonce!);
      innerBuffer.add(serverNonce!);
      innerBuffer.add(leIntToBytes(BigInt.zero, 8)); // retry_id
      innerBuffer.add(serializeString(beBigIntToBytes(gB)));
      Uint8List inner = innerBuffer.toBytes();

      Uint8List dataSha = Uint8List.fromList(sha1.convert(inner).bytes);
      int padLen = (dataSha.length + inner.length) % 16 == 0
          ? 0
          : 16 - (dataSha.length + inner.length) % 16;
      Uint8List pad = getRandomBytes(padLen);
      Uint8List dataWithSha = Uint8List.fromList([...dataSha, ...inner, ...pad]);

      Uint8List tmpAesKey = Uint8List.fromList([
        ...sha1.convert([...newNonce!, ...serverNonce!]).bytes,
        ...sha1.convert([...serverNonce!, ...newNonce!]).bytes.sublist(0, 12),
      ]);
      Uint8List tmpAesIv = Uint8List.fromList([
        ...sha1.convert([...serverNonce!, ...newNonce!]).bytes.sublist(12),
        ...sha1.convert([...newNonce!, ...newNonce!]).bytes,
        ...newNonce!.sublist(0, 4),
      ]);
      final aes = AESEngine();
      final ige = IGE(aes, tmpAesKey, tmpAesIv);
      Uint8List encryptedData = ige.process(true, dataWithSha);
      if (encryptedData.length != dataWithSha.length) {
        print("Error: AES-IGE encryption failed");
        return;
      }

      BytesBuilder buffer = BytesBuilder();
      buffer.add(leIntToBytes(BigInt.from(0xf5045f1f), 4)); // set_client_DH_params
      buffer.add(nonce!);
      buffer.add(serverNonce!);
      buffer.add(serializeString(encryptedData));

      Uint8List msgData = buffer.toBytes();

      buffer = BytesBuilder();
      buffer.add(leIntToBytes(BigInt.zero, 8)); // auth_key_id = 0
      buffer.add(leIntToBytes(_getMessageId(), 8)); // message_id
      buffer.add(leIntToBytes(BigInt.from(msgData.length), 4)); // length
      buffer.add(msgData);

      client.send(buffer.toBytes());
      print("Sent set_client_DH_params, auth_key: ${beBigIntToBytes(authKey!).map((e) => e.toRadixString(16)).join()}");
    } catch (e) {
      print("Error in performDHKeyExchange: $e");
    }
  }

  void _startAuthentication() {
    if (phoneNumber == null) {
      print("Error: Phone number not set");
      return;
    }
    if (!handshakeComplete || authKey == null || authKeyId == null) {
      print("Error: Handshake not complete or auth_key/auth_key_id missing");
      return;
    }
    try {
      BytesBuilder innerBuffer = BytesBuilder();
      innerBuffer.add(leIntToBytes(BigInt.from(0x86aef0ec), 4)); // auth.sendCode
      innerBuffer.add(serializeString(Uint8List.fromList(utf8.encode(phoneNumber!))));
      innerBuffer.add(leIntToBytes(BigInt.from(apiId), 4));
      innerBuffer.add(serializeString(Uint8List.fromList(utf8.encode(apiHash))));
      innerBuffer.add(leIntToBytes(BigInt.from(0x1cb5c415), 4)); // settings: empty vector
      innerBuffer.add(leIntToBytes(BigInt.zero, 4)); // vector length = 0
      Uint8List innerData = innerBuffer.toBytes();

      BytesBuilder dataBuffer = BytesBuilder();
      dataBuffer.add(leIntToBytes(BigInt.zero, 8)); // salt
      dataBuffer.add(leIntToBytes(BigInt.zero, 8)); // session_id
      dataBuffer.add(leIntToBytes(_getMessageId(), 8)); // message_id
      dataBuffer.add(leIntToBytes(BigInt.from(seqNo), 4)); // seq_no
      dataBuffer.add(leIntToBytes(BigInt.from(innerData.length), 4)); // msg_length
      dataBuffer.add(innerData);
      Uint8List data = dataBuffer.toBytes();

      Uint8List msgKey = Uint8List.fromList(sha1.convert(data).bytes.sublist(4, 20));
      Uint8List encryptedData = _encryptMessage(data, authKey!, msgKey);

      BytesBuilder buffer = BytesBuilder();
      buffer.add(authKeyId!);
      buffer.add(msgKey);
      buffer.add(encryptedData);

      client.send(buffer.toBytes());
      seqNo++;
      print("Sent auth.sendCode for $phoneNumber");
    } catch (e) {
      print("Error in startAuthentication: $e");
    }
  }

  void setPhoneNumber(String number) {
    phoneNumber = number;
    _startAuthentication();
  }

  void signIn(String code) {
    if (phoneNumber == null || phoneCodeHash == null) {
      print("Error: Phone number or code hash not set");
      return;
    }
    if (!handshakeComplete || authKey == null || authKeyId == null) {
      print("Error: Handshake not complete or auth_key/auth_key_id missing");
      return;
    }
    try {
      BytesBuilder innerBuffer = BytesBuilder();
      innerBuffer.add(leIntToBytes(BigInt.from(0x8d52a951), 4)); // auth.signIn
      innerBuffer.add(serializeString(Uint8List.fromList(utf8.encode(phoneNumber!))));
      innerBuffer.add(serializeString(Uint8List.fromList(utf8.encode(phoneCodeHash!))));
      innerBuffer.add(serializeString(Uint8List.fromList(utf8.encode(code))));
      Uint8List innerData = innerBuffer.toBytes();

      BytesBuilder dataBuffer = BytesBuilder();
      dataBuffer.add(leIntToBytes(BigInt.zero, 8)); // salt
      dataBuffer.add(leIntToBytes(BigInt.zero, 8)); // session_id
      dataBuffer.add(leIntToBytes(_getMessageId(), 8));
      dataBuffer.add(leIntToBytes(BigInt.from(seqNo), 4));
      dataBuffer.add(leIntToBytes(BigInt.from(innerData.length), 4));
      dataBuffer.add(innerData);
      Uint8List data = dataBuffer.toBytes();

      Uint8List msgKey = Uint8List.fromList(sha1.convert(data).bytes.sublist(4, 20));
      Uint8List encryptedData = _encryptMessage(data, authKey!, msgKey);

      BytesBuilder buffer = BytesBuilder();
      buffer.add(authKeyId!);
      buffer.add(msgKey);
      buffer.add(encryptedData);

      client.send(buffer.toBytes());
      seqNo++;
      print("Sent auth.signIn for $phoneNumber");
    } catch (e) {
      print("Error in signIn: $e");
    }
  }
}