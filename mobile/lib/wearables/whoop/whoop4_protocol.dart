import 'dart:typed_data';

const _startOfFrame = 0xaa;
const _realtimeHeartRate = 40;

final class Whoop4Commands {
  int _sequence = 0;

  Uint8List requestBattery() => _command(26, 0);

  Uint8List setLiveHeartRate({required bool enabled}) =>
      _command(3, enabled ? 1 : 0);

  Uint8List _command(int number, int argument) {
    _sequence = (_sequence + 1) & 0xff;
    final body = <int>[0x23, _sequence, number, argument];
    final crcOffset = 4 + body.length;
    final frame = ByteData(crcOffset + 4)
      ..setUint8(0, _startOfFrame)
      ..setUint16(1, crcOffset, Endian.little)
      ..setUint8(3, _lengthCrc(crcOffset & 0xff, crcOffset >> 8))
      ..setUint32(crcOffset, _bodyCrc(body), Endian.little);
    return frame.buffer.asUint8List()..setRange(4, crcOffset, body);
  }
}

final class Whoop4HeartRateDecoder {
  // The vendor data characteristic can fragment frames or carry other records.
  final _pending = <int>[];
  static const _maxFrameLength = 4096;

  List<int> add(List<int> notification) {
    _pending.addAll(notification);
    final readings = <int>[];
    while (_pending.isNotEmpty) {
      final start = _pending.indexOf(_startOfFrame);
      if (start == -1) {
        _pending.clear();
        break;
      }
      _pending.removeRange(0, start);
      if (_pending.length < 4) break;

      final crcOffset = _pending[1] | (_pending[2] << 8);
      final frameLength = crcOffset + 4;
      if (crcOffset < 7 ||
          frameLength > _maxFrameLength ||
          _pending[3] != _lengthCrc(_pending[1], _pending[2])) {
        _pending.removeAt(0);
        continue;
      }
      if (_pending.length < frameLength) break;

      final checksum =
          _pending[crcOffset] |
          (_pending[crcOffset + 1] << 8) |
          (_pending[crcOffset + 2] << 16) |
          (_pending[crcOffset + 3] << 24);
      if (checksum != _bodyCrc(_pending.getRange(4, crcOffset))) {
        _pending.removeAt(0);
        continue;
      }

      if (_pending[4] == _realtimeHeartRate && crcOffset >= 14) {
        final bpm = _pending[12];
        if (bpm > 0) readings.add(bpm);
      }
      _pending.removeRange(0, frameLength);
    }
    return readings;
  }
}

int _lengthCrc(int low, int high) {
  var crc = 0;
  for (final byte in [low, high]) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final polynomial = crc & 0x80 == 0 ? 0 : 0x07;
      crc = ((crc << 1) ^ polynomial) & 0xff;
    }
  }
  return crc;
}

int _bodyCrc(Iterable<int> bytes) {
  var crc = 0xffffffff;
  for (final byte in bytes) {
    crc ^= byte;
    for (var bit = 0; bit < 8; bit++) {
      final polynomial = crc & 1 == 0 ? 0 : 0xedb88320;
      crc = (crc >>> 1) ^ polynomial;
    }
  }
  return crc ^ 0xffffffff;
}
