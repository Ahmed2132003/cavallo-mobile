import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/error_messages.dart';
import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/app_avatar.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_shimmer_box.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/domain/user_entity.dart';
import '../../auth/presentation/session_provider.dart';
import '../../business_profile/presentation/business_avatar_picker.dart'
    show PickedAvatar, pickBusinessAvatar;

/// Opens the gallery. A provider so tests can replace it with a fake picker
/// (no real file, no plugin).
typedef AvatarPicker = Future<PickedAvatar?> Function();

final editProfileAvatarPickerProvider = Provider<AvatarPicker>(
  (ref) => pickBusinessAvatar,
);

/// Device-side convenience limits. The backend is the final judge.
const int kMaxAvatarBytes = 5 * 1024 * 1024;
const int kMaxDisplayNameLength = 80;

/// JPEG, PNG or WebP, decided by the first bytes (not by the file name).
bool isSupportedAvatarImage(Uint8List b) {
  if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) {
    return true;
  }
  if (b.length >= 8 &&
      b[0] == 0x89 &&
      b[1] == 0x50 &&
      b[2] == 0x4E &&
      b[3] == 0x47) {
    return true;
  }
  if (b.length >= 12 &&
      b[0] == 0x52 &&
      b[1] == 0x49 &&
      b[2] == 0x46 &&
      b[3] == 0x46 &&
      b[8] == 0x57 &&
      b[9] == 0x45 &&
      b[10] == 0x42 &&
      b[11] == 0x50) {
    return true;
  }
  return false;
}

/// Part P-116B: "Edit my profile" for EVERY account type (Customer, Business,
/// Moderator, Staff): display name + personal photo. Business data (name of
/// the shop, phone, ...) stays in `BusinessProfileEditScreen`.
///
/// State: no session state of its own. It reads [sessionProvider] and saves
/// through `SessionNotifier.updateMyProfile`, so every `AppAvatar` that
/// reads the session updates at once. Nothing is written to the session until
/// the server answered OK; on failure the session is untouched and the typed
/// edits stay on screen for a retry.
class EditMyProfileScreen extends ConsumerWidget {
  const EditMyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final session = ref.watch(sessionProvider);

    final Widget body = switch (session) {
      AsyncData(value: final User user) => _EditMyProfileForm(
        key: ValueKey<int>(user.id),
        user: user,
      ),
      AsyncError(:final error) => ErrorStateWidget(
        message: localizedApiError(l10n, error),
        onRetry: () => ref.invalidate(sessionProvider),
      ),
      _ => const _ProfileSkeleton(),
    };

    return Scaffold(
      appBar: CavalloAppBar(title: Text(l10n.editProfileTitle)),
      body: SafeArea(child: body),
    );
  }
}

class _ProfileSkeleton extends StatelessWidget {
  const _ProfileSkeleton();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.editProfileLoadingLabel,
      child: const ExcludeSemantics(
        child: Padding(
          padding: EdgeInsetsDirectional.all(24),
          child: Column(
            children: <Widget>[
              AppShimmerBox.circle(size: 96),
              SizedBox(height: 24),
              AppShimmerBox(height: 52),
              SizedBox(height: 24),
              AppShimmerBox(height: 44),
            ],
          ),
        ),
      ),
    );
  }
}

enum _PhotoAction { pick, remove }

class _EditMyProfileForm extends ConsumerStatefulWidget {
  const _EditMyProfileForm({super.key, required this.user});

  final User user;

  @override
  ConsumerState<_EditMyProfileForm> createState() => _EditMyProfileFormState();
}

class _EditMyProfileFormState extends ConsumerState<_EditMyProfileForm> {
  static const double _avatarSize = 96;

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.user.displayName,
  );

  /// A photo picked but not saved yet.
  PickedAvatar? _pending;

  /// The saved photo is to be removed on save.
  bool _removeSaved = false;

  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  bool get _hasSavedPhoto {
    final String? url = widget.user.avatarUrl;
    return url != null && url.isNotEmpty;
  }

  bool get _hasPhoto => _pending != null || (_hasSavedPhoto && !_removeSaved);

  static ApiFailure? _failureOf(Object error) {
    if (error is ApiFailure) return error;
    if (error is DioException && error.error is ApiFailure) {
      return error.error as ApiFailure;
    }
    return null;
  }

  String _messageFor(AppLocalizations l10n, Object error) {
    final ApiFailure? failure = _failureOf(error);
    if (failure is ValidationFailure) {
      if (failure.fields.containsKey('avatar')) {
        return l10n.editProfileAvatarRejected;
      }
      if (failure.fields.containsKey('display_name')) {
        return l10n.editProfileNameRejected;
      }
    }
    return localizedApiError(l10n, error);
  }

  Future<void> _showPhotoSheet() async {
    final bool canRemove = _hasPhoto;
    final AppColors colors = context.appColors;
    final _PhotoAction? action = await showModalBottomSheet<_PhotoAction>(
      context: context,
      showDragHandle: true,
      builder:
          (BuildContext sheetContext) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                ListTile(
                  key: const Key('edit_profile_pick'),
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text(sheetContext.l10n.editProfilePickFromGallery),
                  onTap:
                      () => Navigator.of(sheetContext).pop(_PhotoAction.pick),
                ),
                if (canRemove)
                  ListTile(
                    key: const Key('edit_profile_remove'),
                    leading: Icon(
                      Icons.delete_outline,
                      color: colors.dangerText,
                    ),
                    title: Text(
                      sheetContext.l10n.editProfileRemovePhoto,
                      style: TextStyle(color: colors.dangerText),
                    ),
                    onTap:
                        () =>
                            Navigator.of(sheetContext).pop(_PhotoAction.remove),
                  ),
              ],
            ),
          ),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case _PhotoAction.pick:
        await _pickPhoto();
      case _PhotoAction.remove:
        setState(() {
          _pending = null;
          _removeSaved = _hasSavedPhoto;
          _error = null;
        });
    }
  }

  Future<void> _pickPhoto() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final AvatarPicker pick = ref.read(editProfileAvatarPickerProvider);

    final PickedAvatar? picked;
    try {
      picked = await pick();
    } catch (_) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editProfilePhotoPickFailed)),
      );
      return;
    }
    if (picked == null || !mounted) return;

    if (!isSupportedAvatarImage(picked.bytes)) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editProfilePhotoUnsupported)),
      );
      return;
    }
    if (picked.bytes.length > kMaxAvatarBytes) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            l10n.editProfilePhotoTooLarge(kMaxAvatarBytes ~/ (1024 * 1024)),
          ),
        ),
      );
      return;
    }
    setState(() {
      _pending = picked;
      _removeSaved = false;
      _error = null;
    });
  }

  Future<void> _save() async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final String name = _name.text.trim();
    final bool nameChanged = name != widget.user.displayName;
    final PickedAvatar? photo = _pending;

    if (!nameChanged && photo == null && !_removeSaved) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.editProfileNoChanges)),
      );
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(sessionProvider.notifier)
          .updateMyProfile(
            displayName: nameChanged ? name : null,
            avatarBytes: photo?.bytes,
            avatarFilename: photo?.filename,
            removeAvatar: _removeSaved && photo == null,
          );
      if (!mounted) return;
      setState(() {
        _pending = null;
        _removeSaved = false;
        _saving = false;
        _name.text = name;
      });
      messenger.showSnackBar(SnackBar(content: Text(l10n.editProfileSaved)));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = _messageFor(l10n, error);
      });
    }
  }

  Widget _buildAvatar(AppLocalizations l10n, AppColors colors) {
    final User user = widget.user;
    final String typed = _name.text.trim();
    final String shownName = typed.isNotEmpty ? typed : user.email;

    final PickedAvatar? pending = _pending;
    final Widget photo =
        pending != null
            ? SizedBox.square(
              dimension: _avatarSize,
              child: ClipOval(
                child: Image.memory(
                  pending.bytes,
                  fit: BoxFit.cover,
                  gaplessPlayback: true,
                  errorBuilder:
                      (_, _, _) => ColoredBox(color: colors.surfaceVariant),
                ),
              ),
            )
            : AppAvatar(
              imageUrl: _removeSaved ? null : user.avatarUrl,
              name: shownName,
              size: _avatarSize,
            );

    return Semantics(
      button: true,
      label: l10n.editProfilePhotoSemantic,
      excludeSemantics: true,
      child: GestureDetector(
        key: const Key('edit_profile_avatar'),
        behavior: HitTestBehavior.opaque,
        onTap: _saving ? null : _showPhotoSheet,
        child: Stack(
          children: <Widget>[
            photo,
            PositionedDirectional(
              end: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colors.brand,
                  border: Border.all(color: colors.surface, width: 2),
                ),
                child: Icon(
                  Icons.photo_camera,
                  size: 16,
                  color: colors.onBrand,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.appColors;
    final TextTheme text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Center(child: _buildAvatar(l10n, colors)),
            const SizedBox(height: 8),
            Text(
              widget.user.email,
              textAlign: TextAlign.center,
              style: text.bodySmall?.copyWith(color: colors.textSecondary),
            ),
            const SizedBox(height: 24),
            AppTextField(
              label: l10n.editProfileNameLabel,
              controller: _name,
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() => _error = null),
              validator: (String? value) {
                if ((value ?? '').trim().length > kMaxDisplayNameLength) {
                  return l10n.editProfileNameTooLong;
                }
                return null;
              },
            ),
            if (_error != null) ...<Widget>[
              const SizedBox(height: 16),
              Text(
                _error!,
                key: const Key('edit_profile_error'),
                style: TextStyle(color: colors.dangerText),
              ),
            ],
            const SizedBox(height: 24),
            AppButton(
              key: const Key('edit_profile_save'),
              label: l10n.editProfileSave,
              isLoading: _saving,
              onPressed: _save,
            ),
          ],
        ),
      ),
    );
  }
}
