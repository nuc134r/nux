import 'dart:convert';
import 'dart:typed_data';

/// Reads the SSH binary encoding (RFC 4251 §5): uint32, string, mpint.
class SshWireReader {
  SshWireReader(this._bytes);

  final Uint8List _bytes;
  int _offset = 0;

  bool get isDone => _offset >= _bytes.length;

  int readUint32() {
    _need(4);
    final v = ByteData.sublistView(_bytes, _offset, _offset + 4).getUint32(0);
    _offset += 4;
    return v;
  }

  Uint8List readString() {
    final length = readUint32();
    _need(length);
    final v = Uint8List.sublistView(_bytes, _offset, _offset + length);
    _offset += length;
    return Uint8List.fromList(v);
  }

  String readUtf8() => utf8.decode(readString(), allowMalformed: true);

  BigInt readMpint() => decodeBigIntUnsigned(readString());

  void _need(int n) {
    if (_offset + n > _bytes.length) throw const FormatException('Truncated SSH data');
  }
}

/// Writes the SSH binary encoding.
class SshWireWriter {
  final BytesBuilder _out = BytesBuilder();

  void writeUint32(int v) => _out.add((ByteData(4)..setUint32(0, v)).buffer.asUint8List());

  void writeString(List<int> bytes) {
    writeUint32(bytes.length);
    _out.add(bytes);
  }

  void writeUtf8(String s) => writeString(utf8.encode(s));

  /// Two's-complement big-endian with a leading zero when the top bit is set (positive numbers only).
  void writeMpint(BigInt v) => writeString(encodeMpint(v));

  Uint8List takeBytes() => _out.takeBytes();
}

BigInt decodeBigIntUnsigned(List<int> bytes) {
  var result = BigInt.zero;
  for (final b in bytes) {
    result = (result << 8) | BigInt.from(b);
  }
  return result;
}

/// Big-endian bytes of [v], exactly [length] long when given (left-padded with zeros).
Uint8List encodeBigIntUnsigned(BigInt v, [int? length]) {
  final bytes = <int>[];
  var x = v;
  while (x > BigInt.zero) {
    bytes.insert(0, (x & BigInt.from(0xff)).toInt());
    x >>= 8;
  }
  if (length != null) {
    while (bytes.length < length) {
      bytes.insert(0, 0);
    }
  }
  return Uint8List.fromList(bytes);
}

Uint8List encodeMpint(BigInt v) {
  if (v == BigInt.zero) return Uint8List(0);
  final b = encodeBigIntUnsigned(v);
  return b[0] & 0x80 != 0 ? Uint8List.fromList([0, ...b]) : b;
}
