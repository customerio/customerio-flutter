import 'package:amiapp_flutter/src/utils/extensions.dart';
import 'package:customer_io/customer_io_plugin_version.dart'
    as customer_io_plugin_version;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:package_info_plus/package_info_plus.dart';

class BuildInfoMetadata {
  late final String sdkVersion;
  late final String appVersion;
  late final String buildDate;
  late final String gitMetadata;
  late final String defaultWorkspace;
  late final String language;
  late final String uiFramework;
  late final String sdkIntegration;

  BuildInfoMetadata(PackageInfo packageInfo) {
    final env = dotenv.env;

    sdkVersion = resolveValidOrElse(env['SDK_VERSION'], () {
      return '${customer_io_plugin_version.version}-${resolveValidOrElse(env['COMMITS_AHEAD_COUNT'], () => "as-source")}';
    });
    appVersion = resolveValidOrElse(packageInfo.version);

    final buildTimestamp = env['BUILD_TIMESTAMP']?.toIntOrNull();
    buildDate = buildTimestamp == null
        ? "unavailable"
        : formatBuildDateWithRelativeTime(buildTimestamp);

    final branchName =
        resolveValidOrElse(env['BRANCH_NAME'], () => "development build");
    final commitHash =
        resolveValidOrElse(env['COMMIT_HASH'], () => "untracked");
    gitMetadata = "$branchName-$commitHash";

    defaultWorkspace = resolveValidOrElse(env['WORKSPACE_NAME']);
    language = "Dart";
    uiFramework = "Flutter";
    sdkIntegration = "Flutter Package Manager (pub.dev)";
  }

  @override
  String toString() {
    return '''
    SDK Version: $sdkVersion\tApp Version: $appVersion
    Build Date: $buildDate
    Branch: $gitMetadata
    Default Workspace: $defaultWorkspace
    Language: $language\tUI Framework: $uiFramework
    SDK Integration: $sdkIntegration
    ''';
  }

  static String resolveValidOrElse(String? text,
      [String Function()? fallback]) {
    if (text == null || text.isEmpty || text.equalsIgnoreCase("null")) {
      return fallback?.call() ?? "unknown";
    }
    return text;
  }

  static String formatBuildDateWithRelativeTime(int timestamp) {
    final buildDate = DateTime.fromMillisecondsSinceEpoch(timestamp * 1000);
    final now = DateTime.now();
    final formattedDate = '${buildDate.toLocal()}'.split('.')[0];

    final daysAgo = now.difference(buildDate).inDays;
    final relativeTime = (daysAgo == 0) ? "(Today)" : "($daysAgo days ago)";

    return "$formattedDate $relativeTime";
  }
}
