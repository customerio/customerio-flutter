import 'package:flutter/material.dart';

import '../components/text_field_label.dart';
import '../utils/extensions.dart';

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
                hintStyle: TextStyle(
                  color: Theme.of(context).colorScheme.outline,
                ),
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

class ChoiceSettingsFormField<T> extends StatelessWidget {
  const ChoiceSettingsFormField({
    super.key,
    required this.labelText,
    required this.semanticsLabel,
    required this.value,
    required this.updateState,
    required this.options,
    this.enabled = true,
  });

  final String labelText;
  final String semanticsLabel;
  final T value;
  final List<T> options;
  final void Function(T) updateState;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    const double defaultBorderRadius = 8.0;

    return UnmanagedRestorationScope(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            labelText,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 12),
          Container(
            decoration: BoxDecoration(
              color: enabled
                  ? Theme.of(context).colorScheme.surface
                  : Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(defaultBorderRadius),
            ),
            child: Row(
              children: options.map((option) {
                final bool isSelected = option == value;
                return Expanded(
                  child: GestureDetector(
                    onTap: enabled
                        ? () {
                            updateState(option);
                          }
                        : null,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Theme.of(context).colorScheme.primary
                            : Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                        borderRadius: BorderRadius.only(
                          topLeft: option == options.first
                              ? const Radius.circular(defaultBorderRadius)
                              : Radius.zero,
                          bottomLeft: option == options.first
                              ? const Radius.circular(defaultBorderRadius)
                              : Radius.zero,
                          topRight: option == options.last
                              ? const Radius.circular(defaultBorderRadius)
                              : Radius.zero,
                          bottomRight: option == options.last
                              ? const Radius.circular(defaultBorderRadius)
                              : Radius.zero,
                        ),
                      ),
                      child: Text(
                        option.toString().split('.').last.capitalize(),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: isSelected
                                  ? Theme.of(context).colorScheme.onPrimary
                                  : Theme.of(context).colorScheme.onSurface,
                            ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}
