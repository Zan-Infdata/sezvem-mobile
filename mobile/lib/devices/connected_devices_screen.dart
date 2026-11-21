import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../companion/companion_overlay.dart';
import '../companion/companion_wander_test.dart';
import '../settings/patient_settings.dart';
import '../settings/settings_screen.dart';
import '../sync/telemetry_api.dart';
import '../wearables/metric_batch_buffer.dart';
import '../wearables/wearable_adapter.dart';
import 'device_scan_screen.dart';
import 'provider_catalog.dart';
import 'provider_picker_screen.dart';

class ConnectedDevicesScreen extends StatefulWidget {
  const ConnectedDevicesScreen({
    super.key,
    required this.adapters,
    required this.batchInterval,
    required this.patientSettings,
    this.companion = const AndroidCompanionOverlay(),
    this.telemetryApi,
  });

  final Map<String, WearableAdapter> adapters;
  final Duration batchInterval;
  final PatientSettings patientSettings;
  final CompanionOverlay companion;
  final TelemetryApi? telemetryApi;

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  late final _batchBuffer = MetricBatchBuffer(
    interval: widget.batchInterval,
    firstBatchNumber: widget.telemetryApi == null
        ? 1
        : DateTime.now().microsecondsSinceEpoch,
  );
  late Timer _batchTimer;
  StreamSubscription<WearableEvent>? _connection;
  String? _providerId;
  WearableDevice? _device;
  bool _connected = false;
  bool _disconnecting = false;
  HeartRateSample? _latest;
  String? _error;
  String? _batchJson;
  String? _batchUploadStatus;
  bool _debugJam = false;
  late final _companionWander = CompanionWanderTest(
    companion: widget.companion,
  );
  late final AppLifecycleListener _companionLifecycle;

  @override
  void initState() {
    super.initState();
    widget.patientSettings.addListener(_assignUnassignedReadings);
    // Moves the companion around while the app is in the background.
    _companionLifecycle = AppLifecycleListener(
      onHide: _companionWander.start,
      onShow: _companionWander.stop,
    );
    final now = DateTime.now().toUtc();
    final next = _batchBuffer.windowStart(now).add(_batchBuffer.interval);
    _batchTimer = Timer(next.difference(now), () {
      _batchTimer = Timer.periodic(
        _batchBuffer.interval,
        (_) => unawaited(_flushBatches()),
      );
      unawaited(_flushBatches());
    });
  }

  void _assignUnassignedReadings() {
    final patientId = widget.patientSettings.patientId;
    if (patientId != null) _batchBuffer.assignUnassignedReadings(patientId);
  }

  Future<void> _flushBatches() async {
    await _batchBuffer.flushReady(
      now: DateTime.now().toUtc(),
      send: _sendBatch,
    );
    if (mounted) setState(() {});
  }

  Future<bool> _sendBatch(Map<String, Object?> payload) async {
    if (!mounted) return false;
    final api = widget.telemetryApi;
    final body = api?.payloadFor(payload) ?? payload;
    final jammed = _debugJam;
    setState(() {
      _batchJson = const JsonEncoder.withIndent('  ').convert(body);
      _batchUploadStatus = jammed
          ? 'Debug jam active. Batch kept.'
          : api == null
          ? 'Debug preview.'
          : 'Sending…';
    });
    if (jammed) return false;
    if (api == null) return true;
    try {
      final result = await api.send(body);
      if (mounted) setState(() => _batchUploadStatus = result.status);
      return result.accepted;
    } on TelemetryDeliveryUncertain catch (error) {
      if (mounted) setState(() => _batchUploadStatus = error.message);
      rethrow;
    }
  }

  Future<void> _addDevice() async {
    final provider = await Navigator.of(context).push(
      MaterialPageRoute<WearableProvider>(
        builder: (_) =>
            ProviderPickerScreen(adapterIds: widget.adapters.keys.toSet()),
      ),
    );
    if (!mounted || provider == null) return;
    final adapter = widget.adapters[provider.id];
    if (adapter == null) return;
    final device = await Navigator.of(context).push(
      MaterialPageRoute<WearableDevice>(
        builder: (_) => DeviceScanScreen(provider: provider, adapter: adapter),
      ),
    );
    if (!mounted || device == null) return;

    setState(() {
      _providerId = provider.id;
      _device = device;
      _error = null;
    });
    _connection = adapter
        .connect(device)
        .listen(
          (event) {
            if (!mounted) return;
            switch (event) {
              case WearableConnected():
                setState(() => _connected = true);
              case HeartRateSample():
                _batchBuffer.addHeartRate(
                  patientId: widget.patientSettings.patientId,
                  providerId: provider.id,
                  deviceId: device.id,
                  sample: event,
                );
                setState(() => _latest = event);
            }
          },
          onError: (Object error) => _endConnection(
            error is WearableException
                ? error.message
                : 'Device connection failed.',
          ),
          onDone: () => _endConnection('Device connection ended.'),
          cancelOnError: true,
        );
  }

  Future<void> _testCompanion() async {
    final companion = widget.companion;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final allowed =
          await companion.hasPermission() ||
          await companion.requestPermission();
      if (!allowed) {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Allow IXLand to display over other apps to test the companion.',
            ),
          ),
        );
        return;
      }
      await companion.show();
      await companion.minimizeApp();
    } on PlatformException {
      messenger.showSnackBar(
        const SnackBar(content: Text('Could not show the companion.')),
      );
    }
  }

  Future<void> _disconnect() async {
    setState(() => _disconnecting = true);
    try {
      await _connection?.cancel();
      _endConnection();
    } catch (_) {
      _endConnection('Could not close the device connection.');
    }
  }

  void _endConnection([String? error]) {
    if (!mounted || _device == null) return;
    setState(() {
      _connection = null;
      _providerId = null;
      _device = null;
      _connected = false;
      _disconnecting = false;
      _latest = null;
      _error = error;
    });
  }

  @override
  void dispose() {
    widget.patientSettings.removeListener(_assignUnassignedReadings);
    _companionLifecycle.dispose();
    _companionWander.stop();
    _batchTimer.cancel();
    unawaited(_connection?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final providerId = _providerId;
    final latest = _latest;
    final batchJson = _batchJson;
    final pendingSamples = providerId == null || device == null
        ? 0
        : _batchBuffer.pendingSampleCount(
            providerId: providerId,
            deviceId: device.id,
          );
    return Scaffold(
      appBar: AppBar(
        title: const Text('Connected devices'),
        actions: [
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SettingsScreen(
                  companion: widget.companion,
                  patientSettings: widget.patientSettings,
                ),
              ),
            ),
          ),
        ],
      ),
      body: device == null && batchJson == null
          ? Center(child: Text(_error ?? 'No connected devices'))
          : ListView(
              padding: const EdgeInsets.only(bottom: 80),
              children: [
                if (device == null)
                  ListTile(title: Text(_error ?? 'No connected devices'))
                else
                  ListTile(
                    title: Text(device.name),
                    subtitle: Text(_connected ? 'Connected' : 'Connecting…'),
                    trailing: TextButton(
                      onPressed: _disconnecting ? null : _disconnect,
                      child: Text(_connected ? 'Disconnect' : 'Cancel'),
                    ),
                  ),
                if (_connected)
                  ListTile(
                    title: Text(
                      latest == null
                          ? 'Waiting for heart rate'
                          : '${latest.bpm} bpm',
                    ),
                    subtitle: Text('Samples in batch: $pendingSamples'),
                  ),
                if (batchJson != null) ...[
                  ExpansionTile(
                    title: const Text('Batch JSON (debug)'),
                    subtitle: _batchUploadStatus == null
                        ? null
                        : Text(_batchUploadStatus!),
                    initiallyExpanded: true,
                    childrenPadding: const EdgeInsets.all(16),
                    expandedAlignment: Alignment.centerLeft,
                    children: [
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 240),
                        child: SingleChildScrollView(
                          primary: false,
                          child: SelectableText(
                            batchJson,
                            style: const TextStyle(fontFamily: 'monospace'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  CheckboxListTile(
                    title: const Text('Debug jam'),
                    subtitle: const Text('Simulate an unavailable API'),
                    value: _debugJam,
                    onChanged: (value) {
                      setState(() => _debugJam = value ?? false);
                    },
                  ),
                ],
              ],
            ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (device == null) ...[
            FloatingActionButton.extended(
              heroTag: 'add_device',
              onPressed: _addDevice,
              icon: const Icon(Icons.add),
              label: const Text('Add device'),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'test_companion',
            onPressed: _testCompanion,
            icon: const Icon(Icons.pets),
            label: const Text('TEST'),
          ),
        ],
      ),
    );
  }
}
