class InAppConfig {
  final String siteId;

  InAppConfig({required this.siteId});

  Map<String, dynamic> toMap() {
    return {
      'siteId': siteId,
    };
  }
}
