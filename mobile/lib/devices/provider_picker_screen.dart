import 'package:flutter/material.dart';

import 'provider_catalog.dart';

class ProviderPickerScreen extends StatefulWidget {
  const ProviderPickerScreen({super.key, required this.adapterIds});

  final Set<String> adapterIds;

  @override
  State<ProviderPickerScreen> createState() => _ProviderPickerScreenState();
}

class _ProviderPickerScreenState extends State<ProviderPickerScreen> {
  AssetBundle? _bundle;
  late Future<List<WearableProvider>> _providers;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final bundle = DefaultAssetBundle.of(context);
    if (bundle != _bundle) {
      _bundle = bundle;
      _providers = ProviderCatalog(bundle).load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add device')),
      body: FutureBuilder<List<WearableProvider>>(
        future: _providers,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return const Center(child: Text('Could not load providers'));
          }
          final providers = snapshot.data;
          if (providers == null) {
            return const Center(child: CircularProgressIndicator());
          }
          if (providers.isEmpty) {
            return const Center(child: Text('No providers available'));
          }
          return ListView.builder(
            itemCount: providers.length,
            itemBuilder: (context, index) {
              final provider = providers[index];
              return ListTile(
                key: ValueKey(provider.id),
                title: Text(provider.name),
                enabled: widget.adapterIds.contains(provider.id),
                onTap: () => Navigator.of(context).pop(provider),
              );
            },
          );
        },
      ),
    );
  }
}
