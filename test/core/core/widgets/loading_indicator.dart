import 'package:flutter/material.dart';

/// Part P-006 scope: the one loading state every feature screen should
/// use instead of a raw [CircularProgressIndicator], centered by default
/// so callers never have to remember to wrap it in a [Center] themselves.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(child: CircularProgressIndicator());
  }
}