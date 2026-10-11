import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../domain/business_profile_entity.dart';
import 'business_avatar_picker.dart';
import 'business_profile_provider.dart';

/// Profile-photo section of the EDIT screen. Picking uploads immediately
/// (`businessProfileProvider.notifier.uploadAvatar`) and "Remove" deletes it;
/// both show a snackbar. It reads the current photo from
/// [businessProfileProvider], so it follows the change by itself and the rest
/// of the form (and any unsaved text) is untouched.
class BusinessAvatarEditor extends ConsumerStatefulWidget {
  const BusinessAvatarEditor({super.key});

  @override
  ConsumerState<BusinessAvatarEditor> createState() =>
      _BusinessAvatarEditorState();
}

class _BusinessAvatarEditorState extends ConsumerState<BusinessAvatarEditor> {
  bool _busy = false;

  /// Last loaded profile: the provider briefly passes through `AsyncLoading`
  /// while the text fields are saved, and the avatar must not flicker then.
  BusinessProfile? _last;

  Future<void> _run(
    Future<void> Function() action,
    String Function() successText,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await action();
      messenger.showSnackBar(SnackBar(content: Text(successText())));
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(localizedApiError(l10n, error))),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pick() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final notifier = ref.read(businessProfileProvider.notifier);
    final PickedAvatar? picked;
    try {
      picked = await pickBusinessAvatar();
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bizAvatarUploadFailed)));
      return;
    }
    if (picked == null || !mounted) return;
    final PickedAvatar photo = picked;
    await _run(
      () => notifier.uploadAvatar(bytes: photo.bytes, filename: photo.filename),
      () => l10n.bizAvatarUpdated,
    );
  }

  Future<void> _remove() async {
    final l10n = context.l10n;
    final notifier = ref.read(businessProfileProvider.notifier);
    await _run(notifier.removeAvatar, () => l10n.bizAvatarRemoved);
  }

  @override
  Widget build(BuildContext context) {
    final BusinessProfile? now = switch (ref.watch(businessProfileProvider)) {
      AsyncData(value: final profile) => profile,
      _ => null,
    };
    if (now != null) _last = now;
    final BusinessProfile? profile = _last;

    return Center(
      child: BusinessAvatarPicker(
        businessName: profile?.businessName ?? '',
        imageUrl: profile?.avatarUrl,
        isBusy: _busy,
        onPick: _pick,
        onRemove: _remove,
      ),
    );
  }
}
