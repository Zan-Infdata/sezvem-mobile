import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'assistant_engine.dart';

/// One message in the chat.
class ChatMessage {
  ChatMessage({required this.fromUser, this.text = ''});

  final bool fromUser;
  String text;

  /// Whether the reply is still streaming.
  bool pending = false;

  /// Whether the reply stopped because of an error.
  bool failed = false;
}

/// A chat with the on-device assistant.
///
/// Messages live in memory only. They are gone when this object is disposed,
/// which happens when the companion window closes.
class AssistantChat extends ChangeNotifier {
  AssistantChat(this.engine);

  final AssistantEngine engine;
  final List<ChatMessage> _messages = [];
  StreamSubscription<String>? _reply;
  AssistantState _state = const AssistantState(AssistantStatus.unloaded);
  bool _disposed = false;

  /// Oldest first.
  List<ChatMessage> get messages => List.unmodifiable(_messages);

  AssistantState get state => _state;

  bool get isReplying => _reply != null;

  bool get canSend => _state.status == AssistantStatus.ready && !isReplying;

  /// Loads the model unless it is loaded or loading.
  Future<void> prepare() async {
    if (_state.status == AssistantStatus.ready ||
        _state.status == AssistantStatus.loading) {
      return;
    }
    _setState(const AssistantState(AssistantStatus.loading));
    try {
      _setState(await engine.load());
    } on PlatformException catch (error) {
      _setState(AssistantState(AssistantStatus.error, message: error.message));
    } on MissingPluginException {
      _setState(
        const AssistantState(
          AssistantStatus.error,
          message: 'The on-device model needs the Android app.',
        ),
      );
    }
  }

  /// Sends [text] and appends the streaming reply. Returns false when the
  /// text is blank or [canSend] is false.
  bool send(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty || !canSend) return false;
    final reply = ChatMessage(fromUser: false)..pending = true;
    _messages
      ..add(ChatMessage(fromUser: true, text: trimmed))
      ..add(reply);
    void end({bool failed = false}) {
      reply
        ..pending = false
        ..failed = failed;
      _reply = null;
      _notify();
    }

    _reply = engine
        .send(trimmed)
        .listen(
          (chunk) {
            reply.text += chunk;
            _notify();
          },
          onDone: end,
          onError: (Object error) => end(failed: true),
          cancelOnError: true,
        );
    _notify();
    return true;
  }

  /// Stops the streaming reply and keeps what arrived so far.
  Future<void> stop() async {
    final reply = _reply;
    if (reply == null) return;
    _reply = null;
    await reply.cancel();
    for (final message in _messages) {
      message.pending = false;
    }
    _notify();
    await engine.cancel();
  }

  /// Clears the messages and starts a new conversation.
  Future<void> clear() async {
    await stop();
    _messages.clear();
    _notify();
    if (_state.status == AssistantStatus.ready) await engine.reset();
  }

  void _setState(AssistantState state) {
    _state = state;
    _notify();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _reply?.cancel();
    _reply = null;
    super.dispose();
  }
}
