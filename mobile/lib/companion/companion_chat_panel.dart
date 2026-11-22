import 'package:flutter/material.dart';

import '../app_names.dart';
import '../assistant/assistant_chat.dart';
import '../assistant/assistant_engine.dart';

/// The chat with the on-device assistant, shown below the companion's head
/// while the chat is open.
class CompanionChatPanel extends StatefulWidget {
  const CompanionChatPanel({
    super.key,
    required this.chat,
    required this.onClose,
  });

  final AssistantChat chat;
  final VoidCallback onClose;

  @override
  State<CompanionChatPanel> createState() => _CompanionChatPanelState();
}

class _CompanionChatPanelState extends State<CompanionChatPanel> {
  final _input = TextEditingController();

  void _send() {
    if (widget.chat.send(_input.text)) _input.clear();
  }

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      color: theme.colorScheme.surface,
      child: ListenableBuilder(
        listenable: widget.chat,
        builder: (context, _) {
          final chat = widget.chat;
          return Column(
            children: [
              _Header(chat: chat, onClose: widget.onClose),
              const Divider(height: 1),
              Expanded(child: _Messages(chat: chat)),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _input,
                        minLines: 1,
                        maxLines: 4,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        decoration: InputDecoration(
                          hintText: chat.state.status == AssistantStatus.ready
                              ? 'Message'
                              : 'Waiting for the model',
                          border: InputBorder.none,
                        ),
                      ),
                    ),
                    if (chat.isReplying)
                      IconButton(
                        tooltip: 'Stop',
                        onPressed: chat.stop,
                        icon: const Icon(Icons.stop_circle_outlined),
                      )
                    else
                      IconButton(
                        tooltip: 'Send',
                        onPressed: chat.canSend ? _send : null,
                        icon: const Icon(Icons.send),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.chat, required this.onClose});

  final AssistantChat chat;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(companionName, style: theme.textTheme.titleMedium),
                Text(
                  _statusLine(chat.state),
                  style: theme.textTheme.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'New chat',
            onPressed: chat.messages.isEmpty ? null : chat.clear,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Close chat',
            onPressed: onClose,
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }

  static String _statusLine(AssistantState state) {
    switch (state.status) {
      case AssistantStatus.unloaded:
      case AssistantStatus.loading:
        return 'Loading Gemma on this phone…';
      case AssistantStatus.ready:
        final backend = state.backend?.toUpperCase() ?? 'CPU';
        final time = state.loadTime;
        final loaded = time == null
            ? ''
            : ' · loaded in ${(time.inMilliseconds / 1000).toStringAsFixed(1)} s';
        return 'Gemma 4 E2B on $backend$loaded · nothing is saved';
      case AssistantStatus.missing:
        return 'Model file not found';
      case AssistantStatus.error:
        return 'The model could not load';
    }
  }
}

class _Messages extends StatelessWidget {
  const _Messages({required this.chat});

  final AssistantChat chat;

  @override
  Widget build(BuildContext context) {
    final notice = _notice(chat.state);
    final messages = chat.messages;
    if (messages.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            notice ??
                'Say hello. The chat runs on this phone and is not saved.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }
    // Reversed so the newest message stays at the bottom, above the input.
    return ListView.builder(
      reverse: true,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      itemCount: messages.length,
      itemBuilder: (context, index) =>
          _Bubble(message: messages[messages.length - 1 - index]),
    );
  }

  static String? _notice(AssistantState state) {
    switch (state.status) {
      case AssistantStatus.missing:
        return 'Copy ${_fileName(state.modelPath)} to the phone with ADB. '
            'The app expects it at ${state.modelPath ?? 'its files folder'}. '
            'See docs/mobile-implementation.md.';
      case AssistantStatus.error:
        return 'The model could not load: ${state.message ?? 'unknown error'}.';
      case AssistantStatus.unloaded:
      case AssistantStatus.loading:
      case AssistantStatus.ready:
        return null;
    }
  }

  static String _fileName(String? path) =>
      path == null ? 'the model file' : path.split('/').last;
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final ChatMessage message;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fromUser = message.fromUser;
    final String text;
    if (message.text.isNotEmpty) {
      text = message.failed
          ? '${message.text}\n(Reply stopped.)'
          : message.text;
    } else if (message.pending) {
      text = '…';
    } else {
      text = message.failed ? 'No reply. Try again.' : '(No reply.)';
    }
    return Align(
      alignment: fromUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 280),
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: fromUser ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: fromUser ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
