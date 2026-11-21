import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/wearables/whoop/whoop4_protocol.dart';

List<int> _bytes(String hex) => [
  for (var index = 0; index < hex.length; index += 2)
    int.parse(hex.substring(index, index + 2), radix: 16),
];

const _heartRateFrame = 'aa10005728110000000000004e0120034340147c';
const _otherFrame = 'aa1000572b110000000000004e012003b3928a0b';

void main() {
  test('frames the confirmed battery request and live heart-rate commands', () {
    final commands = Whoop4Commands();
    expect(commands.requestBattery(), _bytes('aa0800a823011a00204f2c22'));
    expect(
      commands.setLiveHeartRate(enabled: true),
      _bytes('aa0800a823020301f7686dcc'),
    );
    expect(
      commands.setLiveHeartRate(enabled: false),
      _bytes('aa0800a8230303005632a8ba'),
    );
  });

  test('decodes fragmented live heart rate and skips other frame types', () {
    final decoder = Whoop4HeartRateDecoder();
    final packet = _bytes(_heartRateFrame);
    expect(decoder.add(packet.sublist(0, 3)), isEmpty);
    expect(decoder.add(packet.sublist(3, 15)), isEmpty);
    expect(
      decoder.add([...packet.sublist(15), ..._bytes(_otherFrame), ...packet]),
      [78, 78],
    );
  });

  test('rejects bad checksums and resynchronizes at the next good frame', () {
    final decoder = Whoop4HeartRateDecoder();
    final badHeader = _bytes(_heartRateFrame)..[3] ^= 1;
    final badData = _bytes(_heartRateFrame)..[12] ^= 1;
    expect(decoder.add([...badHeader, ...badData]), isEmpty);
    expect(decoder.add(_bytes(_heartRateFrame)), [78]);
  });
}
