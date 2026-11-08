import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Part P-006 scope: the one text field every feature form should use
/// instead of a raw [TextFormField], so field styling (and any future
/// brand restyle) stays consistent across every form in the app.
///
/// Part P-111: the explicit `OutlineInputBorder` was removed. The look (filled
/// with the surfaceVariant token, 12 px radius, brand-coloured focus border,
/// danger-coloured error border) now comes from `inputDecorationTheme` in
/// AppTheme, so this widget carries no style of its own.
///
/// ### [maxLines] - added in Part P-028B, flagged (not silent)
///
/// P-006's original scope for this widget had no [maxLines] parameter
/// (single-line only). Part P-028B's own spec calls for "description
/// (multiline AppTextField)" on the business onboarding form. Adding one
/// small, backward-compatible optional parameter here (default `1`,
/// identical to every existing call site's behavior) was the smaller, more
/// consistent change.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
    this.maxLines = 1,
    this.inputFormatters,
    this.suffixIcon,
    this.textInputAction,
    this.onChanged,
  });

  /// Field label, shown as the [InputDecoration.labelText].
  final String label;

  final TextEditingController controller;

  /// Standard [FormFieldValidator] hook. Only takes effect when this
  /// field is wrapped in a [Form] and `formKey.currentState!.validate()`
  /// is called - return `null` when the value is valid, or an error
  /// string to show beneath the field otherwise.
  final String? Function(String?)? validator;

  /// True for password-style fields that should mask input.
  final bool obscureText;

  final TextInputType? keyboardType;

  /// Number of visible text lines. Defaults to `1`. Pass a value greater
  /// than `1` for a multiline field - mirrors [TextFormField.maxLines].
  final int maxLines;

  /// Optional input filters (for example digits only plus a length cap for a
  /// verification code). Added with the forgot-password screens; `null`
  /// (default) keeps every existing call site unchanged.
  final List<TextInputFormatter>? inputFormatters;

  /// Optional trailing widget inside the field, for example a show/hide
  /// password button. Added with the forgot-password screens; `null`
  /// (default) keeps every existing call site unchanged.
  final Widget? suffixIcon;

  final TextInputAction? textInputAction;

  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      inputFormatters: inputFormatters,
      textInputAction: textInputAction,
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, suffixIcon: suffixIcon),
    );
  }
}
