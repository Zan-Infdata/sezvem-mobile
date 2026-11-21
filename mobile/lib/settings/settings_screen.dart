import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companion/companion_animator.dart';
import '../companion/companion_character.dart';
import '../companion/companion_overlay.dart';
import '../companion/companion_state.dart';
import '../companion/styles/companion_look.dart';
import '../companion/styles/companion_style.dart';
import '../companion/styles/companion_styles.dart';
import '../debug/simulated_night_screen.dart';
import '../sync/patient_api.dart';
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
  CompanionLook? _look;
  late final _patientId = TextEditingController(
    text: widget.patientSettings.patientId,
  );
  bool _savingPatient = false;
  String? _patientError;

  @override
  void initState() {
    super.initState();
    _loadLook();
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
      final settings = widget.patientSettings;
      final id = create ? await settings.createPatient() : editedId;
      if (!create) await settings.save(id);
      if (!mounted) return;
      _patientId.text = id;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(create ? 'Patient created.' : 'Patient ID saved.'),
        ),
      );
    } on PatientCreationException catch (error) {
      if (mounted) setState(() => _patientError = error.message);
    } on PlatformException {
      if (mounted) {
        setState(() {
          _patientError = create
              ? 'Patient created. Tap Create patient again to retry saving.'
              : 'Could not save patient ID.';
        });
      }
    } on MissingPluginException {
      if (mounted) {
        setState(() => _patientError = 'Patient settings require Android.');
      }
    } finally {
      if (mounted) setState(() => _savingPatient = false);
    }
  }

  Future<void> _loadLook() async {
    var saved = const CompanionLook();
    try {
      saved = await widget.companion.look();
    } on PlatformException {
      // Fall back to the default look.
    }
    if (!mounted) return;
    setState(() => _look = saved);
  }

  Future<void> _saveLook(CompanionLook look) async {
    final previous = _look;
    if (previous == null || look == previous) return;
    setState(() => _look = look);
    try {
      await widget.companion.setLook(look);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _look = previous);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save the companion style.')),
      );
    }
  }

  /// [style] with the choices saved for it.
  CompanionStyle _customized(CompanionStyle style) =>
      style.customize(_look?.choices[style.id] ?? const {});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final look = _look;
    final selected = look?.resolve(widget.styles);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        actions: [
          if (kDebugMode)
            IconButton(
              tooltip: 'Replay simulated night',
              icon: const Icon(Icons.bedtime_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const SimulatedNightScreen(),
                ),
              ),
            ),
        ],
      ),
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
          if (look == null || selected == null)
            const Center(child: CircularProgressIndicator())
          else ...[
            RadioGroup<String>(
              groupValue: selected.id,
              onChanged: (id) {
                if (id != null) _saveLook(look.withStyle(id));
              },
              child: Column(
                children: [
                  for (final style in widget.styles)
                    RadioListTile<String>(
                      value: style.id,
                      title: Text(style.name),
                      secondary: SizedBox.square(
                        dimension: 56,
                        child: CompanionStylePreview(style: _customized(style)),
                      ),
                    ),
                ],
              ),
            ),
            for (final slot in selected.slots) ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(slot.name, style: theme.textTheme.titleSmall),
              ),
              SizedBox(
                height: 112,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: slot.options.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, index) {
                    final option = slot.options[index];
                    return _OptionTile(
                      label: option.name,
                      selected: selected.choices[slot.id] == option.id,
                      preview: selected.customize({
                        ...selected.choices,
                        slot.id: option.id,
                      }),
                      onTap: () => _saveLook(
                        look.withChoice(selected.id, slot.id, option.id),
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
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
                      onPressed:
                          _savingPatient ||
                              !widget.patientSettings.canCreatePatient
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
    // The character fills a window of the resting size. Scale it to fit.
    return FittedBox(
      child: SizedBox.fromSize(
        size: CompanionStyle.onScreen(CompanionStyle.restSize),
        child: CompanionCharacter(animator: _animator, style: widget.style),
      ),
    );
  }
}

/// One customization option with a preview of the companion wearing it.
class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.selected,
    required this.preview,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final CompanionStyle preview;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 88,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: selected ? colors.primaryContainer : null,
            border: Border.all(
              color: selected ? colors.primary : colors.outlineVariant,
              width: selected ? 2 : 1,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: [
              SizedBox.square(
                dimension: 56,
                child: CompanionStylePreview(style: preview),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
