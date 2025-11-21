import 'dart:math';
import 'dart:typed_data';
import 'package:crypto/crypto.dart';

/// PBKDF2 (HMAC-SHA256) key derivation.
/// Returns [length] bytes.
Uint8List deriveKey({
  required String password,
  required Uint8List salt,
  required int iterations,
  required int length,
}) {
  final passBytes = Uint8List.fromList(password.codeUnits);
  final blocks = (length / 32).ceil(); // SHA256 output = 32 bytes
  final output = BytesBuilder();
  for (int blockIndex = 1; blockIndex <= blocks; blockIndex++) {
    // Initial U = HMAC(password, salt || INT(blockIndex))
    final hmac = Hmac(sha256, passBytes);
    final blockData = Uint8List(salt.length + 4);
    blockData.setAll(0, salt);
    // INT(blockIndex) big-endian
    blockData[salt.length] = (blockIndex >> 24) & 0xff;
    blockData[salt.length + 1] = (blockIndex >> 16) & 0xff;
    blockData[salt.length + 2] = (blockIndex >> 8) & 0xff;
    blockData[salt.length + 3] = blockIndex & 0xff;
    Uint8List u = Uint8List.fromList(hmac.convert(blockData).bytes);
    Uint8List t = Uint8List.fromList(u); // accumulator
    for (int i = 1; i < iterations; i++) {
      u = Uint8List.fromList(hmac.convert(u).bytes);
      for (int j = 0; j < t.length; j++) {
        t[j] ^= u[j];
      }
    }
    output.add(t);
  }
  final derived = output.toBytes();
  return Uint8List.sublistView(derived, 0, length);
}

Uint8List randomBytes(int length) {
  final rnd = Random.secure();
  final data = Uint8List(length);
  for (int i = 0; i < length; i++) {
    data[i] = rnd.nextInt(256);
  }
  return data;
}