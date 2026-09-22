import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'own_content_provider.dart';

/// Part P-044 scope: `lib/features/content/presentation/
/// reel_form_screen.dart` — the Reel creation form (caption + required
/// video), calling `OwnContentNotifier.createReel` (STEP 4 of this
/// part) — always a multipart request, since `content.models.Reel.video`
/// is REQUIRED (no `null=True`/`blank=True`, unlike `Post.image`) and
/// `content.serializers.ReelSerializer.validate_video` always runs.
///
/// Create-only, same reasoning as `PostFormScreen` — this part's spec
/// asks only for creation screens, and `ReelDetailView`'s PATCH (Part
/// P-042) has no Flutter caller in this part's scope either.
///
/// ### Upload UX pattern — reused/adapted from `ProductFormScreen`
/// (Part P-033), per this part's own spec, adapted for video:
/// * `image_picker`'s `pickVideo(source: ImageSource.gallery)` — the
///   same package already used for Post's/Product's image picking,
///   just its video-picking method instead of `pickImage`. No new
///   dependency added.
/// * **Known, deliberately out-of-scope limitation (flag for a future
///   part, not silently "fixed" here):** this project has no
///   `video_player`-style dependency anywhere yet (confirmed against
///   `pubspec.yaml` — not guessed), so the picked video has no inline
///   playback preview here. The preview box instead shows a static
///   "video selected" state (play-circle icon + the picked file's
///   name), matching the same "square preview box" shape as
///   `ProductFormScreen`'s/`PostFormScreen`'s image preview without
///   claiming a play/scrub capability this project doesn't have yet.
/// * A Reel has no "existing video" branch to preview either
///   (create-only, same as Post) — the preview only ever has the two
///   states just described (none picked yet / one picked).
/// * Field-level backend errors read from a [ValidationFailure]'s
///   `fields` map, keyed by `content.serializers.ReelSerializer`'s own
///   field names (`caption`, `video`) — same `switch (failure)` shape
///   as `PostFormScreen._submit`'s catch block. A missing video is
///   additionally caught client-side, before ever calling the
///   repository — see [_submit]'s own guard, since `video` has no
///   [TextEditingController]/[FormField] for `Form.validate()` to run
///   against the way [AppTextField]'s caption does.
///
/// ### Navigation — same deliberate, flagged choice as
/// `PostFormScreen`/`ProductFormScreen`
///
/// No `RouteNames` dependency (STEP 8 of this part wires the route
/// in). On success, calls `Navigator.of(context).pop(true)`;
/// `ContentListScreen`'s `onCreateReel` callback (Part P-044 STEP 5)
/// is the seam that will eventually push this screen.
///
/// ### Why the created Reel doesn't need to be polled from here
///
/// A successful `createReel` returns the raw, just-uploaded Reel
/// (`processing_status: "uploaded"`) — this screen pops immediately
/// after that, on success, without waiting for transcoding.
/// `ContentListScreen`'s own polling (Part P-044 STEP 5, already
/// implemented) is what observes the status progress to `"ready"` once
/// the user is back on that screen — this file has no polling logic of
/// its own.
class ReelFormScreen extends ConsumerStatefulWidget {
  const ReelFormScreen({super.key});

  @override
  ConsumerState<ReelFormScreen> createState() => _ReelFormScreenState();
}

class _ReelFormScreenState extends ConsumerState<ReelFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();

  File? _videoFile;
  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — same convention as
  /// `PostFormScreen`'s own `_captionError`/`_imageError` pair, keyed
  /// by `ReelSerializer`'s field names (`caption`, `video`).
  String? _captionError;

  /// Covers BOTH a backend-reported `video` validation error (e.g. an
  /// unsupported format/oversized file, from `ReelSerializer.
  /// validate_video`) AND the purely local "you haven't picked a video
  /// yet" case — shown in the same place either way, see
  /// [_buildVideoPicker].
  String? _videoError;

  /// Any failure that doesn't map onto a specific field above.
  String? _generalError;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _videoFile = File(picked.path);
      _videoError = null;
    });
  }

  void _removeVideo() {
    setState(() => _videoFile = null);
  }

  Future<void> _submit() async {
    setState(() {
      _captionError = null;
      _videoError = null;
      _generalError = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    // `video` has no Form-registered field to carry this error the way
    // `AppTextField`'s `validator` does for `caption` — checked here,
    // explicitly, before ever calling the repository. See this class's
    // module docstring.
    final videoMissing = _videoFile == null;
    if (videoMissing) {
      setState(() => _videoError = 'A video is required.');
    }
    if (!formValid || videoMissing) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(ownContentProvider.notifier)
          .createReel(
            caption: _captionController.text.trim(),
            videoFile: _videoFile!,
          );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (error) {
      final failure = switch (error) {
        DioException(error: final ApiFailure f) => f,
        ApiFailure() => error,
        _ => null,
      };
      if (!mounted) return;
      setState(() {
        if (failure == null) {
          _generalError = 'Something went wrong. Please try again.';
          return;
        }
        switch (failure) {
          case ValidationFailure(:final fields):
            _captionError = fields['caption']?.join(' ');
            _videoError = fields['video']?.join(' ');
            if (_captionError == null && _videoError == null) {
              _generalError = failure.message;
            }
          case AuthFailure() ||
              NetworkFailure() ||
              ServerFailure() ||
              UnknownFailure():
            _generalError = failure.message;
        }
      });
      _formKey.currentState?.validate();
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }

  Widget _buildVideoPicker(BuildContext context) {
    final theme = Theme.of(context);
    const previewSize = 160.0;

    Widget preview;
    final videoFile = _videoFile;
    if (videoFile != null) {
      // No inline playback — see this file's module docstring. Shows
      // the picked file's name so the user can confirm they chose the
      // right one, without implying a scrub/play capability this
      // project doesn't have yet.
      preview = Container(
        width: previewSize,
        height: previewSize,
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.play_circle_outline,
              size: 40,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 8),
            Text(
              videoFile.uri.pathSegments.last,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      );
    } else {
      preview = Container(
        width: previewSize,
        height: previewSize,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.video_call_outlined),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Video'),
        const SizedBox(height: 8),
        preview,
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const Key('reelForm_pickVideoButton'),
              onPressed: _isSubmitting ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(_videoFile == null ? 'Choose video' : 'Change video'),
            ),
            if (_videoFile != null)
              TextButton(
                key: const Key('reelForm_removeVideoButton'),
                onPressed: _isSubmitting ? null : _removeVideo,
                child: const Text('Remove'),
              ),
          ],
        ),
        if (_videoError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _videoError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New reel')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('reelForm_captionField'),
                  label: 'Caption',
                  controller: _captionController,
                  maxLines: 4,
                  validator: (value) {
                    if (_captionError != null) return _captionError;
                    if ((value ?? '').trim().isEmpty) {
                      return 'Caption is required.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildVideoPicker(context),
                const SizedBox(height: 8),
                Text(
                  'Your video is processed first, then reviewed before it '
                  "becomes visible to customers. You'll see its status on "
                  'your content list.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_generalError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _generalError!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  key: const Key('reelForm_submitButton'),
                  label: 'Post reel',
                  isLoading: _isSubmitting,
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}