import 'dart:async';

import 'package:flutter/material.dart';

import '../wearables/wearable_adapter.dart';
import 'provider_catalog.dart';

class DeviceScanScreen extends StatefulWidget {
  const DeviceScanScreen({
    super.key,
    required this.provider,
    required this.adapter,
  });

  final WearableProvider provider;
  final WearableAdapter adapter;

  @override
  State<DeviceScanScreen> createState() => _DeviceScanScreenState();
}

class _DeviceScanScreenState extends State<DeviceScanScreen> {
  final _devices = <String, WearableDevice>{};
  StreamSubscription<WearableDevice>? _scan;
  bool _scanning = false;
  bool _hasScanned = false;
  bool _selecting = false;
  String? _error;

  void _startScan() {
    if (_scanning || _selecting) return;
    setState(() {
      _devices.clear();
      _scanning = true;
      _hasScanned = true;
      _error = null;
    });
    _scan = widget.adapter.scan().listen(
      (device) {
        if (mounted) setState(() => _devices[device.id] = device);
      },
      onError: (Object error) => _stopScan(
        error is WearableException ? error.message : 'Bluetooth scan failed.',
      ),
      onDone: _stopScan,
      cancelOnError: true,
    );
  }

  void _stopScan([String? error]) {
    if (!mounted) return;
    setState(() {
      _scanning = false;
      _scan = null;
      _error = error;
    });
  }

  Future<void> _select(WearableDevice device) async {
    if (_selecting) return;
    setState(() => _selecting = true);
    try {
      await _scan?.cancel();
    } catch (_) {
      if (!mounted) return;
      _stopScan('Could not stop scanning. Scan again to select a device.');
      setState(() => _selecting = false);
      return;
    }
    if (mounted) Navigator.of(context).pop(device);
  }

  @override
  void dispose() {
    unawaited(_scan?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final steps = widget.adapter.setupSteps;
    final scanLabel = _hasScanned
        ? 'Scan again'
        : 'Scan for ${widget.provider.name}';
    return Scaffold(
      appBar: AppBar(title: Text('Find ${widget.provider.name}')),
      body: ListView(
        children: [
          for (final (index, step) in steps.indexed)
            ListTile(leading: Text('${index + 1}.'), title: Text(step)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: FilledButton(
              onPressed: _scanning || _selecting ? null : _startScan,
              child: Text(_scanning ? 'Scanning…' : scanLabel),
            ),
          ),
          if (_scanning) const LinearProgressIndicator(),
          if (_error case final error?) ListTile(title: Text(error)),
          if (_hasScanned && !_scanning && _error == null && _devices.isEmpty)
            const ListTile(title: Text('No devices found')),
          for (final device in _devices.values)
            ListTile(
              title: Text(device.name),
              enabled: !_selecting,
              onTap: () => _select(device),
            ),
        ],
      ),
    );
  }
}
