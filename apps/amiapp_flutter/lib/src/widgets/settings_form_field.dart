import 'package:flutter/material.dart';

import '../components/text_field_label.dart';

class TextSettingsFormField extends StatelessWidget {
  const TextSettingsFormField({
    super.key,
    required this.labelText,
    required this.semanticsLabel,
    required this.valueController,
    this.hintText,
    this.readOnly = false,
    this.keyboardType = TextInputType.text,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.suffixIcon,
    this.validator,
  });

  final String labelText;
  final String semanticsLabel;
  final String? hintText;
  final bool readOnly;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final Widget? suffixIcon;
  final FormFieldValidator<String>? validator;
  final TextEditingController valueController;

  String? get nonEmptyValue {
    final text = valueController.text;
    if (text.isNotEmpty) {
      return text;
    } else {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final FloatingLabelBehavior? floatingLabelBehavior;
    if (hintText?.isNotEmpty == true) {
      floatingLabelBehavior = FloatingLabelBehavior.always;
    } else {
      floatingLabelBehavior = null;
    }

    return UnmanagedRestorationScope(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: TextFormField(
              controller: valueController,
              readOnly: readOnly,
              decoration: InputDecoration(
                border: const OutlineInputBorder(),
                label: TextFieldLabel(
                  text: labelText,
                  semanticsLabel: semanticsLabel,
                ),
                hintText: hintText,
                isDense: true,
                floatingLabelBehavior: floatingLabelBehavior,
              ),
              keyboardType: keyboardType,
              textCapitalization: textCapitalization,
              textInputAction: textInputAction,
              validator: validator,
            ),
          ),
        ],
      ),
    );
  }
}

class SwitchSettingsFormField extends StatelessWidget {
  const SwitchSettingsFormField({
    super.key,
    required this.labelText,
    required this.semanticsLabel,
    required this.value,
    required this.updateState,
    this.enabled = true,
  });

  final String labelText;
  final String semanticsLabel;
  final bool value;
  final void Function(bool) updateState;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return UnmanagedRestorationScope(
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              labelText,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Semantics(
            label: semanticsLabel,
            child: Switch(
              value: value,
              onChanged: (bool value) => updateState(value),
            ),
          ),
        ],
      ),
    );
  }
}
