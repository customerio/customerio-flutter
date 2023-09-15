import 'package:flutter/material.dart';

@immutable
class Sizes extends ThemeExtension<Sizes> {
  final double buttonHeightDefault;
  final double inputFieldWidthMax;

  const Sizes({
    required this.buttonHeightDefault,
    required this.inputFieldWidthMax,
  });

  @override
  ThemeExtension<Sizes> copyWith({
    double? buttonHeightDefault,
    double? inputFieldWidthMax,
  }) {
    return Sizes(
      buttonHeightDefault: buttonHeightDefault ?? this.buttonHeightDefault,
      inputFieldWidthMax: inputFieldWidthMax ?? this.inputFieldWidthMax,
    );
  }

  @override
  ThemeExtension<Sizes> lerp(ThemeExtension<Sizes>? other, double t) {
    if (other is! Sizes) {
      return this;
    }

    return Sizes(
      buttonHeightDefault: other.buttonHeightDefault,
      inputFieldWidthMax: other.inputFieldWidthMax,
    );
  }

  const Sizes.defaults()
      : buttonHeightDefault = 40.0,
        inputFieldWidthMax = 600.0;
}

extension UISizes on Sizes {
  Size buttonDefault() => Size(double.infinity, buttonHeightDefault);

  Size inputFieldDefault() => Size(inputFieldWidthMax, double.infinity);
}
