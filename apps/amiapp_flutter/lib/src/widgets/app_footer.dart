import 'package:flutter/material.dart';

/// User agent widget to make it consistent app wide
class TextFooter extends StatelessWidget {
  const TextFooter({
    super.key,
    required this.text,
    this.paddingInsets = const EdgeInsets.fromLTRB(16.0, 0, 16.0, 32.0),
  });

  final EdgeInsetsGeometry paddingInsets;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: paddingInsets,
      child: Center(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
