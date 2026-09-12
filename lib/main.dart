import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config/app_theme.dart';
import 'routing/app_router.dart';

/// Composition root for the app.
///
/// Wrapped in ProviderScope since P-001. [AppTheme] was applied app-wide
/// in P-006. As of P-007, navigation goes through the single [GoRouter]
/// instance exposed by [appRouterProvider] — [SocialCommerceApp] is now a
/// [ConsumerWidget] so it can watch that provider and pass it to
/// [MaterialApp.router]. No feature should build a separate `Navigator`.
void main() {
  runApp(const ProviderScope(child: SocialCommerceApp()));
}

class SocialCommerceApp extends ConsumerWidget {
  const SocialCommerceApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);

    return MaterialApp.router(
      title: 'Social Commerce Discovery Platform',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.theme,
      routerConfig: router,
    );
  }
}