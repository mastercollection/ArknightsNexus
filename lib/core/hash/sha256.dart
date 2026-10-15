import 'dart:typed_data';

/// SHA-256 (FIPS 180-4) of [data] as lowercase hex.
///
/// Used to verify published snapshot files against their manifest, so the
/// app needs no extra package for one digest. Runs on the 64-bit VM only
/// (masks every word to 32 bits); the app does not target the web.
String sha256Hex(List<int> data) {
  final length = data.length;
  final paddedLength = ((length + 9 + 63) ~/ 64) * 64;
  final message = Uint8List(paddedLength)
    ..setRange(0, length, data)
    ..[length] = 0x80;
  ByteData.sublistView(message)
    ..setUint32(paddedLength - 8, (length >> 29) & _mask)
    ..setUint32(paddedLength - 4, (length << 3) & _mask);

  final hash = Uint32List.fromList(_initialHash);
  final words = Uint32List(64);
  final view = ByteData.sublistView(message);

  for (var offset = 0; offset < paddedLength; offset += 64) {
    for (var i = 0; i < 16; i++) {
      words[i] = view.getUint32(offset + i * 4);
    }
    for (var i = 16; i < 64; i++) {
      final w15 = words[i - 15];
      final w2 = words[i - 2];
      final s0 = _rotr(w15, 7) ^ _rotr(w15, 18) ^ (w15 >> 3);
      final s1 = _rotr(w2, 17) ^ _rotr(w2, 19) ^ (w2 >> 10);
      words[i] = (words[i - 16] + s0 + words[i - 7] + s1) & _mask;
    }

    var a = hash[0];
    var b = hash[1];
    var c = hash[2];
    var d = hash[3];
    var e = hash[4];
    var f = hash[5];
    var g = hash[6];
    var h = hash[7];

    for (var i = 0; i < 64; i++) {
      final s1 = _rotr(e, 6) ^ _rotr(e, 11) ^ _rotr(e, 25);
      final ch = (e & f) ^ (~e & _mask & g);
      final t1 = (h + s1 + ch + _k[i] + words[i]) & _mask;
      final s0 = _rotr(a, 2) ^ _rotr(a, 13) ^ _rotr(a, 22);
      final maj = (a & b) ^ (a & c) ^ (b & c);
      final t2 = (s0 + maj) & _mask;
      h = g;
      g = f;
      f = e;
      e = (d + t1) & _mask;
      d = c;
      c = b;
      b = a;
      a = (t1 + t2) & _mask;
    }

    hash[0] = (hash[0] + a) & _mask;
    hash[1] = (hash[1] + b) & _mask;
    hash[2] = (hash[2] + c) & _mask;
    hash[3] = (hash[3] + d) & _mask;
    hash[4] = (hash[4] + e) & _mask;
    hash[5] = (hash[5] + f) & _mask;
    hash[6] = (hash[6] + g) & _mask;
    hash[7] = (hash[7] + h) & _mask;
  }

  final out = StringBuffer();
  for (final word in hash) {
    out.write(word.toRadixString(16).padLeft(8, '0'));
  }
  return out.toString();
}

const _mask = 0xffffffff;

int _rotr(int x, int n) => ((x >> n) | (x << (32 - n))) & _mask;

const _initialHash = [
  0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, //
  0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
];

const _k = [
  0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, //
  0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
  0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
  0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
  0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc,
  0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
  0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7,
  0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
  0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
  0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
  0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3,
  0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
  0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5,
  0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
  0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
  0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];
