import 'dart:async';

import 'package:flutter/material.dart';

import '../assistant/assistant_chat.dart';
import '../assistant/assistant_engine.dart';
import 'companion_actions.dart';
import 'companion_animator.dart';
import 'companion_character.dart';
import 'companion_chat_panel.dart';
import 'companion_movement.dart';
import 'companion_test_actions.dart';
import 'companion_window.dart';
import 'styles/companion_style.dart';
import 'styles/companion_styles.dart';

/// Classifies the end of a drag as a swipe input, or null for a small drag
/// that should snap back. The larger axis decides the direction. [distance] is
/// in logical pixels and [velocity] in logical pixels per second.
CompanionInput? classifySwipe({
  required Offset distance,
  required Offset velocity,
}) {
  const minVelocity = 400.0;
  const minDistance = 32.0;
  final Offset vector;
  if (velocity.distance >= minVelocity) {
    vector = velocity;
  } else if (distance.distance >= minDistance) {
    vector = distance;
  } else {
    return null;
  }
  if (vector.dx.abs() >= vector.dy.abs()) {
    return vector.dx < 0 ? CompanionInput.swipeLeft : CompanionInput.swipeRight;
  }
  return vector.dy < 0 ? CompanionInput.swipeUp : CompanionInput.swipeDown;
}

/// Root widget of the overlay engine. It turns gestures into
/// [CompanionInput]s for the action controller.
class CompanionOverlayApp extends StatefulWidget {
  const CompanionOverlayApp({
    super.key,
    this.window,
    this.actions,
    this.styles = companionStyles,
    this.assistant,
  });

  final CompanionWindow? window;

  /// Defaults to [NativeAssistantEngine].
  final AssistantEngine? assistant;

  /// Defaults to [testCompanionActions].
  final Map<CompanionInput, CompanionAction>? actions;

  /// The styles a saved look can pick from.
  final List<CompanionStyle> styles;

  @override
  State<CompanionOverlayApp> createState() => _CompanionOverlayAppState();
}

class _CompanionOverlayAppState extends State<CompanionOverlayApp>
    with TickerProviderStateMixin {
  late final _window = widget.window ?? CompanionWindow();
  late final _animator = CompanionAnimator(vsync: this);
  CompanionMovementController? _movement;
  CompanionActionController? _actions;
  Completer<void>? _hold;
  late CompanionStyle _style = widget.styles.first;
  Offset _drag = Offset.zero;

  /// Kept for the life of the overlay, so reopening the chat shows earlier
  /// messages. Nothing is saved.
  AssistantChat? _chat;
  Completer<void>? _chatClosed;

  /// Where the character is in the expanded window, in logical pixels. The
  /// head stays exactly there while the chat is open. Null while the chat is
  /// closed.
  Rect? _chatHead;

  /// Whether the backdrop and panel are faded in.
  bool _chatShown = false;

  static const _chatFade = Duration(milliseconds: 180);

  @override
  void initState() {
    super.initState();
    unawaited(_start());
  }

  Future<void> _start() async {
    final layout = await _window.getLayout();
    final look = await _window.getLook();
    if (!mounted) return;
    setState(() => _style = look.resolve(widget.styles));
    final movement = _movement = CompanionMovementController(
      window: _window,
      layout: layout,
      vsync: this,
      // Leave room for the backflip and inflation to grow the window.
      reserve: CompanionStyle.growthRoom,
    );
    final actions = _actions = CompanionActionController(
      actions: widget.actions ?? testCompanionActions(),
      animator: _animator,
      movement: movement,
      window: _window,
      openChat: _openChat,
    );
    _window.listen(
      onLayoutChanged: movement.updateLayout,
      // Moves from the main app follow the same one-at-a-time rule as inputs.
      onMoveTo: (uv) => actions.run((context) => walkToUv(context, uv)),
      onLookChanged: (look) {
        if (!mounted) return;
        setState(() => _style = look.resolve(widget.styles));
      },
      onBack: _closeChat,
    );
    actions.run(enterFromRight);
  }

  /// Expands the window around the character, which becomes the chat head,
  /// and fades in the panel below it. Completes after the user closes the
  /// chat and the window is small again.
  Future<void> _openChat() async {
    final movement = _movement;
    if (movement == null || !mounted) return;
    final from = await _window.getLayout();
    final expanded = await _window.expand();
    if (!mounted) return;
    final density = expanded.density;
    final chat = _chat ??= AssistantChat(
      widget.assistant ?? NativeAssistantEngine(),
    );
    unawaited(chat.prepare());
    final closed = _chatClosed = Completer<void>();
    setState(() {
      _chatHead = Rect.fromLTWH(
        (from.x - expanded.x) / density,
        (from.y - expanded.y) / density,
        from.width / density,
        from.height / density,
      );
      _chatShown = false;
    });
    // Fade in from the next frame, so the expanded window first shows only
    // the character where it already was.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _chatHead != null) setState(() => _chatShown = true);
    });
    await closed.future;
    if (!mounted) return;
    setState(() => _chatShown = false);
    await Future<void>.delayed(_chatFade);
    if (!mounted) return;
    setState(() => _chatHead = null);
    movement.updateLayout(await _window.collapse());
  }

  void _closeChat() {
    final closed = _chatClosed;
    _chatClosed = null;
    if (closed != null && !closed.isCompleted) closed.complete();
  }

  bool _accepts() {
    final actions = _actions;
    return actions != null && !actions.isBusy && !actions.isClosed;
  }

  void _onPanUpdate(DragUpdateDetails details) {
    if (!_accepts()) return;
    setState(() => _drag += details.delta);
  }

  void _onPanEnd(DragEndDetails details) {
    final input = classifySwipe(
      distance: _drag,
      velocity: details.velocity.pixelsPerSecond,
    );
    setState(() => _drag = Offset.zero);
    if (input != null) _actions?.handle(input);
  }

  void _onHoldStart(LongPressStartDetails details) {
    final hold = _hold = Completer<void>();
    if (_actions?.handle(CompanionInput.hold, released: hold.future) != true) {
      _endHold();
    }
  }

  void _endHold() {
    final hold = _hold;
    _hold = null;
    if (hold != null && !hold.isCompleted) hold.complete();
  }

  @override
  void dispose() {
    _closeChat();
    _chat?.dispose();
    _actions?.dispose();
    _endHold();
    _movement?.dispose();
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // MaterialApp supplies what the chat's text field needs. It paints no
    // background, so the overlay stays transparent around the character.
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      color: const Color(0x00000000),
      home: _chatHead == null ? _buildCharacter() : _buildChat(),
    );
  }

  Widget _buildChat() {
    final chat = _chat!;
    final head = _chatHead!;
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: _closeChat,
            child: AnimatedOpacity(
              opacity: _chatShown ? 1 : 0,
              duration: _chatFade,
              child: const ColoredBox(color: Color(0x8A000000)),
            ),
          ),
        ),
        Positioned(
          left: 12,
          right: 12,
          top: head.bottom + 4,
          bottom: 12 + keyboard,
          child: AnimatedOpacity(
            opacity: _chatShown ? 1 : 0,
            duration: _chatFade,
            child: CompanionChatPanel(chat: chat, onClose: _closeChat),
          ),
        ),
        Positioned.fromRect(
          rect: head,
          child: Semantics(
            button: true,
            label: 'IXLand companion. Tap to close the chat.',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: _closeChat,
              child: CompanionCharacter(animator: _animator, style: _style),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCharacter() {
    return Directionality(
      textDirection: TextDirection.ltr,
      child: Semantics(
        button: true,
        label:
            'IXLand companion. Tap to chat. Hold or swipe in any direction to interact.',
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => _actions?.handle(CompanionInput.tap),
          onPanUpdate: _onPanUpdate,
          onPanEnd: _onPanEnd,
          onLongPressStart: _onHoldStart,
          onLongPressEnd: (_) => _endHold(),
          onLongPressCancel: _endHold,
          child: Transform.translate(
            // Follow the finger a little inside the window as drag feedback.
            offset: Offset(
              _drag.dx.clamp(-16.0, 16.0),
              _drag.dy.clamp(-16.0, 16.0),
            ),
            child: CompanionCharacter(animator: _animator, style: _style),
          ),
        ),
      ),
    );
  }
}
