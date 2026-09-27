import 'package:flutter/material.dart';

/// Part P-006 scope: the one text field every feature form should use
/// instead of a raw [TextFormField], so field styling (and any future
/// brand restyle) stays consistent across every form in the app.
///
/// ### [maxLines] — added in Part P-028B, flagged (not silent)
///
/// P-006's original scope for this widget had no [maxLines] parameter
/// (single-line only). Part P-028B's own spec calls for "description
/// (multiline AppTextField)" on the business onboarding form, and this
/// project's convention (P-006's own handoff note) is that every feature
/// form uses [AppTextField] instead of a raw [TextFormField] — so a raw
/// multiline `TextFormField` inside `business_onboarding_screen.dart`
/// would itself be the kind of deviation this project's convention asks
/// to flag. Adding one small, backward-compatible optional parameter
/// here (default `1`, identical to every existing call site's current
/// behavior) was the smaller, more consistent change. No existing call
/// site (`LoginScreen`, `RegisterScreen`) is affected — none of them
/// pass this parameter, so they keep their exact previous behavior.
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
  /// is called — return `null` when the value is valid, or an error
  /// string to show beneath the field otherwise.
  final String? Function(String?)? validator;

  /// True for password-style fields that should mask input.
  final bool obscureText;

  final TextInputType? keyboardType;

  /// Number of visible text lines. Defaults to `1` (every pre-existing
  /// call site's exact previous behavior — see this class's docstring).
  /// Pass a value greater than `1` for a multiline field (e.g. a
  /// description/notes field) — mirrors [TextFormField.maxLines]
  /// directly, with no extra behavior layered on top.
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}