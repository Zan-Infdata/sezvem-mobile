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

sealed class WearableSample extends WearableEvent {
  const WearableSample({required this.receivedAt});

  final DateTime receivedAt;
}

final class HeartRateSample extends WearableSample {
  const HeartRateSample({required this.bpm, required super.receivedAt});

  final int bpm;
}

final class TemperatureSample extends WearableSample {
  const TemperatureSample({required this.celsius, required super.receivedAt});

  final double celsius;
}

final class StepCountSample extends WearableSample {
  const StepCountSample({required this.count, required super.receivedAt});

  final int count;
}

final class WearableException implements Exception {
  const WearableException(this.message);

  final String message;
}
