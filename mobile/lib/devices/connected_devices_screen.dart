import 'dart:async';

import 'package:flutter/material.dart';

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
  });

  final Map<String, WearableAdapter> adapters;
  final Duration batchInterval;

  @override
  State<ConnectedDevicesScreen> createState() => _ConnectedDevicesScreenState();
}

class _ConnectedDevicesScreenState extends State<ConnectedDevicesScreen> {
  late final _batchBuffer = MetricBatchBuffer(interval: widget.batchInterval);
  StreamSubscription<WearableEvent>? _connection;
  WearableDevice? _device;
  bool _connected = false;
  bool _disconnecting = false;
  HeartRateSample? _latest;
  int _sampleCount = 0;
  String? _error;

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
                final batch = _batchBuffer.addHeartRate(
                  providerId: provider.id,
                  deviceId: device.id,
                  sample: event,
                );
                setState(() {
                  _latest = event;
                  _sampleCount = batch.sampleCount;
                });
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
      _device = null;
      _connected = false;
      _disconnecting = false;
      _latest = null;
      _sampleCount = 0;
      _error = error;
    });
  }

  @override
  void dispose() {
    unawaited(_connection?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final device = _device;
    final latest = _latest;
    return Scaffold(
      appBar: AppBar(title: const Text('Connected devices')),
      body: device == null
          ? Center(child: Text(_error ?? 'No connected devices'))
          : ListView(
              children: [
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
                    subtitle: Text('Samples in batch: $_sampleCount'),
                  ),
              ],
            ),
      floatingActionButton: device == null
          ? FloatingActionButton.extended(
              onPressed: _addDevice,
              icon: const Icon(Icons.add),
              label: const Text('Add device'),
            )
          : null,
    );
  }
}
