import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/l10n/rtl_helpers.dart';
import '../../../core/theme/app_colors.dart';
import '../data/social_interaction_repository_impl.dart';
import 'comment_list_provider.dart';
import 'content_interaction_key.dart';
import 'social_error_message.dart';
import 'social_interaction_provider.dart';

/// Part P-058 + P-114 STEP 4B: pill-shaped text field + send button. On
/// success the new comment is put on top of the local list and the comment
/// counter is bumped. On failure the text is kept and a SnackBar explains
/// why. Behaviour is unchanged; only the look, the localized texts and the
/// 44 px send target are new.
class CommentInputWidget extends ConsumerStatefulWidget {
  const CommentInputWidget({
    super.key,
    required this.contentType,
    required this.objectId,
  });

  final String contentType;
  final int objectId;

  @override
  ConsumerState<CommentInputWidget> createState() => _CommentInputWidgetState();
}

class _CommentInputWidgetState extends ConsumerState<CommentInputWidget> {
  final TextEditingController _controller = TextEditingController();
  bool _sending = false;

  ContentInteractionKey get _key =>
      (contentType: widget.contentType, objectId: widget.objectId);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);

    try {
      final created = await ref
          .read(socialInteractionRepositoryProvider)
          .createComment(
            contentType: widget.contentType,
            objectId: widget.objectId,
            text: text,
          );
      if (!mounted) return;
      ref.read(commentListProvider(_key).notifier).addCreated(created);
      ref.read(contentInteractionProvider(_key).notifier).recordNewComment();
      _controller.clear();
      setState(() => _sending = false);
    } catch (e) {
      if (mounted) setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(content: Text(socialErrorMessage(e))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.appColors;
    final l10n = context.l10n;
    final pill = OutlineInputBorder(
      borderRadius: BorderRadius.circular(24),
      borderSide: BorderSide.none,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: TextField(
            controller: _controller,
            enabled: !_sending,
            minLines: 1,
            maxLines: 4,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: l10n.commentsInputHint,
              isDense: true,
              filled: true,
              fillColor: colors.surfaceVariant,
              contentPadding: const EdgeInsetsDirectional.fromSTEB(
                16,
                12,
                16,
                12,
              ),
              border: pill,
              enabledBorder: pill,
              disabledBorder: pill,
              focusedBorder: pill.copyWith(
                borderSide: BorderSide(color: colors.brand),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 44,
          height: 44,
          child: _sending
              ? const Center(
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : IconButton(
                  icon: DirectionalIcon(Icons.send, color: colors.brandText),
                  tooltip: l10n.commentsPostTooltip,
                  onPressed: _submit,
                ),
        ),
      ],
    );
  }
}