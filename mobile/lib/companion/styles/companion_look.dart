import 'dart:convert';

import 'package:flutter/foundation.dart';

import 'companion_style.dart';
import 'companion_styles.dart';

/// The companion look saved in settings: the chosen style and, for each
/// style, the options chosen for its slots.
@immutable
class CompanionLook {
  const CompanionLook({this.styleId, this.choices = const {}});

  /// Reads the form saved by the native side. Bad data gives the default look.
  factory CompanionLook.fromMap(Map<Object?, Object?>? map) {
    final styleId = map?['style'];
    final encoded = map?['choices'];
    final choices = <String, Map<String, String>>{};
    if (encoded is String) {
      try {
        final decoded = jsonDecode(encoded);
        if (decoded is Map) {
          for (final MapEntry(:key, :value) in decoded.entries) {
            if (key is String && value is Map) {
              choices[key] = {
                for (final MapEntry(key: slot, value: option) in value.entries)
                  if (slot is String && option is String) slot: option,
              };
            }
          }
        }
      } on FormatException {
        // Keep the default choices.
      }
    }
    return CompanionLook(
      styleId: styleId is String ? styleId : null,
      choices: choices,
    );
  }

  /// The chosen style ID, or null for the default style.
  final String? styleId;

  /// Slot choices per style ID, mapping slot IDs to option IDs.
  final Map<String, Map<String, String>> choices;

  /// The chosen style from [styles] with its saved choices applied.
  CompanionStyle resolve([List<CompanionStyle> styles = companionStyles]) {
    final style = companionStyleById(styleId, styles);
    return style.customize(choices[style.id] ?? const {});
  }

  CompanionLook withStyle(String id) =>
      CompanionLook(styleId: id, choices: choices);

  /// This look with [optionId] chosen for [slotId] on the style [styleId].
  CompanionLook withChoice(String styleId, String slotId, String optionId) =>
      CompanionLook(
        styleId: this.styleId,
        choices: {
          ...choices,
          styleId: {...?choices[styleId], slotId: optionId},
        },
      );

  /// The form the native side saves.
  Map<String, Object?> toMap() => {
    'style': styleId,
    'choices': jsonEncode(choices),
  };

  @override
  bool operator ==(Object other) =>
      other is CompanionLook &&
      other.styleId == styleId &&
      mapEquals(other.toMap(), toMap());

  @override
  int get hashCode => Object.hash(styleId, jsonEncode(choices));
}
