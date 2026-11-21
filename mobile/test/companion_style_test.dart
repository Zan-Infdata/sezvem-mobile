import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_state.dart';
import 'package:ixland_mobile/companion/styles/companion_style.dart';
import 'package:ixland_mobile/companion/styles/companion_styles.dart';

/// Checks the contract in `companion_style.dart` for every registered style.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('styles have unique IDs and names', () {
    final ids = companionStyles.map((style) => style.id).toList();
    expect(ids.toSet(), hasLength(ids.length));
    for (final style in companionStyles) {
      expect(style.id, isNotEmpty);
      expect(style.name, isNotEmpty);
    }
  });

  test('unknown or missing IDs fall back to the first style', () {
    expect(companionStyleById(null), same(companionStyles.first));
    expect(companionStyleById('no-such-style'), same(companionStyles.first));
  });

  test('detects a style that skips an animation', () async {
    const style = _NoSadStyle();
    final rest = await _render(
      style,
      CompanionStyle.restSize,
      const CompanionPose(),
    );
    final sad = await _render(
      style,
      CompanionStyle.restSize,
      CompanionPose.example(CompanionAnimation.sad),
    );
    final blink = await _render(
      style,
      CompanionStyle.restSize,
      CompanionPose.example(CompanionAnimation.blink),
    );
    expect(_same(rest, sad), isTrue);
    expect(_same(rest, blink), isFalse);
  });

  for (final style in companionStyles) {
    group(style.name, () {
      for (final animation in CompanionAnimation.values) {
        test('shows the ${animation.name} animation', () async {
          final size = _windowFor(animation);
          final rest = await _render(style, size, const CompanionPose());
          final active = await _render(
            style,
            size,
            CompanionPose.example(animation),
          );
          expect(
            _same(rest, active),
            isFalse,
            reason: '${style.name} draws no change for ${animation.name}.',
          );
        });
      }

      test('turns to face both ways', () async {
        final left = await _render(
          style,
          CompanionStyle.restSize,
          const CompanionPose(facing: CompanionFacing.left),
        );
        final right = await _render(
          style,
          CompanionStyle.restSize,
          const CompanionPose(facing: CompanionFacing.right),
        );
        expect(_same(left, right), isFalse);
      });

      test('stays inside its window for every animation', () async {
        for (final animation in CompanionAnimation.values) {
          final size = _windowFor(animation);
          for (final facing in CompanionFacing.values) {
            for (var step = 0; step <= 10; step++) {
              final t = step / 10;
              final pose = _poseAt(animation, t, facing);
              final pixels = await _render(style, size, pose);
              expect(
                _touchesEdge(pixels, size),
                isFalse,
                reason:
                    '${style.name} draws past its ${size.width.round()}x'
                    '${size.height.round()} window during ${animation.name} '
                    'at $t facing ${facing.name}.',
              );
            }
          }
        }
      });
    });
  }
}

/// Draws a blinking dot but ignores sadness.
class _NoSadStyle extends CompanionStyle {
  const _NoSadStyle();

  @override
  String get id => 'no-sad';

  @override
  String get name => 'No sad';

  @override
  void paint(ui.Canvas canvas, ui.Size size, CompanionPose pose) {
    canvas.drawCircle(
      size.center(ui.Offset.zero),
      20 * (1 - pose.blink * 0.5),
      ui.Paint()..color = const ui.Color(0xFF000000),
    );
  }
}

ui.Size _windowFor(CompanionAnimation animation) => switch (animation) {
  CompanionAnimation.backflip => CompanionStyle.backflipSize,
  CompanionAnimation.inflate => CompanionStyle.inflateSize,
  _ => CompanionStyle.restSize,
};

/// [animation] at progress [t] from 0 to 1, with everything else at rest.
CompanionPose _poseAt(
  CompanionAnimation animation,
  double t,
  CompanionFacing facing,
) => switch (animation) {
  CompanionAnimation.idle => CompanionPose(idle: t, facing: facing),
  CompanionAnimation.walk => CompanionPose(
    walking: true,
    walk: t,
    facing: facing,
  ),
  CompanionAnimation.blink => CompanionPose(blink: t, facing: facing),
  CompanionAnimation.bounce => CompanionPose(bounce: t, facing: facing),
  CompanionAnimation.backflip => CompanionPose(backflip: t, facing: facing),
  CompanionAnimation.sad => CompanionPose(sad: t, facing: facing),
  CompanionAnimation.inflate => CompanionPose(
    inflate: 1 + t * (CompanionStyle.maxInflate - 1),
    facing: facing,
  ),
};

Future<Uint8List> _render(
  CompanionStyle style,
  ui.Size size,
  CompanionPose pose,
) async {
  final recorder = ui.PictureRecorder();
  style.paint(ui.Canvas(recorder), size, pose);
  final image = await recorder.endRecording().toImage(
    size.width.round(),
    size.height.round(),
  );
  final bytes = await image.toByteData();
  image.dispose();
  return bytes!.buffer.asUint8List();
}

bool _same(Uint8List a, Uint8List b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

/// Whether any pixel on the outer edge of the image is visible.
bool _touchesEdge(Uint8List rgba, ui.Size size) {
  final width = size.width.round();
  final height = size.height.round();
  bool visible(int x, int y) => rgba[(y * width + x) * 4 + 3] != 0;
  for (var x = 0; x < width; x++) {
    if (visible(x, 0) || visible(x, height - 1)) return true;
  }
  for (var y = 0; y < height; y++) {
    if (visible(0, y) || visible(width - 1, y)) return true;
  }
  return false;
}
