import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

extension AmiAppExtensions on BuildContext {
  void showSnackBar(String text) {
    ScaffoldMessenger.of(this).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> showMessageDialog(String title, String message,
      {List<Widget>? actions, bool barrierDismissible = true}) {
    List<Widget> actionWidgets = actions ??
        [
          TextButton(
            child: const Text('OK'),
            onPressed: () => Navigator.of(this).pop(),
          ),
        ];
    return showDialog<void>(
      context: this,
      barrierDismissible: barrierDismissible,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: actionWidgets,
        );
      },
    );
  }
}

extension AmiAppStringExtensions on String {
  bool equalsIgnoreCase(String? other) => toLowerCase() == other?.toLowerCase();

  int? toIntOrNull() {
    if (isNotEmpty) {
      return int.tryParse(this);
    } else {
      return null;
    }
  }

  double? toDoubleOrNull() {
    if (isNotEmpty) {
      return double.tryParse(this);
    } else {
      return null;
    }
  }

  bool? toBoolOrNull() {
    if (equalsIgnoreCase('true')) {
      return true;
    } else if (equalsIgnoreCase('false')) {
      return false;
    } else {
      return null;
    }
  }

  bool isValidUrl() {
    String url = trim();
    // Empty text is not considered valid.
    if (url.isEmpty) {
      return false;
    }

    // Currently only Android fails on URLs with empty host, still adding
    // validation for all platforms to keep it consistent for app users
    final Uri? uri = Uri.tryParse(url);
    if (uri == null) {
      return false;
    }
    // Valid URL with a host and http/https scheme
    return uri.hasAuthority &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.path.endsWith("/");
  }

  bool isValidInt({int? min, int? max}) {
    int? value = trim().toIntOrNull();
    return value != null &&
        (min == null || value >= min) &&
        (max == null || value <= max);
  }

  bool isValidDouble({double? min, double? max}) {
    double? value = trim().toDoubleOrNull();
    return value != null &&
        (min == null || value >= min) &&
        (max == null || value <= max);
  }
}

extension AmiAppDoubleExtensions on double {
  String? toTrimmedString() {
    if (this % 1.0 != 0.0) {
      return toString();
    }
    return toStringAsFixed(0);
  }
}

extension LocationExtensions on GoRouter {
  // Get location of current route
  // This is a workaround to get the current location as location property
  // was removed from GoRouter in v9.0.0
  // See migration guide:
  // https://flutter.dev/go/go-router-v9-breaking-changes
  String currentLocation() {
    final RouteMatch lastMatch = routerDelegate.currentConfiguration.last;
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch ? lastMatch.matches : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}