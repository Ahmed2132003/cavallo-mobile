import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/widgets/app_avatar.dart';

/// A photo chosen from the gallery, already read into memory.
class PickedAvatar {
  const PickedAvatar({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

/// Opens the gallery and returns the chosen photo, or `null` when the user
/// cancels. The image is downscaled to at most 1024 px and re-encoded, which
/// keeps the upload small (the app never shows an avatar bigger than ~100 px).
Future<PickedAvatar?> pickBusinessAvatar() async {
  final XFile? picked = await ImagePicker().pickImage(
    source: ImageSource.gallery,
    maxWidth: 1024,
    maxHeight: 1024,
    imageQuality: 85,
  );
  if (picked == null) return null;
  final Uint8List bytes = await picked.readAsBytes();
  return PickedAvatar(
    bytes: bytes,
    filename: picked.name.isEmpty ? 'avatar.jpg' : picked.name,
  );
}

/// Presentational profile-photo control used by the onboarding and edit
/// screens: a big round [AppAvatar] (or the just-picked photo as a local
/// preview), a "Add / Change photo" button and, when there is a photo, a
/// "Remove photo" button. All behaviour (picking, uploading) lives in the
/// host; this widget only reports taps.
class BusinessAvatarPicker extends StatelessWidget {
  const BusinessAvatarPicker({
    super.key,
    required this.businessName,
    required this.onPick,
    this.onRemove,
    this.imageUrl,
    this.localBytes,
    this.isBusy = false,
  });

  final String businessName;
  final String? imageUrl;

  /// A photo picked but not uploaded yet (onboarding). Wins over [imageUrl].
  final Uint8List? localBytes;
  final bool isBusy;
  final VoidCallback onPick;
  final VoidCallback? onRemove;

  static const double size = 88;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bool hasPhoto =
        localBytes != null || (imageUrl != null && imageUrl!.isNotEmpty);

    final Widget preview =
        localBytes != null
            ? Semantics(
              label: l10n.bizAvatarSemantic,
              image: true,
              child: SizedBox.square(
                dimension: size,
                child: ClipOval(
                  child: Image.memory(
                    localBytes!,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            )
            : AppAvatar(
              imageUrl: imageUrl,
              name: businessName,
              size: size,
              semanticLabel: l10n.bizAvatarSemantic,
            );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        GestureDetector(
          key: const ValueKey<String>('business_avatar_preview'),
          behavior: HitTestBehavior.opaque,
          onTap: isBusy ? null : onPick,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              preview,
              if (isBusy)
                const SizedBox(
                  width: size,
                  height: size,
                  child: CircularProgressIndicator(strokeWidth: 3),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Wrap(
          alignment: WrapAlignment.center,
          children: <Widget>[
            TextButton.icon(
              key: const ValueKey<String>('business_avatar_pick_button'),
              onPressed: isBusy ? null : onPick,
              icon: const Icon(Icons.photo_camera_outlined, size: 18),
              label: Text(hasPhoto ? l10n.bizAvatarChange : l10n.bizAvatarAdd),
            ),
            if (hasPhoto && onRemove != null)
              TextButton(
                key: const ValueKey<String>('business_avatar_remove_button'),
                onPressed: isBusy ? null : onRemove,
                child: Text(l10n.bizAvatarRemove),
              ),
          ],
        ),
      ],
    );
  }
}
