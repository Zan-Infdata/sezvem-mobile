import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:ixland_mobile/companion/companion_state.dart';
import 'package:ixland_mobile/companion/styles/companion_look.dart';
import 'package:ixland_mobile/companion/styles/companion_style.dart';
import 'package:ixland_mobile/companion/styles/companion_styles.dart';
import 'package:ixland_mobile/companion/styles/dress_up/dress_up_parts.dart';
import 'package:ixland_mobile/companion/styles/dress_up/dress_up_style.dart';

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

  test('Dress-up offers 2 bases, 3 hats, and 2 tops, plus none', () {
    final slots = {
      for (final slot in const DressUpCompanionStyle().slots)
        slot.id: [for (final option in slot.options) option.id],
    };
    expect(slots, {
      'base': ['circle', 'triangle'],
      'hat': ['none', 'cat_ears', 'cap', 'top_hat'],
      'top': ['none', 'tshirt', 'doctor_coat'],
    });
  });

  test('Dress-up applies known choices and keeps the rest', () {
    final style = const DressUpCompanionStyle().customize({
      'base': 'triangle',
      'hat': 'cap',
      'top': 'no-such-top',
      'shoes': 'boots',
    });
    expect(style.choices, {'base': 'triangle', 'hat': 'cap', 'top': 'none'});
    expect(
      style,
      const DressUpCompanionStyle(base: TriangleBase(), hat: Cap()),
    );
  });

  group('CompanionLook', () {
    test('round-trips through the saved form', () {
      const look = CompanionLook(
        styleId: 'dress_up',
        choices: {
          'dress_up': {'base': 'triangle', 'hat': 'cat_ears'},
        },
      );
      expect(CompanionLook.fromMap(look.toMap()), look);
      expect(
        look.resolve(),
        const DressUpCompanionStyle(base: TriangleBase(), hat: CatEars()),
      );
    });

    test('bad saved data gives the default look', () {
      final look = CompanionLook.fromMap({'style': 3, 'choices': '{oops'});
      expect(look, const CompanionLook());
      expect(look.resolve(), same(companionStyles.first));
    });

    test('keeps choices for each style separately', () {
      final look = const CompanionLook()
          .withChoice('dress_up', 'hat', 'cap')
          .withChoice('other', 'hat', 'crown')
          .withChoice('dress_up', 'top', 'doctor_coat')
          .withStyle('dress_up');
      expect(look.choices, {
        'dress_up': {'hat': 'cap', 'top': 'doctor_coat'},
        'other': {'hat': 'crown'},
      });
      expect(look.withStyle('classic').resolve().id, 'classic');
      expect(look.resolve().choices['hat'], 'cap');
    });
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

  for (final style in [for (final s in companionStyles) ..._variants(s)]) {
    group(_describe(style), () {
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
            reason:
                '${_describe(style)} draws no change for ${animation.name}.',
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
                _drawsOutside(pixels, size),
                isFalse,
                reason:
                    '${_describe(style)} draws more than '
                    '${CompanionStyle.maxSideOverflow} units past the resting '
                    'width during ${animation.name} at $t facing '
                    '${facing.name}.',
              );
              expect(
                _touchesEdge(pixels, size),
                isFalse,
                reason:
                    '${_describe(style)} draws past its ${size.width.round()}x'
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

/// Every combination of [style]'s slot options, or the style alone.
List<CompanionStyle> _variants(CompanionStyle style) {
  var variants = [style];
  for (final slot in style.slots) {
    variants = [
      for (final variant in variants)
        for (final option in slot.options)
          variant.customize({...variant.choices, slot.id: option.id}),
    ];
  }
  return variants;
}

String _describe(CompanionStyle style) => style.choices.isEmpty
    ? style.name
    : '${style.name} ${style.choices.values.join(' + ')}';

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

/// Whether any pixel is visible in the side columns a style must leave empty:
/// farther than [CompanionStyle.maxSideOverflow] past the resting width.
bool _drawsOutside(Uint8List rgba, ui.Size size) {
  final width = size.width.round();
  final height = size.height.round();
  final margin =
      ((size.width - CompanionStyle.restSize.width) / 2 -
              CompanionStyle.maxSideOverflow)
          .floor();
  for (var x = 0; x < margin; x++) {
    for (var y = 0; y < height; y++) {
      if (rgba[(y * width + x) * 4 + 3] != 0) return true;
      if (rgba[(y * width + width - 1 - x) * 4 + 3] != 0) return true;
    }
  }
  return false;
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
