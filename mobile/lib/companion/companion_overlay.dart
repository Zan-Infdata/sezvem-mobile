import 'package:flutter/services.dart';

import 'styles/companion_look.dart';

/// Main-app access to the companion overlay.
///
/// The rest of the app depends on this interface, not on the Android window
/// implementation behind it.
abstract interface class CompanionOverlay {
  Future<bool> hasPermission();

  /// Opens the system "Display over other apps" screen when access is off.
  /// Completes with whether access is granted after the user returns.
  Future<bool> requestPermission();

  /// Shows the companion. Starts the companion service if it isn't running.
  Future<bool> show();

  /// Removes the companion and stops the companion service.
  Future<void> hide();

  /// Whether the companion is on screen.
  Future<bool> isShowing();

  Stream<void> get dismissals;

  /// Shows an alert when the companion window is available.
  Future<bool> showAlert({required String title, required String message});

  /// Asks the companion to walk to [uv], where (0, 0) is the top left and
  /// (1, 1) the bottom right of the padded screen area. Completes with false if
  /// the companion isn't showing or is busy with another action.
  Future<bool> moveTo(Offset uv);

  /// The companion look chosen in settings.
  Future<CompanionLook> look();

  /// Saves the companion look. A visible companion switches right away.
  Future<void> setLook(CompanionLook look);

  /// Sends the app to the background without closing it.
  Future<void> minimizeApp();
}

class AndroidCompanionOverlay implements CompanionOverlay {
  const AndroidCompanionOverlay();

  static const _channel = MethodChannel('ixland/companion');
  static const _dismissed = EventChannel('ixland/companion/dismissed');
  static final _dismissals = _dismissed.receiveBroadcastStream().map<void>(
    (_) {},
  );

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<bool> show() async =>
      await _channel
          .invokeMethod<bool>('show')
          .timeout(const Duration(seconds: 5), onTimeout: () => false) ??
      false;

  @override
  Future<void> hide() => _channel.invokeMethod<void>('hide');

  @override
  Future<bool> isShowing() async =>
      await _channel.invokeMethod<bool>('isShowing') ?? false;

  @override
  Stream<void> get dismissals => _dismissals;

  @override
  Future<bool> showAlert({
    required String title,
    required String message,
  }) async =>
      await _channel.invokeMethod<bool>('showAlert', {
        'title': title,
        'message': message,
      }) ??
      false;

  @override
  Future<bool> moveTo(Offset uv) async =>
      await _channel.invokeMethod<bool>('moveTo', {'u': uv.dx, 'v': uv.dy}) ??
      false;

  @override
  Future<CompanionLook> look() async => CompanionLook.fromMap(
    await _channel.invokeMapMethod<Object?, Object?>('getLook'),
  );

  @override
  Future<void> setLook(CompanionLook look) =>
      _channel.invokeMethod<void>('setLook', look.toMap());

  @override
  Future<void> minimizeApp() => _channel.invokeMethod<void>('minimizeApp');
}
