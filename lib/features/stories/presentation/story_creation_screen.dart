import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/widgets/app_button.dart';
import 'story_upload_queue_provider.dart';
import 'story_upload_status_banner.dart';

/// Part P-051 STEP 4 scope: `lib/features/stories/presentation/
/// story_creation_screen.dart` — the Story creation form for Business
/// accounts. Lets a business pick a single image or short video, then
/// hands it straight to [StoryUploadQueueNotifier.enqueueUpload]
/// (STEP 2/3) rather than uploading inline itself — every retry,
/// backoff, and failure-state decision already lives in that provider,
/// so this screen's only real job is media selection plus rendering
/// [StoryUploadStatusBanner] so the business always sees the true
/// upload state, per Section 27's explicit requirement.
///
/// No caption, text-overlay, or product-link field — matching
/// `story_creation_repository.dart`'s own already-flagged finding that
/// `StorySerializer` has exactly one writable field (`media`). Building
/// UI for fields the backend doesn't accept would be its own kind of
/// dishonest screen, not a literal requirement of this part.
///
/// ### FLAGGED SCOPE DECISION 4 — image vs video picker, two buttons
///
/// `StorySerializer.validate_media` (confirmed in
/// `story_creation_repository.dart`'s own class doc) accepts either an
/// image or a short video under Story's single `media` field, but
/// `image_picker`'s API is two separate methods (`pickImage`/
/// `pickVideo`) — there's no single "pick either" call, unlike the
/// backend's single field. Two explicit buttons ("Add Photo" / "Add
/// Video") are used instead of one "Add Media" button behind a
/// picker-type popup menu, matching `ContentListScreen`'s (P-044)
/// precedent of two explicit creation entry points for a two-way
/// choice.
///
/// ### FLAGGED SCOPE DECISION 5 — no video preview/playback
///
/// No video-playback package (`video_player` or similar) exists
/// anywhere in this codebase's `pubspec.yaml` — `image_picker` is the
/// only media-related dependency (see its own pubspec comment: "the
/// first content-creation screen in this app to need an image
/// upload"). Adding one is a real dependency-and-scope decision beyond
/// what this part's own Files Expected list asks for (three files,
/// none of them a pubspec change), so a picked video is shown as a
/// plain file-name placeholder card (`Icons.videocam`), not an actual
/// video preview. Flagged here rather than silently reaching for a new
/// package.
class StoryCreationScreen extends ConsumerStatefulWidget {
  const StoryCreationScreen({super.key});

  @override
  ConsumerState<StoryCreationScreen> createState() =>
      _StoryCreationScreenState();
}

class _StoryCreationScreenState extends ConsumerState<StoryCreationScreen> {
  File? _mediaFile;
  bool _isVideo = false;
  String? _mediaError;

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() {
      _mediaFile = File(picked.path);
      _isVideo = false;
      _mediaError = null;
    });
  }

  Future<void> _pickVideo() async {
    final picked = await ImagePicker().pickVideo(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() {
      _mediaFile = File(picked.path);
      _isVideo = true;
      _mediaError = null;
    });
  }

  /// Hands [_mediaFile] to the queue and resets this form so the
  /// business can immediately start a second Story if they want — the
  /// upload itself continues in the background regardless of whether
  /// this screen stays open (`enqueueUpload` returns the moment the
  /// task is added to the queue, not when the upload finishes).
  void _submit() {
    final mediaFile = _mediaFile;
    if (mediaFile == null) {
      setState(() => _mediaError = 'Add a photo or video first.');
      return;
    }

    ref.read(storyUploadQueueProvider.notifier).enqueueUpload(mediaFile);

    setState(() {
      _mediaFile = null;
      _isVideo = false;
      _mediaError = null;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Story upload started.')),
    );
  }

  Widget _buildMediaPreview(ThemeData theme) {
    final mediaFile = _mediaFile;
    if (mediaFile == null) {
      return Container(
        key: const Key('storyCreation_emptyMediaPlaceholder'),
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          border: Border.all(color: theme.dividerColor),
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Text('No photo or video selected yet.'),
      );
    }

    if (_isVideo) {
      // See FLAGGED SCOPE DECISION 5 above — no real video preview.
      return Container(
        key: const Key('storyCreation_videoPreviewPlaceholder'),
        height: 220,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.videocam, size: 48),
            const SizedBox(height: 8),
            Text(
              mediaFile.uri.pathSegments.last,
              textAlign: TextAlign.center,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Image.file(
        mediaFile,
        key: const Key('storyCreation_imagePreview'),
        height: 220,
        width: double.infinity,
        fit: BoxFit.cover,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Create Story')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Any upload already in the queue (from this screen or a
              // prior visit) shows here too — see this file's own
              // FLAGGED SCOPE DECISION 6 (in
              // story_upload_status_banner.dart) for why there are two
              // homes for it, not one app-wide overlay.
              const StoryUploadStatusBanner(),
              _buildMediaPreview(theme),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('storyCreation_pickImageButton'),
                      onPressed: _pickImage,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Add Photo'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextButton.icon(
                      key: const Key('storyCreation_pickVideoButton'),
                      onPressed: _pickVideo,
                      icon: const Icon(Icons.videocam_outlined),
                      label: const Text('Add Video'),
                    ),
                  ),
                ],
              ),
              if (_mediaError != null) ...[
                const SizedBox(height: 12),
                Text(
                  _mediaError!,
                  style: TextStyle(color: theme.colorScheme.error),
                ),
              ],
              const SizedBox(height: 24),
              AppButton(
                key: const Key('storyCreation_submitButton'),
                label: 'Post Story',
                onPressed: _submit,
              ),
            ],
          ),
        ),
      ),
    );
  }
}