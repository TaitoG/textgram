import 'dart:typed_data';
import 'package:pointycastle/api.dart';
import 'package:pointycastle/block/aes.dart';

class IGE {
  final AESEngine aes;
  final Uint8List key;
  final Uint8List iv;

  IGE(this.aes, this.key, this.iv) {
    aes.init(true, KeyParameter(key)); // Initialize AES for encryption
  }

  Uint8List process(bool encrypt, Uint8List input) {
    if (input.length % 16 != 0) {
      throw ArgumentError('Input length must be a multiple of 16 bytes');
    }

    Uint8List output = Uint8List(input.length);
    Uint8List xPrev = Uint8List.fromList(iv.sublist(0, 16)); // IV part for x
    Uint8List yPrev = Uint8List.fromList(iv.sublist(16, 32)); // IV part for y

    for (int i = 0; i < input.length; i += 16) {
      Uint8List block = input.sublist(i, i + 16);
      Uint8List outBlock = Uint8List(16);

      if (encrypt) {
        // IGE encryption: block XOR x_prev, AES encrypt, XOR y_prev
        for (int j = 0; j < 16; j++) {
          block[j] ^= xPrev[j];
        }
        aes.processBlock(block, 0, outBlock, 0);
        for (int j = 0; j < 16; j++) {
          outBlock[j] ^= yPrev[j];
        }
        output.setRange(i, i + 16, outBlock);
        xPrev = Uint8List.fromList(outBlock);
        yPrev = Uint8List.fromList(block);
      } else {
        // IGE decryption: block XOR y_prev, AES decrypt, XOR x_prev
        for (int j = 0; j < 16; j++) {
          block[j] ^= yPrev[j];
        }
        aes.processBlock(block, 0, outBlock, 0);
        for (int j = 0; j < 16; j++) {
          outBlock[j] ^= xPrev[j];
        }
        output.setRange(i, i + 16, outBlock);
        xPrev = Uint8List.fromList(block);
        yPrev = Uint8List.fromList(outBlock);
      }
    }

    return output;
  }
}