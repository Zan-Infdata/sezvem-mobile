import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companion/companion_animator.dart';
import '../companion/companion_character.dart';
import '../companion/companion_overlay.dart';
import '../companion/companion_state.dart';
import '../companion/styles/companion_style.dart';
import '../companion/styles/companion_styles.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.companion,
    this.styles = companionStyles,
  });

  final CompanionOverlay companion;

  /// The companion styles to choose from.
  final List<CompanionStyle> styles;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _styleId;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  Future<void> _loadStyle() async {
    String? saved;
    try {
      saved = await widget.companion.styleId();
    } on PlatformException {
      // Fall back to the default style.
    }
    if (!mounted) return;
    setState(() => _styleId = companionStyleById(saved, widget.styles).id);
  }

  Future<void> _selectStyle(String? id) async {
    final previous = _styleId;
    if (id == null || id == previous) return;
    setState(() => _styleId = id);
    try {
      await widget.companion.setStyleId(id);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _styleId = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the companion style.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final styleId = _styleId;
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text(
              'Companion style',
              style: theme.textTheme.titleSmall?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
          ),
          if (styleId == null)
            const Center(child: CircularProgressIndicator())
          else
            RadioGroup<String>(
              groupValue: styleId,
              onChanged: _selectStyle,
              child: Column(
                children: [
                  for (final style in widget.styles)
                    RadioListTile<String>(
                      value: style.id,
                      title: Text(style.name),
                      secondary: SizedBox.square(
                        dimension: 56,
                        child: CompanionStylePreview(style: style),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A small idle companion drawn in [style], for choosing a style.
class CompanionStylePreview extends StatefulWidget {
  const CompanionStylePreview({super.key, required this.style});

  final CompanionStyle style;

  @override
  State<CompanionStylePreview> createState() => _CompanionStylePreviewState();
}

class _CompanionStylePreviewState extends State<CompanionStylePreview>
    with TickerProviderStateMixin {
  late final _animator = CompanionAnimator(vsync: this)
    ..state = CompanionState.idle;

  @override
  void dispose() {
    _animator.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Styles draw for a window of restSize. Scale it down to fit.
    return FittedBox(
      child: SizedBox.fromSize(
        size: CompanionStyle.restSize,
        child: CompanionCharacter(animator: _animator, style: widget.style),
      ),
    );
  }
}
