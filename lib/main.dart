import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Part P-001 scope: skeleton only.
///
/// Wrapped in ProviderScope now - even though no providers exist yet -
/// so that later parts (P-010 onward) never have to retrofit Riverpod
/// into the widget tree. No routing, theming, networking, or storage
/// logic belongs here; that is explicitly out of scope for this part.
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
