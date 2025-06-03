import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class InlineInAppMessageView extends StatelessWidget {
  final String? elementId;
  final double height;

  const InlineInAppMessageView({Key? key, this.elementId, this.height = 100}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return SizedBox(
        height: height,
        child: AndroidView(
          viewType: 'inline_in_app_message_view',
          creationParams: elementId != null ? {'elementId': elementId} : null,
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }
    return const Text('InlineInAppMessageView is only available on Android.');
  }
} 