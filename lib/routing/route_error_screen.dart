import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/l10n/l10n_context.dart';
import '../core/widgets/app_button.dart';
import 'route_names.dart';

/// Part P-112: the page the router shows for an address it does not know
/// (go_router's `errorBuilder`). Before this part the user saw go_router's
/// default English page. All texts come from the ARB files.
class RouteErrorScreen extends StatelessWidget {
  const RouteErrorScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.routeErrorTitle)),
      body: Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                l10n.routeErrorMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              AppButton(
                label: l10n.routeErrorGoHome,
                onPressed: () => context.go(RouteNames.homePath),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
