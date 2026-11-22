import 'package:flutter/services.dart';

import '../assistant/assistant_engine.dart';
import 'styles/companion_look.dart';

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

  /// The companion look chosen in settings.
  Future<CompanionLook> getLook() async => CompanionLook.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>('getLook'),
  );

  /// Handles calls from the service. [onLayoutChanged] receives the clamped
  /// layout after rotation or a display change. [onMoveTo] receives a point in
  /// 0 to 1 screen coordinates from the main app and returns whether the
  /// companion accepted the move. [onLookChanged] receives a newly chosen
  /// look. [onBack] runs when Back is pressed while the window is expanded.
  void listen({
    required void Function(CompanionWindowLayout layout) onLayoutChanged,
    required bool Function(Offset uv) onMoveTo,
    required void Function(CompanionLook look) onLookChanged,
    void Function()? onBack,
    void Function(AssistantSkill skill)? onCheckIn,
    void Function()? onClearCheckIn,
  }) {
    _channel.setMethodCallHandler((call) async {
      final args = call.arguments is Map ? call.arguments as Map : const {};
      switch (call.method) {
        case 'layoutChanged':
          onLayoutChanged(CompanionWindowLayout.fromMap(args));
          return null;
        case 'moveToUv':
          final u = (args['u'] as num?)?.toDouble();
          final v = (args['v'] as num?)?.toDouble();
          if (u == null || v == null) return false;
          return onMoveTo(Offset(u, v));
        case 'lookChanged':
          onLookChanged(CompanionLook.fromMap(args));
          return null;
        case 'backPressed':
          onBack?.call();
          return null;
        case 'startCheckIn':
          for (final skill in AssistantSkill.values) {
            if (skill.name == args['skill']) onCheckIn?.call(skill);
          }
          return null;
        case 'clearCheckIn':
          onClearCheckIn?.call();
          return null;
      }
      throw MissingPluginException(call.method);
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

  /// Grows the window to the usable screen and lets it take keyboard focus.
  /// Moves and resizes are ignored until [collapse]. Returns the new layout.
  Future<CompanionWindowLayout> expand() async => CompanionWindowLayout.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>('expand') ?? const {},
  );

  /// Returns the window to where it was before [expand]. Returns the layout.
  Future<CompanionWindowLayout> collapse() async =>
      CompanionWindowLayout.fromMap(
        await _channel.invokeMapMethod<Object?, Object?>('collapse') ??
            const {},
      );

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
