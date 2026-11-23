// material_ui needs Flutter 3.47, this package supports 3.44.
// ignore: deprecated_member_use
import 'package:flutter/material.dart';

/// Text field label with semantic label for accessibility
/// If semantic label is not provided, it will use the text as semantic label
class TextFieldLabel extends StatelessWidget {
  final String text;
  final String? semanticsLabel;

  const TextFieldLabel({
    super.key,
    required this.text,
    this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) => Text.rich(
        TextSpan(
          children: <InlineSpan>[
            WidgetSpan(
              child: Text(
                text,
                semanticsLabel: semanticsLabel ?? text,
              ),
            ),
          ],
        ),
      );
}
