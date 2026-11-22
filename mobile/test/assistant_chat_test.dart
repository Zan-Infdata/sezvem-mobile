import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/assistant/assistant_chat.dart';
import 'package:ixland_mobile/assistant/assistant_engine.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AssistantChat', () {
    test('loads once, then streams a reply into one message', () async {
      final engine = _FakeEngine();
      final chat = AssistantChat(engine);
      expect(chat.canSend, isFalse);
      expect(chat.send('Too early'), isFalse);

      await chat.prepare();
      await chat.prepare();
      expect(engine.loads, 1);
      expect(chat.canSend, isTrue);

      expect(chat.send('   '), isFalse);
      expect(chat.send('  Hello  '), isTrue);
      expect(engine.sent, ['Hello']);
      expect(chat.canSend, isFalse);
      expect(chat.messages.last.pending, isTrue);

      engine.reply
        ..add('Hi')
        ..add(' there');
      await engine.reply.close();
      await pumpEventQueue();
      expect(chat.messages.map((m) => (m.fromUser, m.text)), [
        (true, 'Hello'),
        (false, 'Hi there'),
      ]);
      expect(chat.messages.last.pending, isFalse);
      expect(chat.canSend, isTrue);
      chat.dispose();
    });

    test('a failed reply keeps its text and allows another message', () async {
      final engine = _FakeEngine();
      final chat = AssistantChat(engine);
      await chat.prepare();
      chat.send('Hello');
      engine.reply
        ..add('Partial')
        ..addError(PlatformException(code: 'reply_failed'));
      await pumpEventQueue();
      expect(chat.messages.last.text, 'Partial');
      expect(chat.messages.last.failed, isTrue);
      expect(chat.canSend, isTrue);
      chat.dispose();
    });

    test(
      'stop cancels the reply, and clear starts a new conversation',
      () async {
        final engine = _FakeEngine();
        final chat = AssistantChat(engine);
        await chat.prepare();
        chat.send('Hello');
        engine.reply.add('Hi');
        await pumpEventQueue();
        await chat.stop();
        expect(engine.cancels, 1);
        expect(chat.messages.last.pending, isFalse);
        expect(chat.canSend, isTrue);

        await chat.clear();
        expect(chat.messages, isEmpty);
        expect(engine.resets, 1);
        chat.dispose();
      },
    );

    test('a load error becomes the error state', () async {
      final engine = _FakeEngine()
        ..loadError = PlatformException(code: 'x', message: 'Out of memory');
      final chat = AssistantChat(engine);
      await chat.prepare();
      expect(chat.state.status, AssistantStatus.error);
      expect(chat.state.message, 'Out of memory');
      expect(chat.canSend, isFalse);
      chat.dispose();
    });

    test(
      'check-in starts with a model turn and no visible user message',
      () async {
        final engine = _FakeEngine();
        final chat = AssistantChat(
          engine,
          skill: AssistantSkill.criticalHeartRate,
        );
        addTearDown(chat.dispose);

        await chat.prepare();
        expect(engine.skill, AssistantSkill.criticalHeartRate);
        expect(engine.sent.single, contains('Begin the monitoring check-in'));
        expect(chat.messages.single.fromUser, isFalse);
        await chat.prepare();
        expect(engine.sent, hasLength(1));
      },
    );
  });

  test('soul.md is bundled and sets the refusal sentence', () async {
    final soul = await rootBundle.loadString(NativeAssistantEngine.soulAsset);
    expect(soul, contains('medical help assistant'));
    expect(soul, contains("I don't know that, I'm a medical expert."));
  });

  group('NativeAssistantEngine', () {
    const methods = MethodChannel('test/assistant');
    const events = EventChannel('test/assistant/events');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late List<MethodCall> calls;
    late StreamController<Object?> replies;

    setUp(() {
      calls = [];
      replies = StreamController<Object?>.broadcast();
      messenger.setMockMethodCallHandler(methods, (call) async {
        calls.add(call);
        if (call.method == 'load') {
          return {
            'state': 'ready',
            'modelPath': '/files/models/gemma-4-E2B-it.litertlm',
            'backend': 'gpu',
            'loadMs': 2500,
          };
        }
        if (call.method == 'send' && call.arguments['text'] == 'busy') {
          throw PlatformException(code: 'not_ready', message: 'Busy.');
        }
        return null;
      });
      StreamSubscription<Object?>? forward;
      messenger.setMockStreamHandler(
        events,
        MockStreamHandler.inline(
          onListen: (arguments, sink) =>
              forward = replies.stream.listen(sink.success),
          onCancel: (arguments) => forward?.cancel(),
        ),
      );
    });

    tearDown(() {
      messenger.setMockMethodCallHandler(methods, null);
      messenger.setMockStreamHandler(events, null);
    });

    NativeAssistantEngine create() => NativeAssistantEngine(
      backend: 'gpu',
      loadSoul: () async => 'Only medicine.',
      methods: methods,
      events: events,
    );

    test('load passes the backend and reads the status', () async {
      final state = await create().load();
      expect(calls.single.arguments, {
        'backend': 'gpu',
        'systemInstruction': 'Only medicine.',
      });
      expect(state.status, AssistantStatus.ready);
      expect(state.backend, 'gpu');
      expect(state.loadTime, const Duration(milliseconds: 2500));
      expect(state.modelPath, '/files/models/gemma-4-E2B-it.litertlm');
    });

    test(
      'load appends the bundled check-in instructions only for the skill',
      () async {
        final engine = create();
        await engine.load(skill: AssistantSkill.criticalHeartRate);
        await engine.load();

        final args = calls.first.arguments as Map;
        expect(args['skill'], 'criticalHeartRate');
        expect(args['systemInstruction'], startsWith('Only medicine.\n\n'));
        final skill = await rootBundle.loadString(
          AssistantSkill.criticalHeartRate.asset,
        );
        expect(args['systemInstruction'], endsWith(skill));
        expect(skill, contains('report_heart_rate_check_in'));
        expect(calls.last.arguments, {
          'backend': 'gpu',
          'systemInstruction': 'Only medicine.',
        });
      },
    );

    test('send streams the chunks for its own id until done', () async {
      final engine = create();
      final received = <String>[];
      final done = Completer<void>();
      engine.send('Hello').listen(received.add, onDone: done.complete);
      await pumpEventQueue();
      expect(calls.single.arguments, {'id': 0, 'text': 'Hello'});

      replies
        ..add({'id': 0, 'type': 'chunk', 'text': 'Hi'})
        ..add({'id': 7, 'type': 'chunk', 'text': 'other reply'})
        ..add({'id': 0, 'type': 'chunk', 'text': '!'})
        ..add({'id': 0, 'type': 'done'});
      await done.future;
      expect(received, ['Hi', '!']);

      // The next message uses the next id.
      engine.send('Again').listen((_) {});
      await pumpEventQueue();
      expect(calls.last.arguments, {'id': 1, 'text': 'Again'});
    });

    test('a refused send or a reply error fails the stream', () async {
      final engine = create();
      await expectLater(
        engine.send('busy'),
        emitsError(isA<PlatformException>()),
      );

      final received = <Object>[];
      final done = Completer<void>();
      engine
          .send('Hello')
          .listen(received.add, onError: received.add, onDone: done.complete);
      await pumpEventQueue();
      replies
        ..add({'id': 1, 'type': 'chunk', 'text': 'Part'})
        ..add({'id': 1, 'type': 'error', 'text': 'Ran out of memory'});
      await done.future;
      expect(received.first, 'Part');
      expect(
        received.last,
        isA<PlatformException>().having(
          (e) => e.message,
          'message',
          'Ran out of memory',
        ),
      );
      expect(received, hasLength(2));
    });
  });
}

class _FakeEngine implements AssistantEngine {
  var loads = 0;
  var cancels = 0;
  var resets = 0;
  PlatformException? loadError;
  AssistantSkill? skill;
  final sent = <String>[];
  final reply = StreamController<String>();

  @override
  Future<AssistantState> status() async =>
      const AssistantState(AssistantStatus.unloaded);

  @override
  Future<AssistantState> load({AssistantSkill? skill}) async {
    loads++;
    this.skill = skill;
    final error = loadError;
    if (error != null) throw error;
    return const AssistantState(AssistantStatus.ready, backend: 'cpu');
  }

  @override
  Stream<String> send(String text) {
    sent.add(text);
    return reply.stream;
  }

  @override
  Future<void> cancel() async => cancels++;

  @override
  Future<void> reset() async => resets++;
}
