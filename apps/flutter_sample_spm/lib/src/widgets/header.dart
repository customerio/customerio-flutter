// material_ui needs Flutter 3.47, this package supports 3.44.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

class TextSectionHeader extends StatelessWidget {
  const TextSectionHeader({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleLarge,
      ),
    );
  }
}
