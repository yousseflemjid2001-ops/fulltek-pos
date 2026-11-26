import 'dart:convert';
import 'package:flutter/material.dart';

/// Pure-Dart ISO/IEC 18004 QR Code Encoder (Byte Mode, Error Correction Level M,
/// Versions 1..10 — supports up to 213 UTF-8 bytes, ideal for Menu QR URLs).
/// Zero external dependencies; renders crisp scannable QR codes in Flutter & SVG.
class QrMatrix {
  final int size;
  final List<List<bool>> modules;

  const QrMatrix({required this.size, required this.modules});

  String toSvg({int pixelSize = 220, int quietZone = 4}) {
    final total = size + quietZone * 2;
    final buf = StringBuffer();
    buf.write(
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $total $total" '
      'width="$pixelSize" height="$pixelSize" shape-rendering="crispEdges">',
    );
    buf.write('<rect width="$total" height="$total" fill="#ffffff"/>');
    buf.write('<path fill="#000000" d="');
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (modules[y][x]) {
          buf.write('M${x + quietZone},${y + quietZone}h1v1h-1z');
        }
      }
    }
    buf.write('"/></svg>');
    return buf.toString();
  }
}

class QrCodeEncoder {
  // Error Correction Level M table for Versions 1..10:
  // [totalCodewords, ecCodewordsPerBlock, numBlocksGroup1, dataCodewordsGroup1, numBlocksGroup2, dataCodewordsGroup2]
  static const List<List<int>> _ecTableM = [
    [0, 0, 0, 0, 0, 0], // placeholder index 0
    [26, 10, 1, 16, 0, 0], // V1 (21x21)
    [44, 16, 1, 28, 0, 0], // V2 (25x25)
    [70, 26, 1, 44, 0, 0], // V3 (29x29)
    [100, 18, 2, 32, 0, 0], // V4 (33x33)
    [134, 24, 2, 43, 0, 0], // V5 (37x37)
    [172, 16, 4, 27, 0, 0], // V6 (41x41)
    [196, 18, 4, 31, 0, 0], // V7 (45x45)
    [242, 22, 2, 38, 2, 39], // V8 (49x49)
    [292, 22, 3, 36, 2, 37], // V9 (53x53)
    [346, 26, 4, 43, 1, 44], // V10 (57x57)
  ];

  static const List<List<int>> _alignmentCenters = [
    [], // 0
    [], // V1
    [6, 18], // V2
    [6, 22], // V3
    [6, 26], // V4
    [6, 30], // V5
    [6, 34], // V6
    [6, 22, 38], // V7
    [6, 24, 42], // V8
    [6, 26, 46], // V9
    [6, 28, 50], // V10
  ];

  // Format Info 15-bit strings for EC Level M (00) and Mask 0..7 (already XORed with 0x5412)
  static const List<int> _formatInfoM = [
    0x5412,
    0x5125,
    0x5E7C,
    0x5B4B,
    0x45F9,
    0x40CE,
    0x4F97,
    0x4AA0,
  ];

  // Version Info 18-bit strings for V7..V10
  static const Map<int, int> _versionInfo = {
    7: 0x07C94,
    8: 0x085BC,
    9: 0x09A99,
    10: 0x0A4D3,
  };

  static final List<int> _gfExp = _buildGfExp();
  static final List<int> _gfLog = _buildGfLog();

  static List<int> _buildGfExp() {
    final exp = List<int>.filled(512, 0);
    var x = 1;
    for (var i = 0; i < 255; i++) {
      exp[i] = x;
      x <<= 1;
      if ((x & 0x100) != 0) x ^= 0x11D;
    }
    for (var i = 255; i < 512; i++) {
      exp[i] = exp[i - 255];
    }
    return exp;
  }

  static List<int> _buildGfLog() {
    final log = List<int>.filled(256, 0);
    for (var i = 0; i < 255; i++) {
      log[_gfExp[i]] = i;
    }
    return log;
  }

  static int _gfMul(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return _gfExp[_gfLog[a] + _gfLog[b]];
  }

  static List<int> _rsGeneratorPoly(int degree) {
    var poly = <int>[1];
    for (var i = 0; i < degree; i++) {
      final next = List<int>.filled(poly.length + 1, 0);
      final factor = _gfExp[i];
      for (var j = 0; j < poly.length; j++) {
        next[j] ^= poly[j];
        next[j + 1] ^= _gfMul(poly[j], factor);
      }
      poly = next;
    }
    return poly;
  }

  static List<int> _rsRemainder(List<int> data, int ecLen) {
    final gen = _rsGeneratorPoly(ecLen);
    final res = List<int>.filled(ecLen, 0);
    for (final b in data) {
      final factor = b ^ res[0];
      for (var i = 0; i < ecLen - 1; i++) {
        res[i] = res[i + 1];
      }
      res[ecLen - 1] = 0;
      if (factor != 0) {
        for (var i = 0; i < ecLen; i++) {
          res[i] ^= _gfMul(gen[i + 1], factor);
        }
      }
    }
    return res;
  }

  static QrMatrix encode(String text) {
    final bytes = utf8.encode(text);
    // Pick smallest version 1..10 that fits bytes in Byte Mode (4-bit mode + 8/16-bit len)
    int version = 10;
    for (var v = 1; v <= 10; v++) {
      final t = _ecTableM[v];
      final dataCapacity = t[2] * t[3] + t[4] * t[5];
      final headerBits = 4 + (v <= 9 ? 8 : 16);
      final neededBytes = ((headerBits + bytes.length * 8 + 7) ~/ 8);
      if (neededBytes <= dataCapacity) {
        version = v;
        break;
      }
    }

    final t = _ecTableM[version];
    final ecLen = t[1];
    final b1Count = t[2];
    final b1Data = t[3];
    final b2Count = t[4];
    final b2Data = t[5];
    final totalDataCodewords = b1Count * b1Data + b2Count * b2Data;

    // Build bit stream
    final bits = <int>[];
    void pushBits(int val, int len) {
      for (var i = len - 1; i >= 0; i--) {
        bits.add((val >> i) & 1);
      }
    }

    pushBits(0x4, 4); // Byte mode
    final lenBits = version <= 9 ? 8 : 16;
    final maxBytes =
        totalDataCodewords - ((4 + lenBits + 7) ~/ 8);
    final payload =
        bytes.length > maxBytes ? bytes.sublist(0, maxBytes) : bytes;
    pushBits(payload.length, lenBits);
    for (final b in payload) {
      pushBits(b, 8);
    }

    final totalDataBits = totalDataCodewords * 8;
    // Terminator (up to 4 zeros)
    for (var i = 0; i < 4 && bits.length < totalDataBits; i++) {
      bits.add(0);
    }
    while (bits.length % 8 != 0) {
      bits.add(0);
    }

    final dataCodewords = <int>[];
    for (var i = 0; i < bits.length; i += 8) {
      var b = 0;
      for (var j = 0; j < 8; j++) {
        b = (b << 1) | bits[i + j];
      }
      dataCodewords.add(b);
    }
    const padBytes = [0xEC, 0x11];
    var padIdx = 0;
    while (dataCodewords.length < totalDataCodewords) {
      dataCodewords.add(padBytes[padIdx % 2]);
      padIdx++;
    }

    // Split into RS blocks and interleave
    final dataBlocks = <List<int>>[];
    final ecBlocks = <List<int>>[];
    var offset = 0;
    for (var i = 0; i < b1Count; i++) {
      final blk = dataCodewords.sublist(offset, offset + b1Data);
      offset += b1Data;
      dataBlocks.add(blk);
      ecBlocks.add(_rsRemainder(blk, ecLen));
    }
    for (var i = 0; i < b2Count; i++) {
      final blk = dataCodewords.sublist(offset, offset + b2Data);
      offset += b2Data;
      dataBlocks.add(blk);
      ecBlocks.add(_rsRemainder(blk, ecLen));
    }

    final finalCodewords = <int>[];
    final maxDataLen = b2Data > b1Data ? b2Data : b1Data;
    for (var i = 0; i < maxDataLen; i++) {
      for (final blk in dataBlocks) {
        if (i < blk.length) finalCodewords.add(blk[i]);
      }
    }
    for (var i = 0; i < ecLen; i++) {
      for (final ec in ecBlocks) {
        finalCodewords.add(ec[i]);
      }
    }

    final size = 17 + version * 4;
    final modules = List.generate(size, (_) => List<bool>.filled(size, false));
    final isFunction =
        List.generate(size, (_) => List<bool>.filled(size, false));

    void setFunc(int x, int y, bool dark) {
      if (x < 0 || y < 0 || x >= size || y >= size) return;
      modules[y][x] = dark;
      isFunction[y][x] = true;
    }

    // Finder patterns + separators
    void drawFinder(int cx, int cy) {
      for (var dy = -4; dy <= 4; dy++) {
        for (var dx = -4; dx <= 4; dx++) {
          final xx = cx + dx;
          final yy = cy + dy;
          if (xx < 0 || yy < 0 || xx >= size || yy >= size) continue;
          final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
          final dark = dist != 2 && dist != 4;
          setFunc(xx, yy, dark);
        }
      }
    }

    drawFinder(3, 3);
    drawFinder(size - 4, 3);
    drawFinder(3, size - 4);

    // Alignment patterns
    final centers = _alignmentCenters[version];
    for (final cy in centers) {
      for (final cx in centers) {
        final onTopLeft = cx == 6 && cy == 6;
        final onTopRight = cx == centers.last && cy == 6;
        final onBottomLeft = cx == 6 && cy == centers.last;
        if (onTopLeft || onTopRight || onBottomLeft) continue;
        for (var dy = -2; dy <= 2; dy++) {
          for (var dx = -2; dx <= 2; dx++) {
            final dist = dx.abs() > dy.abs() ? dx.abs() : dy.abs();
            setFunc(cx + dx, cy + dy, dist != 1);
          }
        }
      }
    }

    // Timing patterns
    for (var i = 8; i < size - 8; i++) {
      setFunc(i, 6, i % 2 == 0);
      setFunc(6, i, i % 2 == 0);
    }

    // Reserve Format Info areas + Dark Module
    for (var i = 0; i <= 8; i++) {
      if (i != 6) {
        setFunc(8, i, false);
        setFunc(i, 8, false);
      }
    }
    for (var i = size - 8; i < size; i++) {
      setFunc(8, i, false);
      setFunc(i, 8, false);
    }
    setFunc(8, size - 8, true); // Dark module

    // Version Info for V7..V10
    if (version >= 7) {
      final vBits = _versionInfo[version]!;
      for (var i = 0; i < 18; i++) {
        final bit = ((vBits >> i) & 1) != 0;
        final a = size - 11 + (i % 3);
        final b = i ~/ 3;
        setFunc(a, b, bit);
        setFunc(b, a, bit);
      }
    }

    // Place data bits in zig-zag columns
    var bitIdx = 0;
    final totalCodewordBits = finalCodewords.length * 8;
    var upward = true;
    for (var right = size - 1; right >= 1; right -= 2) {
      if (right == 6) right = 5;
      for (var vert = 0; vert < size; vert++) {
        final y = upward ? size - 1 - vert : vert;
        for (var j = 0; j < 2; j++) {
          final x = right - j;
          if (!isFunction[y][x]) {
            var dark = false;
            if (bitIdx < totalCodewordBits) {
              dark = ((finalCodewords[bitIdx >> 3] >> (7 - (bitIdx & 7))) & 1) !=
                  0;
            }
            bitIdx++;
            modules[y][x] = dark;
          }
        }
      }
      upward = !upward;
    }

    // Apply Mask 0 ((x + y) % 2 == 0) — simple, fast, standard ISO/IEC 18004
    const maskId = 0;
    for (var y = 0; y < size; y++) {
      for (var x = 0; x < size; x++) {
        if (!isFunction[y][x] && ((x + y) % 2 == 0)) {
          modules[y][x] = !modules[y][x];
        }
      }
    }

    // Write Format Info for EC Level M + Mask 0
    final fmt = _formatInfoM[maskId];
    for (var i = 0; i <= 5; i++) {
      modules[i][8] = ((fmt >> i) & 1) != 0;
    }
    modules[7][8] = ((fmt >> 6) & 1) != 0;
    modules[8][8] = ((fmt >> 7) & 1) != 0;
    modules[8][7] = ((fmt >> 8) & 1) != 0;
    for (var i = 9; i < 15; i++) {
      modules[8][14 - i] = ((fmt >> i) & 1) != 0;
    }
    for (var i = 0; i < 8; i++) {
      modules[8][size - 1 - i] = ((fmt >> i) & 1) != 0;
    }
    for (var i = 8; i < 15; i++) {
      modules[size - 15 + i][8] = ((fmt >> i) & 1) != 0;
    }
    modules[size - 8][8] = true;

    return QrMatrix(size: size, modules: modules);
  }
}

class QrCodeWidget extends StatelessWidget {
  final String data;
  final double size;
  final Color foregroundColor;
  final Color backgroundColor;

  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 180,
    this.foregroundColor = Colors.black,
    this.backgroundColor = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    final matrix = QrCodeEncoder.encode(data);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: CustomPaint(
        painter: _QrPainter(
          matrix: matrix,
          color: foregroundColor,
        ),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  final QrMatrix matrix;
  final Color color;

  const _QrPainter({required this.matrix, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final cell = size.width / matrix.size;
    for (var y = 0; y < matrix.size; y++) {
      for (var x = 0; x < matrix.size; x++) {
        if (matrix.modules[y][x]) {
          canvas.drawRect(
            Rect.fromLTWH(x * cell, y * cell, cell + 0.35, cell + 0.35),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.matrix != matrix || oldDelegate.color != color;
}
