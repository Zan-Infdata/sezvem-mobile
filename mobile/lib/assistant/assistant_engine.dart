import 'dart:async';

import 'package:flutter/services.dart';

/// Where the on-device model is in its lifecycle.
enum AssistantStatus {
  /// The model file is on the phone but not loaded.
  unloaded,
  loading,
  ready,

  /// The model file isn't on the phone. See [AssistantState.modelPath].
  missing,

  /// Loading failed. See [AssistantState.message].
  error,
}

/// A snapshot of the on-device model.
class AssistantState {
  const AssistantState(
    this.status, {
    this.modelPath,
    this.backend,
    this.loadTime,
    this.message,
  });

  factory AssistantState.fromMap(Map<Object?, Object?>? map) {
    final name = map?['state'] as String?;
    final loadMs = map?['loadMs'] as num?;
    return AssistantState(
      AssistantStatus.values.firstWhere(
        (status) => status.name == name,
        orElse: () => AssistantStatus.error,
      ),
      modelPath: map?['modelPath'] as String?,
      backend: map?['backend'] as String?,
      loadTime: loadMs == null ? null : Duration(milliseconds: loadMs.round()),
      message: map?['message'] as String?,
    );
  }

  final AssistantStatus status;

  /// Where the phone expects the model file.
  final String? modelPath;

  /// `cpu` or `gpu`.
  final String? backend;

  /// How long the last load took.
  final Duration? loadTime;

  /// The error that stopped loading.
  final String? message;
}

/// Runs a chat model on the phone. Messages stay on the device.
abstract interface class AssistantEngine {
  Future<AssistantState> status();

  /// Loads the model if needed. Can take several seconds.
  Future<AssistantState> load({String? checkInPrompt});

  /// Sends [text] in the current conversation and streams the reply in
  /// chunks. The stream ends when the reply is complete and fails if
  /// generation fails.
  Stream<String> send(String text);

  /// Stops the reply that is streaming.
  Future<void> cancel();

  /// Starts a new conversation. The model stays loaded.
  Future<void> reset();
}

/// [AssistantEngine] backed by LiteRT-LM in `AssistantEngine.kt`.
class NativeAssistantEngine implements AssistantEngine {
  NativeAssistantEngine({
    this.backend = const String.fromEnvironment(
      'ASSISTANT_BACKEND',
      defaultValue: 'cpu',
    ),
    Future<String> Function()? loadSoul,
    MethodChannel? methods,
    EventChannel? events,
  }) : _loadSoul = loadSoul ?? (() => rootBundle.loadString(soulAsset)),
       _methods = methods ?? const MethodChannel('ixland/assistant'),
       _events = events ?? const EventChannel('ixland/assistant/events');

  /// Who the assistant is and what it answers. Sent as the system instruction
  /// when the model loads.
  static const soulAsset = 'assets/soul.md';

  /// `cpu` or `gpu`. Set with `--dart-define=ASSISTANT_BACKEND=gpu`.
  final String backend;
  final Future<String> Function() _loadSoul;
  final MethodChannel _methods;
  final EventChannel _events;
  Stream<Map<Object?, Object?>>? _replies;
  var _nextId = 0;

  @override
  Future<AssistantState> status() async => AssistantState.fromMap(
    await _methods.invokeMapMethod<Object?, Object?>('status'),
  );

  @override
  Future<AssistantState> load({String? checkInPrompt}) async {
    final soul = await _loadSoul();
    return AssistantState.fromMap(
      await _methods.invokeMapMethod('load', {
        'backend': backend,
        'systemInstruction': checkInPrompt == null
            ? soul
            : '$soul\n\n$checkInPrompt',
        if (checkInPrompt != null) 'checkIn': true,
      }),
    );
  }

  @override
  Stream<String> send(String text) {
    final id = _nextId++;
    final replies = _replies ??= _events.receiveBroadcastStream().map(
      (event) => event as Map<Object?, Object?>,
    );
    final controller = StreamController<String>();
    StreamSubscription<Map<Object?, Object?>>? subscription;
    Future<void> finish([Object? error]) async {
      await subscription?.cancel();
      if (controller.isClosed) return;
      if (error != null) controller.addError(error);
      await controller.close();
    }

    controller.onListen = () {
      subscription = replies.where((event) => event['id'] == id).listen((
        event,
      ) {
        switch (event['type']) {
          case 'chunk':
            controller.add(event['text'] as String? ?? '');
          case 'done':
            finish();
          case 'error':
            finish(
              PlatformException(
                code: 'reply_failed',
                message: event['text'] as String?,
              ),
            );
        }
      });
      // Subscribe before sending so no chunk is missed.
      _methods
          .invokeMethod<void>('send', {'id': id, 'text': text})
          .catchError(finish);
    };
    controller.onCancel = () => subscription?.cancel();
    return controller.stream;
  }

  @override
  Future<void> cancel() => _methods.invokeMethod<void>('cancel');

  @override
  Future<void> reset() => _methods.invokeMethod<void>('reset');
}
