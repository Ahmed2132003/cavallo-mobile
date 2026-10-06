import 'package:flutter/material.dart';

/// TEMPORARY (P-113 STEP 1 fix): empty placeholder so the `saved` route
/// exists and the reachability test can pass. P-113 STEP 3 replaces this
/// file with the real Saved screen (Posts / Reels / Products tabs).
class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: SizedBox.shrink());
}