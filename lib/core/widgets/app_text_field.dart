import 'package:flutter/material.dart';

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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(labelText: label),
    );
  }
}
