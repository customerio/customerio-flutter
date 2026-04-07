import 'package:flutter/material.dart';

/// AmiApp container makes it easier to host all widgets in [Scaffold] and
/// [SafeArea] conveniently. This should be the root widget of all pages.
class AppContainer extends StatelessWidget {
  const AppContainer({
    super.key,
    this.appBar,
    required this.body,
    this.resizeToAvoidBottomInset = true,
  });

  final PreferredSizeWidget? appBar;
  final Widget body;
  final bool resizeToAvoidBottomInset;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      resizeToAvoidBottomInset: resizeToAvoidBottomInset,
      appBar: appBar,
      body: SafeArea(
        child: body,
      ),
    );
  }
}
