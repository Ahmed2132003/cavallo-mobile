import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_failure.dart';
import '../data/message_repository.dart';
import '../domain/message.dart';

/// Part P-075 STEP 1 — the client-side outbound retry queue for chat's
/// REST send call (`MessageRepository.sendMessage`).
///
/// Directly mirrors `StoryUploadQueueNotifier` (P-051,
/// `lib/features/stories/presentation/story_upload_queue_provider.dart`):
/// same attempt counter, same exponential-backoff schedule, same
/// injectable backoff for tests, same manual-retry-resets-the-counter
/// behavior. Differences are deliberate and listed below.
///
/// ### Why this exists (distinct from P-073)
/// P-073 is about the WebSocket connection's own reliability. This is
/// about the REST call itself: P-068's persistence-first guarantee only
/// begins once the POST actually reaches the server. If the device has
/// no connectivity, that POST never happens — this queue retries it
/// instead of losing the message or making the user notice and resend.
///
/// ### DEVIATION FROM P-051 — what counts as retryable
/// P-051's code retries everything except `ValidationFailure`. P-075's
/// spec says only NETWORK-type failures are retried, and validation /
/// permission errors must fail immediately. `AuthFailure` covers both
/// 401 and 403 in this codebase (see `api_failure.dart`), and a 5xx is
/// not "the message never reached the server" in the sense this part
/// exists for. So here ONLY [NetworkFailure] is retried; every other
/// [ApiFailure] (and any unexpected exception) goes straight to
/// [OutboundMessageStatus.failed] with the manual retry affordance.
///
/// ### Backoff schedule
/// Attempt 1 fires immediately. After a retryable failure of attempt N,
/// wait `_delays[N - 1]` before attempt N + 1 — 2s/4s/8s/16s before
/// attempts 2/3/4/5. The 32s entry is unreachable at `_maxAttempts = 5`
/// (kept so raising the cap needs no change here), same reading P-051
/// chose.
///
/// ### Scope
/// In-memory only. Surviving a full app kill/restart is explicitly out
/// of scope (same MVP boundary as P-051). No cancel of an in-flight
/// request: `MessageRepository.sendMessage` takes no `CancelToken`.
///
/// ### Known limitations (documented, not silently skipped)
/// - No idempotency key exists on the backend: if a request reaches the
///   server but the response is lost, a retry can create a duplicate.
/// - Each queued message retries independently, so under repeated
///   failures the server-side order of two queued messages is not
///   strictly guaranteed to match the order they were typed in.

/// Lifecycle of one queued outbound message.
enum OutboundMessageStatus {
  /// A request is genuinely in flight right now — the first attempt, or
  /// a manually-triggered retry after [failed].
  sending,

  /// A network failure happened and this message is waiting out its
  /// backoff delay before the next automatic attempt.
  retrying,

  /// Terminal until the user taps to retry or discards it: either the
  /// attempt cap was exhausted, or the failure was non-retryable.
  failed,
}

/// One message waiting in (or moving through) the outbound queue.
///
/// [id] is a LOCAL id (`outbound_<n>`), unrelated to the server's
/// integer `Message.id` — the server id only exists after success.
class OutboundMessage {
  const OutboundMessage({
    required this.id,
    required this.conversationId,
    required this.text,
    required this.createdAt,
    required this.attempt,
    required this.status,
    this.errorMessage,
  });

  final String id;
  final int conversationId;
  final String text;

  /// When the user pressed send — used to order the pending bubble in
  /// the thread.
  final DateTime createdAt;

  /// 1-based number of the current/most recent attempt.
  final int attempt;
  final OutboundMessageStatus status;

  /// Only meaningful when [status] is [OutboundMessageStatus.failed].
  final String? errorMessage;

  /// Returns a copy with the given fields replaced. Like P-051's
  /// `UploadTask.copyWith`, [errorMessage] is NOT carried over when
  /// omitted — a copy without it clears the error, which is exactly what
  /// a retry wants.
  OutboundMessage copyWith({
    int? attempt,
    OutboundMessageStatus? status,
    String? errorMessage,
  }) {
    return OutboundMessage(
      id: id,
      conversationId: conversationId,
      text: text,
      createdAt: createdAt,
      attempt: attempt ?? this.attempt,
      status: status ?? this.status,
      errorMessage: errorMessage,
    );
  }
}

/// Emitted on [OutboundMessageQueueNotifier.sentStream] when a queued
/// message finally reached the server. Lets the thread screen swap the
/// local pending bubble ([localId]) for the real server-confirmed
/// [message].
class OutboundMessageSent {
  const OutboundMessageSent({required this.localId, required this.message});

  final String localId;
  final Message message;
}

/// Signature for the injectable backoff function (tests only —
/// production never overrides it). Named distinctly from P-051's
/// `BackoffDelayForAttempt` so both can be imported side by side.
typedef MessageBackoffDelayForAttempt = Duration Function(int failedAttempt);

class OutboundMessageQueueNotifier extends Notifier<List<OutboundMessage>> {
  OutboundMessageQueueNotifier({
    MessageBackoffDelayForAttempt? backoffDelayForAttempt,
  }) : _backoffDelayForAttempt =
           backoffDelayForAttempt ?? _defaultBackoffDelayForAttempt;

  final MessageBackoffDelayForAttempt _backoffDelayForAttempt;

  static const _maxAttempts = 5;

  static const _delays = [
    Duration(seconds: 2),
    Duration(seconds: 4),
    Duration(seconds: 8),
    Duration(seconds: 16),
    Duration(seconds: 32),
  ];

  static Duration _defaultBackoffDelayForAttempt(int failedAttempt) =>
      _delays[failedAttempt - 1];

  var _nextTaskId = 0;
  var _disposed = false;

  final Map<String, Timer> _pendingTimers = {};
  final StreamController<OutboundMessageSent> _sentController =
      StreamController<OutboundMessageSent>.broadcast();

  /// Fires once per message that was successfully delivered to the
  /// server, AFTER it has been removed from [state].
  Stream<OutboundMessageSent> get sentStream => _sentController.stream;

  @override
  List<OutboundMessage> build() {
    ref.onDispose(() {
      _disposed = true;
      for (final timer in _pendingTimers.values) {
        timer.cancel();
      }
      _pendingTimers.clear();
      _sentController.close();
    });
    return const [];
  }

  /// Adds a message to the queue and fires the first attempt
  /// immediately. Returns the new message's local id so the caller can
  /// reference it (retry/discard).
  String enqueueMessage({required int conversationId, required String text}) {
    final id = 'outbound_${_nextTaskId++}';
    final message = OutboundMessage(
      id: id,
      conversationId: conversationId,
      text: text,
      createdAt: DateTime.now(),
      attempt: 1,
      status: OutboundMessageStatus.sending,
    );
    state = [...state, message];
    unawaited(_attempt(id));
    return id;
  }

  /// Manually retries a terminal [OutboundMessageStatus.failed]
  /// message, resetting its attempt counter to 1 (same as P-051's
  /// `retryFailedTask`). No-op for any other status or unknown id.
  void retryFailedMessage(String messageId) {
    final message = _findMessage(messageId);
    if (message == null || message.status != OutboundMessageStatus.failed) {
      return;
    }
    _updateMessage(
      messageId,
      (m) => m.copyWith(attempt: 1, status: OutboundMessageStatus.sending),
    );
    unawaited(_attempt(messageId));
  }

  /// Discards a terminal [OutboundMessageStatus.failed] message without
  /// retrying. No-op for any other status (an in-flight or
  /// backoff-waiting message can't be discarded — see class doc).
  void discardFailedMessage(String messageId) {
    final message = _findMessage(messageId);
    if (message == null || message.status != OutboundMessageStatus.failed) {
      return;
    }
    state = state.where((m) => m.id != messageId).toList();
  }

  Future<void> _attempt(String messageId) async {
    final message = _findMessage(messageId);
    if (message == null) return;

    try {
      final sent = await ref
          .read(messageRepositoryProvider)
          .sendMessage(
            conversationId: message.conversationId,
            text: message.text,
          );
      if (_disposed) return;
      state = state.where((m) => m.id != messageId).toList();
      _sentController.add(OutboundMessageSent(localId: messageId, message: sent));
    } on ApiFailure catch (e) {
      _handleFailure(messageId, e.message, retryable: e is NetworkFailure);
    } catch (_) {
      // Anything unexpected must still surface as a visible failed
      // state — never a silently lost message (this part's core rule).
      _handleFailure(messageId, 'Failed to send message.', retryable: false);
    }
  }

  void _handleFailure(
    String messageId,
    String errorMessage, {
    required bool retryable,
  }) {
    if (_disposed) return;
    final message = _findMessage(messageId);
    if (message == null) return;

    if (!retryable || message.attempt >= _maxAttempts) {
      _updateMessage(
        messageId,
        (m) => m.copyWith(
          status: OutboundMessageStatus.failed,
          errorMessage: errorMessage,
        ),
      );
      return;
    }

    final delay = _backoffDelayForAttempt(message.attempt);
    _updateMessage(
      messageId,
      (m) => m.copyWith(status: OutboundMessageStatus.retrying),
    );
    _pendingTimers[messageId] = Timer(delay, () {
      _pendingTimers.remove(messageId);
      if (_disposed) return;
      if (_findMessage(messageId) == null) return;
      _updateMessage(
        messageId,
        (m) => m.copyWith(
          attempt: m.attempt + 1,
          status: OutboundMessageStatus.sending,
        ),
      );
      unawaited(_attempt(messageId));
    });
  }

  OutboundMessage? _findMessage(String messageId) {
    for (final m in state) {
      if (m.id == messageId) return m;
    }
    return null;
  }

  void _updateMessage(
    String messageId,
    OutboundMessage Function(OutboundMessage) update,
  ) {
    state = [
      for (final m in state)
        if (m.id == messageId) update(m) else m,
    ];
  }
}

final outboundMessageQueueProvider =
    NotifierProvider<OutboundMessageQueueNotifier, List<OutboundMessage>>(
      OutboundMessageQueueNotifier.new,
    );