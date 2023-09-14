import 'package:flutter/material.dart';

/// Full screen scroll view container to fill all remaining spaces on screen
/// and shows scroll thumb when needed
class FullScreenScrollView extends StatelessWidget {
  const FullScreenScrollView({
    super.key,
    required this.child,
    this.thumbVisibility = true,
    this.hasScrollBody = false,
  });

  final Widget child;
  final bool? thumbVisibility;
  final bool hasScrollBody;

  @override
  Widget build(BuildContext context) => Scrollbar(
        thumbVisibility: thumbVisibility,
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: hasScrollBody,
              child: child,
            ),
          ],
        ),
      );
}
