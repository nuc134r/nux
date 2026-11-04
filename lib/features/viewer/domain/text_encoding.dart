import 'dart:convert';
import 'dart:typed_data';

/// Encodings a text file can be read and written in.
enum TextEncoding {
  utf8('UTF-8'),
  utf8Bom('UTF-8 BOM'),
  utf16le('UTF-16 LE'),
  utf16be('UTF-16 BE'),
  latin1('ISO 8859-1'),
  windows1251('Windows-1251');

  const TextEncoding(this.label);

  final String label;
}

enum LineEnding {
  lf('LF', '\n'),
  crlf('CRLF', '\r\n'),
  cr('CR', '\r');

  const LineEnding(this.label, this.chars);

  final String label;
  final String chars;
}

/// A file's text with `\n` line breaks, and how it was stored.
class DecodedText {
  const DecodedText(this.text, this.encoding, this.lineEnding);

  final String text;
  final TextEncoding encoding;
  final LineEnding lineEnding;
}

/// Decodes [bytes] in [encoding], or detects it: a byte order mark, else UTF-8 when the bytes are valid
/// UTF-8, else ISO 8859-1 (which keeps every byte, so saving does not damage the file).
DecodedText decodeText(Uint8List bytes, {TextEncoding? encoding}) {
  final enc = encoding ?? detectEncoding(bytes);
  final raw = switch (enc) {
    TextEncoding.utf8 => utf8.decode(bytes, allowMalformed: true),
    TextEncoding.utf8Bom => utf8.decode(_skip(bytes, 3, const [0xEF, 0xBB, 0xBF]), allowMalformed: true),
    TextEncoding.utf16le => _decodeUtf16(_skip(bytes, 2, const [0xFF, 0xFE]), little: true),
    TextEncoding.utf16be => _decodeUtf16(_skip(bytes, 2, const [0xFE, 0xFF]), little: false),
    TextEncoding.latin1 => latin1.decode(bytes),
    TextEncoding.windows1251 => String.fromCharCodes([for (final b in bytes) b < 0x80 ? b : _cp1251[b - 0x80]]),
  };
  final ending = detectLineEnding(raw);
  final text = raw.contains('\r') ? raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n') : raw;
  return DecodedText(text, enc, ending);
}

/// [text] (with `\n` line breaks) as bytes with [ending] in [encoding]. Characters the encoding cannot
/// hold become `?`.
Uint8List encodeText(String text, TextEncoding encoding, LineEnding ending) {
  final s = ending == LineEnding.lf ? text : text.replaceAll('\n', ending.chars);
  return switch (encoding) {
    TextEncoding.utf8 => Uint8List.fromList(utf8.encode(s)),
    TextEncoding.utf8Bom => Uint8List.fromList([0xEF, 0xBB, 0xBF, ...utf8.encode(s)]),
    TextEncoding.utf16le => _encodeUtf16(s, little: true),
    TextEncoding.utf16be => _encodeUtf16(s, little: false),
    TextEncoding.latin1 => Uint8List.fromList([for (final c in s.codeUnits) c < 0x100 ? c : 0x3F]),
    TextEncoding.windows1251 => Uint8List.fromList([
      for (final c in s.codeUnits) c < 0x80 ? c : (_cp1251Reverse[c] ?? 0x3F),
    ]),
  };
}

TextEncoding detectEncoding(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xEF && b[1] == 0xBB && b[2] == 0xBF) return TextEncoding.utf8Bom;
  if (b.length >= 2 && b[0] == 0xFF && b[1] == 0xFE) return TextEncoding.utf16le;
  if (b.length >= 2 && b[0] == 0xFE && b[1] == 0xFF) return TextEncoding.utf16be;
  try {
    utf8.decode(b);
    return TextEncoding.utf8;
  } on FormatException {
    // A partly loaded file can end in the middle of a character: judge it without the last 3 bytes.
    if (b.length > 3) {
      try {
        utf8.decode(Uint8List.sublistView(b, 0, b.length - 3), allowMalformed: false);
      } on FormatException {
        return TextEncoding.latin1;
      }
      return TextEncoding.utf8;
    }
    return TextEncoding.latin1;
  }
}

/// The most common line break in [text]; LF when there is none.
LineEnding detectLineEnding(String text) {
  var crlf = 0, lf = 0, cr = 0;
  for (var i = 0; i < text.length; i++) {
    final c = text.codeUnitAt(i);
    if (c == 0x0D) {
      if (i + 1 < text.length && text.codeUnitAt(i + 1) == 0x0A) {
        crlf++;
        i++;
      } else {
        cr++;
      }
    } else if (c == 0x0A) {
      lf++;
    }
  }
  if (crlf > lf && crlf >= cr) return LineEnding.crlf;
  if (cr > lf && cr > crlf) return LineEnding.cr;
  return LineEnding.lf;
}

Uint8List _skip(Uint8List b, int n, List<int> bom) {
  for (var i = 0; i < n; i++) {
    if (i >= b.length || b[i] != bom[i]) return b;
  }
  return Uint8List.sublistView(b, n);
}

String _decodeUtf16(Uint8List b, {required bool little}) {
  final units = <int>[];
  for (var i = 0; i + 1 < b.length; i += 2) {
    units.add(little ? b[i] | b[i + 1] << 8 : b[i] << 8 | b[i + 1]);
  }
  return String.fromCharCodes(units);
}

Uint8List _encodeUtf16(String s, {required bool little}) {
  final out = Uint8List(2 + s.length * 2);
  out[0] = little ? 0xFF : 0xFE;
  out[1] = little ? 0xFE : 0xFF;
  for (var i = 0; i < s.length; i++) {
    final c = s.codeUnitAt(i);
    out[2 + i * 2] = little ? c & 0xFF : c >> 8;
    out[3 + i * 2] = little ? c >> 8 : c & 0xFF;
  }
  return out;
}

/// Windows-1251 bytes 0x80–0xFF (0x98 is unassigned).
final _cp1251 = [
  0x0402,
  0x0403,
  0x201A,
  0x0453,
  0x201E,
  0x2026,
  0x2020,
  0x2021,
  0x20AC,
  0x2030,
  0x0409,
  0x2039,
  0x040A,
  0x040C,
  0x040B,
  0x040F, //
  0x0452,
  0x2018,
  0x2019,
  0x201C,
  0x201D,
  0x2022,
  0x2013,
  0x2014,
  0xFFFD,
  0x2122,
  0x0459,
  0x203A,
  0x045A,
  0x045C,
  0x045B,
  0x045F, //
  0x00A0,
  0x040E,
  0x045E,
  0x0408,
  0x00A4,
  0x0490,
  0x00A6,
  0x00A7,
  0x0401,
  0x00A9,
  0x0404,
  0x00AB,
  0x00AC,
  0x00AD,
  0x00AE,
  0x0407, //
  0x00B0,
  0x00B1,
  0x0406,
  0x0456,
  0x0491,
  0x00B5,
  0x00B6,
  0x00B7,
  0x0451,
  0x2116,
  0x0454,
  0x00BB,
  0x0458,
  0x0405,
  0x0455,
  0x0457, //
  for (var c = 0x0410; c <= 0x044F; c++) c,
];

final _cp1251Reverse = {
  for (var i = 0; i < _cp1251.length; i++)
    if (_cp1251[i] != 0xFFFD) _cp1251[i]: 0x80 + i,
};
