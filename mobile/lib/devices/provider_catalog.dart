import 'dart:convert';

import 'package:flutter/services.dart';

class WearableProvider {
  const WearableProvider({required this.id, required this.name});

  factory WearableProvider.fromJson(Object? json) {
    if (json case {
      'id': final String id,
      'name': final String name,
    } when id.trim().isNotEmpty && name.trim().isNotEmpty) {
      return WearableProvider(id: id, name: name);
    }
    throw const FormatException('Expected a provider with an ID and name.');
  }

  final String id;
  final String name;
}

class ProviderCatalog {
  const ProviderCatalog(this._bundle);

  static const assetPath = 'assets/providers.json';

  final AssetBundle _bundle;

  Future<List<WearableProvider>> load() async {
    final json = jsonDecode(await _bundle.loadString(assetPath));
    if (json is! List<dynamic>) {
      throw const FormatException('Expected a list of providers.');
    }
    return json.map(WearableProvider.fromJson).toList(growable: false);
  }
}
