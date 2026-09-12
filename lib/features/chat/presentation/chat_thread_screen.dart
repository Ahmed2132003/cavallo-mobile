import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `chatThread` route (`/chat/:id`) (Part P-007
/// — routing skeleton only). Displays the received [chatId] to prove the
/// `:id` path parameter is wired correctly.
class ChatThreadScreen extends StatelessWidget {
  const ChatThreadScreen({super.key, required this.chatId});

  /// The `:id` path parameter from the matched `/chat/:id` route.
  final String chatId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('chatThread')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: chatThread'),
            Text('id param: $chatId'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Go to notifications',
              onPressed: () => context.goNamed(RouteNames.notifications),
            ),
          ],
        ),
      ),
    );
  }
}
