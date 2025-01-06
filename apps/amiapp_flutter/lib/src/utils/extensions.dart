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

  String? nullIfEmpty() {
    return isEmpty ? null : this;
  }

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

  bool isEmptyOrValidUrl() {
    String url = trim();
    // Empty text is considered valid
    if (url.isEmpty) {
      return true;
    }
    // If the URL contains a scheme, it is considered invalid
    if (url.contains("://")) {
      return false;
    }
    // Ensure the URL is prefixed with "https://" so that it can be parsed
    final prefixedUrl = "https://$url";
    // If the URL is not parsable, it is considered invalid
    final Uri? uri = Uri.tryParse(prefixedUrl);
    if (uri == null) {
      return false;
    }

    // Check if the last character is alphanumeric
    final isLastCharValid = RegExp(r'[a-zA-Z0-9]$').hasMatch(url);

    // Check validity conditions:
    // - URL should not end with a slash
    // - URL should contain a domain (e.g., cdp.customer.io)
    // - URL should not contain a query or fragment
    return isLastCharValid &&
        uri.host.contains('.') &&
        uri.query.isEmpty &&
        uri.fragment.isEmpty;
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

  String capitalize() {
    return '${this[0].toUpperCase()}${substring(1)}';
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
    final RouteMatchList matchList = lastMatch is ImperativeRouteMatch
        ? lastMatch.matches
        : routerDelegate.currentConfiguration;
    return matchList.uri.toString();
  }
}
