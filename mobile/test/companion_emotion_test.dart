import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_animator.dart';
import 'package:ixland_mobile/companion/companion_state.dart';

void main() {
  testWidgets('an emotion eases in, holds, eases out, and clears', (
    tester,
  ) async {
    final animator = CompanionAnimator(vsync: const TestVSync());
    var done = false;
    animator
        .emote(CompanionEmotion.happy, duration: const Duration(seconds: 1))
        .then((_) => done = true);
    expect(animator.emotion, CompanionEmotion.happy);
    expect(animator.emotionAmount, 0);

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(animator.emotionAmount, 1);
    expect(animator.emotionTime, closeTo(0.5, 0.02));

    await tester.pump(const Duration(milliseconds: 400));
    expect(animator.emotionAmount, inExclusiveRange(0, 1));

    await tester.pump(const Duration(milliseconds: 200));
    await tester.pump();
    expect(done, isTrue);
    expect(animator.emotion, isNull);
    expect(animator.emotionAmount, 0);
    animator.dispose();
  });

  testWidgets('a new emotion replaces the one playing', (tester) async {
    final animator = CompanionAnimator(vsync: const TestVSync());
    animator.emote(CompanionEmotion.scared);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    animator.emote(CompanionEmotion.laughing);
    await tester.pump();
    expect(animator.emotion, CompanionEmotion.laughing);
    expect(animator.emotionTime, lessThan(0.05));
    await tester.pump(const Duration(seconds: 3));
    expect(animator.emotion, isNull);
    animator.dispose();
  });

  test('every emotion has a duration longer than its fades', () {
    for (final emotion in CompanionEmotion.values) {
      expect(
        CompanionAnimator.emotionDuration(emotion),
        greaterThan(
          CompanionAnimator.emotionRise + CompanionAnimator.emotionFall,
        ),
      );
    }
  });
}
