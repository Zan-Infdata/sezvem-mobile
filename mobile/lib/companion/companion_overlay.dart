import 'package:flutter/services.dart';

/// Main-app access to the companion overlay.
///
/// The rest of the app depends on this interface, not on the Android window
/// implementation behind it.
abstract interface class CompanionOverlay {
  Future<bool> hasPermission();

  /// Opens the system "Display over other apps" screen when access is off.
  /// Completes with whether access is granted after the user returns.
  Future<bool> requestPermission();

  Future<void> show();
  Future<void> hide();

  /// Sends the app to the background without closing it.
  Future<void> minimizeApp();
}

class AndroidCompanionOverlay implements CompanionOverlay {
  const AndroidCompanionOverlay();

  static const _channel = MethodChannel('ixland/companion');

  @override
  Future<bool> hasPermission() async =>
      await _channel.invokeMethod<bool>('hasPermission') ?? false;

  @override
  Future<bool> requestPermission() async =>
      await _channel.invokeMethod<bool>('requestPermission') ?? false;

  @override
  Future<void> show() => _channel.invokeMethod<void>('show');

  @override
  Future<void> hide() => _channel.invokeMethod<void>('hide');

  @override
  Future<void> minimizeApp() => _channel.invokeMethod<void>('minimizeApp');
}
