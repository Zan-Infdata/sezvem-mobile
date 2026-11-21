import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companion/companion_animator.dart';
import '../companion/companion_character.dart';
import '../companion/companion_overlay.dart';
import '../companion/companion_state.dart';
import '../companion/styles/companion_style.dart';
import '../companion/styles/companion_styles.dart';
import 'patient_settings.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.companion,
    required this.patientSettings,
    this.styles = companionStyles,
  });

  final CompanionOverlay companion;
  final PatientSettings patientSettings;

  /// The companion styles to choose from.
  final List<CompanionStyle> styles;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String? _styleId;
  late final _patientId = TextEditingController(
    text: widget.patientSettings.patientId,
  );
  bool _savingPatient = false;
  String? _patientError;

  @override
  void initState() {
    super.initState();
    _loadStyle();
  }

  @override
  void dispose() {
    _patientId.dispose();
    super.dispose();
  }

  Future<void> _savePatientId({bool create = false}) async {
    if (_savingPatient) return;
    final editedId = _patientId.text.trim();
    if (!create && !isValidPatientId(editedId)) {
      setState(() {
        _patientError = 'Use 1–128 letters, digits, hyphens, or underscores.';
      });
      return;
    }
    setState(() {
      _savingPatient = true;
      _patientError = null;
    });
    try {
      final id = create ? await createPatient() : editedId;
      await widget.patientSettings.save(id);
      if (!mounted) return;
      _patientId.text = id;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient ID saved.')));
    } on PlatformException {
      if (mounted) setState(() => _patientError = 'Could not save patient ID.');
    } on MissingPluginException {
      if (mounted) {
        setState(() => _patientError = 'Patient settings require Android.');
      }
    } finally {
      if (mounted) setState(() => _savingPatient = false);
    }
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Patient ID',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _patientId,
                  decoration: InputDecoration(
                    hintText: 'Enter a patient ID',
                    errorText: _patientError,
                  ),
                  enabled: !_savingPatient,
                  autocorrect: false,
                  enableSuggestions: false,
                  onSubmitted: (_) => _savePatientId(),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton(
                      onPressed: _savingPatient ? null : _savePatientId,
                      child: const Text('Save patient ID'),
                    ),
                    OutlinedButton(
                      onPressed: _savingPatient
                          ? null
                          : () => _savePatientId(create: true),
                      child: const Text('Create patient'),
                    ),
                  ],
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
