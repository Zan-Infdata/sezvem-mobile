import 'package:flutter/services.dart';

/// Position of the overlay window and the usable screen area, in physical
/// pixels. The usable area excludes system bars and display cutouts.
class CompanionWindowLayout {
  const CompanionWindowLayout({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
    required this.screenLeft,
    required this.screenTop,
    required this.screenRight,
    required this.screenBottom,
    required this.density,
  });

  factory CompanionWindowLayout.fromMap(Map<Object?, Object?> map) {
    double read(String key) => (map[key] as num?)?.toDouble() ?? 0;
    return CompanionWindowLayout(
      x: read('x'),
      y: read('y'),
      width: read('width'),
      height: read('height'),
      screenLeft: read('screenLeft'),
      screenTop: read('screenTop'),
      screenRight: read('screenRight'),
      screenBottom: read('screenBottom'),
      density: map['density'] == null ? 1 : read('density'),
    );
  }

  final double x;
  final double y;
  final double width;
  final double height;
  final double screenLeft;
  final double screenTop;
  final double screenRight;
  final double screenBottom;
  final double density;
}

/// Overlay-side access to the native window that hosts the companion.
class CompanionWindow {
  CompanionWindow({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('ixland/companion/window');

  final MethodChannel _channel;

  Future<CompanionWindowLayout> getLayout() async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('getLayout');
    return CompanionWindowLayout.fromMap(map ?? const {});
  }

  /// Called after rotation or a display change with the clamped layout.
  void onLayoutChanged(void Function(CompanionWindowLayout layout) listener) {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'layoutChanged' && call.arguments is Map) {
        listener(CompanionWindowLayout.fromMap(call.arguments as Map));
      }
    });
  }

  Future<void> moveTo(double x, double y) =>
      _channel.invokeMethod<void>('moveTo', {'x': x.round(), 'y': y.round()});

  /// Resizes the window to [size] in logical pixels, keeping its bottom center
  /// in place. Returns the new layout.
  Future<CompanionWindowLayout> resize(Size size) async {
    final map = await _channel.invokeMapMethod<Object?, Object?>('resize', {
      'width': size.width,
      'height': size.height,
    });
    return CompanionWindowLayout.fromMap(map ?? const {});
  }

  /// Plays a rising inflating sound for [duration].
  Future<void> playInflateSound(Duration duration) =>
      _channel.invokeMethod<void>('playInflateSound', {
        'durationMs': duration.inMilliseconds,
      });

  Future<void> stopSound() => _channel.invokeMethod<void>('stopSound');

  Future<void> showAlert({required String title, required String message}) =>
      _channel.invokeMethod<void>('showAlert', {
        'title': title,
        'message': message,
      });

  /// Removes the window and releases the overlay engine.
  Future<void> close() => _channel.invokeMethod<void>('close');
}
