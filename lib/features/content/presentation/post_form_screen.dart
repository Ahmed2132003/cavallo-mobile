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
/// post_form_screen.dart` — the Post creation form (caption + optional
/// image), calling `OwnContentNotifier.createPost` (STEP 4 of this
/// part) — one multipart request when an image is attached, plain JSON
/// otherwise, exactly matching `content.serializers.PostSerializer`'s
/// own `image` field being optional (`Post.image` — `null=True,
/// blank=True` on `content/models.py`).
///
/// Create-only, no edit mode — unlike `ProductFormScreen` (Part P-033),
/// which is shared create/edit. This part's own spec asks only for
/// "Creation screens for both [Post and Reel]" — `PostDetailView`'s
/// PATCH (Part P-041) already exists server-side but has no Flutter
/// caller anywhere in this part's scope, so a `existingPost` parameter
/// would be dead code here. A future part can add edit mode the same
/// way `ProductFormScreen` already does it, without changing this
/// file's create path.
///
/// ### Upload UX pattern — reused from `ProductFormScreen` (Part
/// P-033), per this part's own spec ("reusing the image/video-upload
/// UX pattern established in P-033")
/// * `image_picker`'s `pickImage(source: ImageSource.gallery,
///   imageQuality: 85)` — identical call.
/// * A square preview box that shows the locally-picked [File] once
///   chosen, a neutral "add a photo" placeholder before that — same
///   shape as `ProductFormScreen._buildImagePicker`. There is no
///   "existing image" branch here (create-only, see above), so the
///   preview only ever has the two states just described, never a
///   pre-existing network image.
/// * Field-level backend errors read from a [ValidationFailure]'s
///   `fields` map, keyed by `content.serializers.PostSerializer`'s own
///   field names (`caption`, `image`) — same `switch (failure)` shape
///   as `ProductFormScreen._submit`'s catch block.
///
/// ### Navigation — same deliberate, flagged choice as
/// `ProductFormScreen` (Part P-033)
///
/// `RouteNames` has no entry yet for this screen (STEP 8 of this part
/// wires it in); this screen never imports `RouteNames` or navigates
/// anywhere by name. On success it calls `Navigator.of(context).pop
/// (true)`, leaving the caller (eventually `app_router.dart`)
/// responsible for pushing this screen and reacting to the popped
/// `true`. `ContentListScreen`'s own `onCreatePost` callback (Part
/// P-044 STEP 5) is exactly that seam.
class PostFormScreen extends ConsumerStatefulWidget {
  const PostFormScreen({super.key});

  @override
  ConsumerState<PostFormScreen> createState() => _PostFormScreenState();
}

class _PostFormScreenState extends ConsumerState<PostFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _captionController = TextEditingController();

  File? _imageFile;
  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text — set only from a
  /// [ValidationFailure]'s `fields` map (Part P-004), keyed by the
  /// exact field names `PostRepositoryImpl` already sends (`caption`,
  /// `image`) — same convention as `ProductFormScreen`'s own
  /// `_nameError`/`_imageError` pair.
  String? _captionError;
  String? _imageError;

  /// Any failure that doesn't map onto a specific field above.
  String? _generalError;

  @override
  void dispose() {
    _captionController.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(
      source: ImageSource.gallery,
      imageQuality: 85,
    );
    if (picked == null) return;
    setState(() => _imageFile = File(picked.path));
  }

  void _removeImage() {
    setState(() => _imageFile = null);
  }

  Future<void> _submit() async {
    setState(() {
      _captionError = null;
      _imageError = null;
      _generalError = null;
    });

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      await ref
          .read(ownContentProvider.notifier)
          .createPost(
            caption: _captionController.text.trim(),
            imageFile: _imageFile,
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
            _imageError = fields['image']?.join(' ');
            if (_captionError == null && _imageError == null) {
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

  Widget _buildImagePicker(BuildContext context) {
    final theme = Theme.of(context);
    const previewSize = 160.0;

    Widget preview;
    if (_imageFile != null) {
      preview = ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          _imageFile!,
          width: previewSize,
          height: previewSize,
          fit: BoxFit.cover,
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
        child: const Icon(Icons.add_a_photo_outlined),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Image (optional)'),
        const SizedBox(height: 8),
        preview,
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const Key('postForm_pickImageButton'),
              onPressed: _isSubmitting ? null : _pickImage,
              icon: const Icon(Icons.photo_library_outlined),
              label: Text(_imageFile == null ? 'Choose image' : 'Change image'),
            ),
            if (_imageFile != null)
              TextButton(
                key: const Key('postForm_removeImageButton'),
                onPressed: _isSubmitting ? null : _removeImage,
                child: const Text('Remove'),
              ),
          ],
        ),
        if (_imageError != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _imageError!,
              style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New post')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppTextField(
                  key: const Key('postForm_captionField'),
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
                _buildImagePicker(context),
                const SizedBox(height: 8),
                Text(
                  'Your post will be reviewed before it becomes visible to '
                  'customers.',
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
                  key: const Key('postForm_submitButton'),
                  label: 'Post',
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