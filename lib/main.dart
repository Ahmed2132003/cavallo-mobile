import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_theme.dart';

/// Composition root for the app.
///
/// Wrapped in ProviderScope since P-001 — even though no providers exist
/// yet — so that later parts (P-010 onward) never have to retrofit
/// Riverpod into the widget tree. [AppTheme] was applied app-wide in
/// P-006. Routing, networking, and storage wiring are still out of
/// scope here and land in their own later parts.
void main() {
  runApp(const ProviderScope(child: SocialCommerceApp()));
}

class SocialCommerceApp extends StatelessWidget {
  const SocialCommerceApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Social Commerce Discovery Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      home: const _PlaceholderHome(),
    );
  }
}

class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text(
          'Social Commerce Discovery Platform',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}