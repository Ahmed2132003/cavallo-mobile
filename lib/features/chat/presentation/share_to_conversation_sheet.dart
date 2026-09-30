import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/network/api_failure.dart';
import '../../../routing/route_names.dart';
import '../data/conversation_repository.dart';
import '../data/message_repository.dart';
import '../domain/conversation.dart';
import '../domain/shared_content.dart';

/// Part P-077 STEP 4 — the conversations offered as share targets.
///
/// Reuses `ConversationRepository.listConversations()` (P-074), first
/// page only (the backend currently answers a plain array, so there is
/// no second page). `autoDispose`, so the list is re-fetched every time
/// the picker is opened and never shows a stale conversation list.
final shareTargetConversationsProvider =
    FutureProvider.autoDispose<List<Conversation>>((ref) async {
      final page = await ref
          .watch(conversationRepositoryProvider)
          .listConversations();
      return page.results;
    });

/// Part P-077 STEP 4 — the two-option sheet behind every Share icon
/// (Post / Reel / Product):
///
/// - "Share via…" -> [onNativeShare], the caller's EXISTING share flow,
///   unchanged (for Post/Reel: share tracking + native share sheet).
/// - "Share to conversation" -> a conversation picker; picking a row
///   POSTs the shared reference via
///   `MessageRepository.sendSharedContentMessage`, then calls
///   [onSharedToConversation] (best-effort share tracking, its errors
///   are the caller's to swallow) and opens that conversation's thread.
///
/// The router and messenger are captured from [context] BEFORE the
/// sheets open, so navigation and error snackbars still work after the
/// sheets have been popped.
Future<void> showShareOptionsSheet(
  BuildContext context, {
  required SharedContentType contentType,
  required int objectId,
  required Future<void> Function() onNativeShare,
  Future<void> Function()? onSharedToConversation,
}) {
  final router = GoRouter.of(context);
  final messenger = ScaffoldMessenger.of(context);

  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) {
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('shareOption_native'),
              leading: const Icon(Icons.ios_share),
              title: const Text('Share via…'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                unawaited(onNativeShare());
              },
            ),
            ListTile(
              key: const ValueKey('shareOption_conversation'),
              leading: const Icon(Icons.chat_bubble_outline),
              title: const Text('Share to conversation'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                if (!context.mounted) return;
                unawaited(
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    showDragHandle: true,
                    builder: (_) => _ConversationPickerSheet(
                      contentType: contentType,
                      objectId: objectId,
                      router: router,
                      messenger: messenger,
                      onSent: onSharedToConversation,
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      );
    },
  );
}

class _ConversationPickerSheet extends ConsumerStatefulWidget {
  const _ConversationPickerSheet({
    required this.contentType,
    required this.objectId,
    required this.router,
    required this.messenger,
    required this.onSent,
  });

  final SharedContentType contentType;
  final int objectId;
  final GoRouter router;
  final ScaffoldMessengerState messenger;
  final Future<void> Function()? onSent;

  @override
  ConsumerState<_ConversationPickerSheet> createState() =>
      _ConversationPickerSheetState();
}

class _ConversationPickerSheetState
    extends ConsumerState<_ConversationPickerSheet> {
  /// The conversation currently being sent to (its row shows a spinner
  /// and every row ignores taps, so a double tap can't send twice).
  int? _sendingId;

  Future<void> _send(Conversation conversation) async {
    if (_sendingId != null) return;
    setState(() => _sendingId = conversation.id);

    // Captured up-front: this State is disposed once the sheet pops.
    final router = widget.router;
    final messenger = widget.messenger;
    final onSent = widget.onSent;

    try {
      await ref
          .read(messageRepositoryProvider)
          .sendSharedContentMessage(
            conversationId: conversation.id,
            contentType: widget.contentType,
            objectId: widget.objectId,
          );
    } catch (e) {
      if (!mounted) return;
      setState(() => _sendingId = null);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e is ApiFailure ? e.message : 'Could not share. Please try again.',
          ),
        ),
      );
      return;
    }

    if (!mounted) return;
    Navigator.of(context).pop();

    if (onSent != null) {
      try {
        await onSent();
      } catch (_) {
        // Tracking is best-effort: the message is already delivered.
      }
    }

    unawaited(
      router.pushNamed(
        RouteNames.chatThread,
        pathParameters: {RouteNames.idParam: conversation.id.toString()},
        extra: conversation,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(shareTargetConversationsProvider);
    final theme = Theme.of(context);

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.6,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              'Share to conversation',
              style: theme.textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: switch (async) {
              AsyncData(:final value) =>
                value.isEmpty
                    ? const Center(
                        key: ValueKey('sharePicker_empty'),
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No conversations yet.\n'
                            'Start one from the Messages tab first.',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: value.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, index) {
                          final conversation = value[index];
                          final name =
                              conversation.otherParticipant?.displayName ??
                              'Unknown';
                          return ListTile(
                            key: ValueKey(
                              'sharePicker_conversation_${conversation.id}',
                            ),
                            enabled: _sendingId == null,
                            onTap: () => _send(conversation),
                            leading: CircleAvatar(
                              child: Text(
                                name.isNotEmpty ? name[0].toUpperCase() : '?',
                              ),
                            ),
                            title: Text(name),
                            trailing: _sendingId == conversation.id
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : null,
                          );
                        },
                      ),
              AsyncError() => Center(
                key: const ValueKey('sharePicker_error'),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Could not load your conversations.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () =>
                          ref.invalidate(shareTargetConversationsProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              _ => const Center(child: CircularProgressIndicator()),
            },
          ),
        ],
      ),
    );
  }
}