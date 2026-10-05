import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Part P-006 scope: the one loading state every feature screen should
/// use instead of a raw [CircularProgressIndicator], centered by default
/// so callers never have to remember to wrap it in a [Center] themselves.
///
/// Part P-111: spinner uses the brand token. Where a skeleton is specified
/// (P-114), use `AppShimmerBox` instead of this spinner.
class LoadingIndicator extends StatelessWidget {
  const LoadingIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: CircularProgressIndicator(color: context.appColors.brand),
    );
  }
}
