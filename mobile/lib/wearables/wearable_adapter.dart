abstract interface class WearableAdapter {
  List<String> get setupSteps;

  Stream<WearableDevice> scan();
  Stream<WearableEvent> connect(WearableDevice device);
}

final class WearableDevice {
  const WearableDevice({required this.id, required this.name});

  final String id;
  final String name;
}

sealed class WearableEvent {
  const WearableEvent();
}

final class WearableConnected extends WearableEvent {
  const WearableConnected();
}

final class HeartRateSample extends WearableEvent {
  const HeartRateSample({required this.bpm, required this.receivedAt});

  final int bpm;
  final DateTime receivedAt;
}

final class WearableException implements Exception {
  const WearableException(this.message);

  final String message;
}
