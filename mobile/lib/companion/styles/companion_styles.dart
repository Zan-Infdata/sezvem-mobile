import 'classic_style.dart';
import 'companion_style.dart';

/// Every companion style, in the order settings lists them. The first one is
/// the default.
const companionStyles = <CompanionStyle>[ClassicCompanionStyle()];

/// The style saved as [id] in [styles], or the first style for an unknown or
/// missing ID.
CompanionStyle companionStyleById(
  String? id, [
  List<CompanionStyle> styles = companionStyles,
]) => styles.firstWhere((style) => style.id == id, orElse: () => styles.first);
