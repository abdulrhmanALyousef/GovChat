import 'dart:math';
import 'dart:typed_data';

import 'package:pointycastle/export.dart';

/// Low-level cryptographic utilities: secure random, BigInt ↔ bytes, etc.
class CryptoUtils {
  CryptoUtils._();

  static SecureRandom? _random;

  /// A seeded [FortunaRandom] instance.
  /// Re-seeds from [Random.secure] on first access.
  static SecureRandom get secureRandom {
    if (_random != null) return _random!;
    final rng = FortunaRandom();
    final seeds = Uint8List(32);
    final dartRandom = Random.secure();
    for (var i = 0; i < seeds.length; i++) {
      seeds[i] = dartRandom.nextInt(256);
    }
    rng.seed(KeyParameter(seeds));
    _random = rng;
    return rng;
  }

  /// Generate [count] cryptographically secure random bytes.
  static Uint8List randomBytes(int count) => secureRandom.nextBytes(count);

  /// Encode an unsigned [BigInt] as a big-endian [Uint8List].
  static Uint8List bigIntToBytes(BigInt n) {
    assert(n >= BigInt.zero, 'BigInt must be non-negative');
    if (n == BigInt.zero) return Uint8List(1);
    final hex = n.toRadixString(16);
    final padded = hex.length.isOdd ? '0$hex' : hex;
    final out = Uint8List(padded.length ~/ 2);
    for (var i = 0; i < out.length; i++) {
      out[i] = int.parse(padded.substring(i * 2, i * 2 + 2), radix: 16);
    }
    return out;
  }

  /// Decode a big-endian [Uint8List] to an unsigned [BigInt].
  static BigInt bytesToBigInt(Uint8List bytes) {
    var result = BigInt.zero;
    for (final byte in bytes) {
      result = (result << 8) | BigInt.from(byte);
    }
    return result;
  }
}
