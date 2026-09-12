import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_button.dart';
import '../../../routing/route_names.dart';

/// Placeholder screen for the `chatList` route (Part P-007 — routing
/// skeleton only). Navigates to a sample `chatThread/:id` to prove the
/// parameterized route resolves correctly.
class ChatListScreen extends StatelessWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('chatList')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Route: chatList'),
            const SizedBox(height: 16),
            AppButton(
              label: 'Open sample chat thread',
              onPressed: () => context.goNamed(
                RouteNames.chatThread,
                pathParameters: const {RouteNames.idParam: 'sample-thread-1'},
              ),
            ),
          ],
        ),
      ),
    );
  }
}
