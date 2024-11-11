/// Extensions for [Map] class that provide additional functionality and convenience methods.
extension CustomerIOMapExtension on Map<String, dynamic> {
  /// Returns a new map with entries that have non-null values, excluding null values.
  Map<String, dynamic> excludeNullValues() {
    return Map.fromEntries(entries.where((entry) => entry.value != null));
  }
}
