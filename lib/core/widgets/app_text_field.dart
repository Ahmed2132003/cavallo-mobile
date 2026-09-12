import 'package:flutter/material.dart';

/// Part P-006 scope: the one text field every feature form should use
/// instead of a raw [TextFormField], so field styling (and any future
/// brand restyle) stays consistent across every form in the app.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.obscureText = false,
    this.keyboardType,
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

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      obscureText: obscureText,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}