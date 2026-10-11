<#
  add_business_avatar.ps1
  Business profile photo (avatar): backend + Flutter app.

  Usage (run it from OUTSIDE both repos, e.g. D:\Cavallo, so it is not committed by `git add .`):
      .\add_business_avatar.ps1
      .\add_business_avatar.ps1 -BackendRoot D:\Cavallo\scd-backend -MobileRoot D:\Cavallo\social_commerce_app
      .\add_business_avatar.ps1 -DryRun        # only checks that every edit applies, writes nothing

  Safety: every edit is checked in memory first (the old text must appear exactly once).
  If ANY edit does not match your local file, NOTHING is written and the script says which one.
  Re-running is safe: edits that are already applied are skipped.
#>
param(
  [string]$BackendRoot = 'D:\Cavallo\scd-backend',
  [string]$MobileRoot  = 'D:\Cavallo\social_commerce_app',
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$roots = @{ backend = $BackendRoot; mobile = $MobileRoot }

foreach ($k in $roots.Keys) {
  if (-not (Test-Path $roots[$k])) { throw "Folder not found: $($roots[$k])" }
  $branch = (git -C $roots[$k] rev-parse --abbrev-ref HEAD 2>$null)
  Write-Host ("[{0}] {1}  (git branch: {2})" -f $k, $roots[$k], $branch)
}

function Read-Lf([string]$path) {
  $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
  $eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
  return @{ Text = $raw.Replace("`r`n", "`n"); Eol = $eol }
}
function Norm([string]$s) { return $s.Replace("`r`n", "`n") }
function Count-Occ([string]$text, [string]$needle) {
  $n = 0; $i = 0
  while (($i = $text.IndexOf($needle, $i, [System.StringComparison]::Ordinal)) -ge 0) { $n++; $i += $needle.Length }
  return $n
}

# ---------------------------------------------------------------- data
$edits = @(

@{ R='backend'; P='businesses/models.py'
Old=@'
    ratings_count = models.PositiveIntegerField(default=0)

    class Meta:
        verbose_name = "Business Profile"

'@
New=@'
    ratings_count = models.PositiveIntegerField(default=0)
    # Business profile photo: the round avatar shown next to the business
    # name on every screen (feed, stories, search, chat, profile). Plain
    # FileField like Product.image / Post.image - the real content check is
    # core.media.validate_upload() (python-magic), never Pillow. Written ONLY
    # through businesses.services.set_business_avatar()/clear_business_avatar()
    # (POST/DELETE /api/v1/businesses/me/avatar/), never through the JSON
    # POST/PATCH /me/ contract. null/blank = "no photo": clients then fall
    # back to the business name's initials.
    avatar = models.FileField(upload_to="businesses/avatars/", null=True, blank=True)

    class Meta:
        verbose_name = "Business Profile"

'@
},
@{ R='backend'; P='businesses/serializers.py'
Old=@'
import phonenumbers
from phonenumbers import NumberParseException
from rest_framework import serializers

from .models import BusinessProfile, CustomerProfile

'@
New=@'
import phonenumbers
from django.core.exceptions import ValidationError as DjangoValidationError
from phonenumbers import NumberParseException
from rest_framework import serializers

from core.media import validate_upload

from .models import BusinessProfile, CustomerProfile

# Business profile photo limits. Same allow-list as product/post images; 5 MB is
# plenty for a round avatar the app shows at 32-96 px.
_ALLOWED_AVATAR_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
_MAX_AVATAR_SIZE_BYTES = 5 * 1024 * 1024

'@
},
@{ R='backend'; P='businesses/serializers.py'
Old=@'
    is_featured = serializers.BooleanField(read_only=True)

    class Meta:
        model = BusinessProfile

'@
New=@'
    is_featured = serializers.BooleanField(read_only=True)
    # Profile photo URL (null when the business has none). READ-ONLY here: it
    # is written only through BusinessAvatarView (multipart), so the existing
    # JSON POST/PATCH /me/ contract is unchanged and a client can never set
    # it by sending a string. Every screen that renders a business (public
    # profile, Search, owner /me/) gets it from this one serializer.
    avatar = serializers.FileField(read_only=True)

    class Meta:
        model = BusinessProfile

'@
},
@{ R='backend'; P='businesses/serializers.py'
Old=@'
            "phone_number",
            "is_verified",

'@
New=@'
            "phone_number",
            "avatar",
            "is_verified",

'@
},
@{ R='backend'; P='businesses/serializers.py'
Old=@'
        return serializers.DateTimeField().to_representation(expires_at)
'@
New=@'
        return serializers.DateTimeField().to_representation(expires_at)


class BusinessAvatarUploadSerializer(serializers.Serializer):
    """
    Input for POST /api/v1/businesses/me/avatar/ (multipart, one `avatar`
    file). The content check goes through the single shared choke point
    core.media.validate_upload() (real MIME sniffing + size), exactly like
    ProductSerializer.validate_image(); DRF turns the Django
    ValidationError into the project's standard error envelope.
    """

    avatar = serializers.FileField(allow_empty_file=False)

    def validate_avatar(self, value):
        try:
            validate_upload(
                value,
                allowed_mime_types=_ALLOWED_AVATAR_MIME_TYPES,
                max_size_bytes=_MAX_AVATAR_SIZE_BYTES,
            )
        except DjangoValidationError as exc:
            raise serializers.ValidationError(list(exc.messages))
        return value
'@
},
@{ R='backend'; P='businesses/services.py'
Old=@'
from django.core.exceptions import ValidationError
from django.db import transaction

'@
New=@'
import logging

from django.core.exceptions import ValidationError
from django.db import transaction

'@
},
@{ R='backend'; P='businesses/services.py'
Old=@'
from .models import BusinessProfile, CustomerProfile

ACCOUNT_TYPE_BUSINESS = "business"
ACCOUNT_TYPE_CUSTOMER = "customer"

'@
New=@'
from .models import BusinessProfile, CustomerProfile

logger = logging.getLogger(__name__)

ACCOUNT_TYPE_BUSINESS = "business"
ACCOUNT_TYPE_CUSTOMER = "customer"

'@
},
@{ R='backend'; P='businesses/services.py'
Old=@'
def update_customer_profile(user, **fields) -> CustomerProfile:
'@
New=@'
def _get_own_business_profile(user) -> BusinessProfile:
    """Resolve `user`'s OWN BusinessProfile (never an id from the caller),
    with the same account_type guard as update_business_profile()."""
    if getattr(user, "account_type", None) != ACCOUNT_TYPE_BUSINESS:
        raise ValidationError(
            "Only a Business-type user can change a BusinessProfile photo."
        )
    try:
        return user.business_profile
    except BusinessProfile.DoesNotExist:
        raise ValidationError(
            "This user does not have a BusinessProfile yet. "
            "POST to create one first."
        )


def _delete_stored_file(storage, name) -> None:
    """Best-effort removal of a replaced/cleared avatar file. A storage hiccup
    must never turn a successful profile update into a 500, so failures are
    logged and swallowed (the orphaned object is harmless)."""
    if not name:
        return
    try:
        storage.delete(name)
    except Exception:  # noqa: BLE001
        logger.warning("Could not delete old avatar file %s", name, exc_info=True)


def set_business_avatar(user, file) -> BusinessProfile:
    """
    Set (or replace) `user`'s business profile photo. `file` must already be
    validated by the serializer (core.media.validate_upload). The previous
    file, if any, is removed from storage after the new one is saved.
    """
    profile = _get_own_business_profile(user)
    old_name = profile.avatar.name if profile.avatar else None

    with transaction.atomic():
        profile.avatar = file
        profile.save(update_fields=["avatar", "updated_at"])

    if old_name and old_name != profile.avatar.name:
        _delete_stored_file(profile.avatar.storage, old_name)
    return profile


def clear_business_avatar(user) -> BusinessProfile:
    """Remove `user`'s business profile photo (idempotent: no photo is fine)."""
    profile = _get_own_business_profile(user)
    old_name = profile.avatar.name if profile.avatar else None
    storage = profile.avatar.storage

    with transaction.atomic():
        profile.avatar = None
        profile.save(update_fields=["avatar", "updated_at"])

    _delete_stored_file(storage, old_name)
    return profile


def update_customer_profile(user, **fields) -> CustomerProfile:
'@
},
@{ R='backend'; P='businesses/views.py'
Old=@'
from rest_framework.generics import RetrieveAPIView
from rest_framework.permissions import AllowAny, IsAuthenticated

'@
New=@'
from rest_framework.generics import RetrieveAPIView
from rest_framework.parsers import FormParser, MultiPartParser
from rest_framework.permissions import AllowAny, IsAuthenticated

'@
},
@{ R='backend'; P='businesses/views.py'
Old=@'
from .serializers import (
    BusinessProfileOwnerSerializer,

'@
New=@'
from .serializers import (
    BusinessAvatarUploadSerializer,
    BusinessProfileOwnerSerializer,

'@
},
@{ R='backend'; P='businesses/views.py'
Old=@'
class BusinessProfilePublicView(RetrieveAPIView):
'@
New=@'
class BusinessAvatarView(APIView):
    """
    POST   /api/v1/businesses/me/avatar/  - set/replace the business profile
                                            photo (multipart, field `avatar`).
    DELETE /api/v1/businesses/me/avatar/  - remove it.

    Same IDOR-safe-by-construction rule as BusinessProfileMeView: the profile
    is always request.user's own (no id in the URL or body). Both methods
    answer 200 with the owner's full profile (BusinessProfileOwnerSerializer),
    so the client can replace its cached profile in one step. A separate
    endpoint (instead of multipart on /me/) keeps the existing JSON POST/PATCH
    contract untouched and gives "remove photo" a natural verb.

    Like BusinessProfileMeView.patch(), a successful write drops the public
    read's cache entry so the new photo shows on the very next public read.
    """

    permission_classes = [IsAuthenticated]
    parser_classes = [MultiPartParser, FormParser]

    def post(self, request):
        serializer = BusinessAvatarUploadSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)

        profile = _call_service(
            services.set_business_avatar,
            user=request.user,
            file=serializer.validated_data["avatar"],
        )
        cache.delete(_business_profile_cache_key(profile.id))
        return Response(BusinessProfileOwnerSerializer(profile).data)

    def delete(self, request):
        profile = _call_service(services.clear_business_avatar, user=request.user)
        cache.delete(_business_profile_cache_key(profile.id))
        return Response(BusinessProfileOwnerSerializer(profile).data)


class BusinessProfilePublicView(RetrieveAPIView):
'@
},
@{ R='backend'; P='businesses/urls.py'
Old=@'
from businesses.views import BusinessProfileMeView, BusinessProfilePublicView

'@
New=@'
from businesses.views import (
    BusinessAvatarView,
    BusinessProfileMeView,
    BusinessProfilePublicView,
)

'@
},
@{ R='backend'; P='businesses/urls.py'
Old=@'
    path("<int:pk>/", BusinessProfilePublicView.as_view(), name="business-public"),
'@
New=@'
    path("me/avatar/", BusinessAvatarView.as_view(), name="business-me-avatar"),
    path("<int:pk>/", BusinessProfilePublicView.as_view(), name="business-public"),
'@
},
@{ R='backend'; P='chat/serializers.py'
Old=@'
class ConversationListSerializer(serializers.ModelSerializer):
'@
New=@'
def _resolve_conversation_participant_avatar(user):
    """
    Profile photo URL of a chat participant, or None. Only Business accounts
    have a photo (BusinessProfile.avatar); Customers have none, so the client
    falls back to initials. Never raises: a storage/signing hiccup must not
    break the whole conversation list.
    """
    business_profile = getattr(user, "business_profile", None)
    if business_profile is None or not business_profile.avatar:
        return None
    try:
        return business_profile.avatar.url
    except Exception:  # noqa: BLE001
        return None


class ConversationListSerializer(serializers.ModelSerializer):
'@
},
@{ R='backend'; P='chat/serializers.py'
Old=@'
            "display_name": _resolve_conversation_participant_display_name(user),
        }
'@
New=@'
            "display_name": _resolve_conversation_participant_display_name(user),
            "avatar": _resolve_conversation_participant_avatar(user),
        }
'@
},
@{ R='backend'; P='chat/serializers.py'
Old=@'
        "business_name": None,
        "preview": None,
    }
'@
New=@'
        "business_name": None,
        "business_avatar": None,
        "preview": None,
    }
'@
},
@{ R='backend'; P='chat/serializers.py'
Old=@'
        business_name=target.business.business_name,
        preview=_preview_for(target),
'@
New=@'
        business_name=target.business.business_name,
        business_avatar=_resolve_business_avatar_url(target.business),
        preview=_preview_for(target),
'@
},
@{ R='backend'; P='chat/serializers.py'
Old=@'
def _resolve_conversation_participant_avatar(user):
'@
New=@'
def _resolve_business_avatar_url(business_profile):
    """Profile photo URL of a BusinessProfile, or None. Never raises."""
    if business_profile is None or not business_profile.avatar:
        return None
    try:
        return business_profile.avatar.url
    except Exception:  # noqa: BLE001
        return None


def _resolve_conversation_participant_avatar(user):
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
    this.followerCount = 0,
    this.isFeatured = false,
  });
'@
New=@'
    this.followerCount = 0,
    this.isFeatured = false,
    this.avatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
  final bool isFeatured;

  BusinessProfile copyWith({
'@
New=@'
  final bool isFeatured;

  /// Business profile photo URL (a short-lived signed URL from the backend),
  /// or `null` when the business has none - the UI then shows the initials
  /// of [businessName] (see `AppAvatar`).
  final String? avatarUrl;

  BusinessProfile copyWith({
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
    bool? isFeatured,
  }) {
    return BusinessProfile(
'@
New=@'
    bool? isFeatured,
    String? avatarUrl,
  }) {
    return BusinessProfile(
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
      isFeatured: isFeatured ?? this.isFeatured,
    );
  }
'@
New=@'
      isFeatured: isFeatured ?? this.isFeatured,
      avatarUrl: avatarUrl ?? this.avatarUrl,
    );
  }

  /// Same profile with exactly [url] as its photo, where `null` REMOVES it.
  /// [copyWith] cannot do that (its `null` means "keep").
  BusinessProfile withAvatarUrl(String? url) {
    return BusinessProfile(
      id: id,
      businessName: businessName,
      businessType: businessType,
      country: country,
      city: city,
      description: description,
      phoneNumber: phoneNumber,
      categoryId: categoryId,
      isVerified: isVerified,
      followerCount: followerCount,
      isFeatured: isFeatured,
      avatarUrl: url,
    );
  }
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
          other.isFeatured == isFeatured);
'@
New=@'
          other.isFeatured == isFeatured &&
          other.avatarUrl == avatarUrl);
'@
},
@{ R='mobile'; P='lib/features/business_profile/domain/business_profile_entity.dart'
Old=@'
    followerCount,
    isFeatured,
  );
'@
New=@'
    followerCount,
    isFeatured,
    avatarUrl,
  );
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/dtos/business_profile_response_dto.dart'
Old=@'
    required this.followerCount,
    this.isFeatured = false,
  });
'@
New=@'
    required this.followerCount,
    this.isFeatured = false,
    this.avatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/dtos/business_profile_response_dto.dart'
Old=@'
      isFeatured: (json['is_featured'] as bool?) ?? false,
    );
'@
New=@'
      isFeatured: (json['is_featured'] as bool?) ?? false,
      // `avatar` is the profile photo URL, or null / missing when the business
      // has none (older cached payloads lack the key).
      avatarUrl: switch (json['avatar']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
    );
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/dtos/business_profile_response_dto.dart'
Old=@'
  final bool isFeatured;

  Map<String, dynamic> toJson() => {
'@
New=@'
  final bool isFeatured;

  /// Profile photo URL (wire key `avatar`), `null` when none.
  final String? avatarUrl;

  Map<String, dynamic> toJson() => {
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/dtos/business_profile_response_dto.dart'
Old=@'
    'is_featured': isFeatured,
  };
'@
New=@'
    'is_featured': isFeatured,
    if (avatarUrl != null) 'avatar': avatarUrl,
  };
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/business_profile_repository_impl.dart'
Old=@'
      isFeatured: dto.isFeatured,
    );
'@
New=@'
      isFeatured: dto.isFeatured,
      avatarUrl: dto.avatarUrl,
    );
'@
},
@{ R='mobile'; P='lib/features/business_profile/data/business_profile_public_repository.dart'
Old=@'
      isFeatured: dto.isFeatured,
    );
'@
New=@'
      isFeatured: dto.isFeatured,
      avatarUrl: dto.avatarUrl,
    );
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_provider.dart'
Old=@'
import '../data/business_profile_repository_impl.dart';

'@
New=@'
import '../data/business_avatar_repository.dart';
import '../data/business_profile_repository_impl.dart';

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_provider.dart'
Old=@'
import '../domain/business_profile_repository.dart';

'@
New=@'
import '../domain/business_profile_repository.dart';
import 'business_profile_public_provider.dart';

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_provider.dart'
Old=@'
  Future<void> refreshProfile() async {
'@
New=@'
  /// Uploads a new profile photo. Unlike the other mutations this does NOT
  /// pass through `AsyncLoading` (the edit form must not flash or re-seed);
  /// on success the current profile is replaced by one carrying the new URL,
  /// and the public profile cache is invalidated so every screen showing this
  /// business (feed, stories, search...) re-fetches the new photo. A failure
  /// is rethrown and leaves the state untouched.
  Future<void> uploadAvatar({
    required List<int> bytes,
    required String filename,
  }) async {
    final url = await ref
        .read(businessAvatarRepositoryProvider)
        .upload(bytes: bytes, filename: filename);
    _applyAvatar(url);
  }

  /// Removes the profile photo (same state rules as [uploadAvatar]).
  Future<void> removeAvatar() async {
    final url = await ref.read(businessAvatarRepositoryProvider).remove();
    _applyAvatar(url);
  }

  void _applyAvatar(String? url) {
    final current = switch (state) {
      AsyncData(:final value) => value,
      _ => null,
    };
    if (current == null) return;
    state = AsyncValue.data(current.withAvatarUrl(url));
    ref.invalidate(businessProfilePublicProvider(current.id));
  }

  Future<void> refreshProfile() async {
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
import 'package:flutter/material.dart';

'@
New=@'
import 'dart:typed_data';

import 'package:flutter/material.dart';

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
import 'business_profile_provider.dart';

'@
New=@'
import 'business_avatar_picker.dart';
import 'business_profile_provider.dart';

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
  bool _isSubmitting = false;

  /// Backend-driven,
'@
New=@'
  bool _isSubmitting = false;

  /// Profile photo picked on this screen, uploaded right after the profile is
  /// created (the photo endpoint needs an existing profile). Optional.
  Uint8List? _avatarBytes;
  String? _avatarFilename;

  Future<void> _pickAvatar() async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      final PickedAvatar? picked = await pickBusinessAvatar();
      if (picked == null || !mounted) return;
      setState(() {
        _avatarBytes = picked.bytes;
        _avatarFilename = picked.filename;
      });
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.bizAvatarUploadFailed)));
    }
  }

  /// Backend-driven,
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
    final trimmedDescription = _descriptionController.text.trim();

    try {
      await ref
          .read(businessProfileProvider.notifier)
          .createProfile(
'@
New=@'
    final trimmedDescription = _descriptionController.text.trim();

    // Captured before the awaits: creating the profile can make the router
    // leave this screen, after which `ref`/`context` must not be used.
    final notifier = ref.read(businessProfileProvider.notifier);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    final avatarBytes = _avatarBytes;
    final avatarFilename = _avatarFilename;

    try {
      await notifier.createProfile(
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
            phoneNumber: _phoneNumber,
          );
      if (!mounted) return;
      context.goNamed(RouteNames.home);
'@
New=@'
            phoneNumber: _phoneNumber,
          );
      // The profile now exists. A failing photo upload must not undo that:
      // tell the user and let them add the photo later from Edit profile.
      if (avatarBytes != null && avatarFilename != null) {
        try {
          await notifier.uploadAvatar(
            bytes: avatarBytes,
            filename: avatarFilename,
          );
        } catch (_) {
          messenger.showSnackBar(
            SnackBar(content: Text(l10n.bizAvatarUploadLater)),
          );
        }
      }
      if (!mounted) return;
      context.goNamed(RouteNames.home);
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_onboarding_screen.dart'
Old=@'
                children: [
                  AppTextField(
                    label: context.l10n.bizFieldName,
'@
New=@'
                children: [
                  Center(
                    child: BusinessAvatarPicker(
                      businessName: _businessNameController.text,
                      localBytes: _avatarBytes,
                      isBusy: _isSubmitting,
                      onPick: _pickAvatar,
                      onRemove:
                          () => setState(() {
                            _avatarBytes = null;
                            _avatarFilename = null;
                          }),
                    ),
                  ),
                  const SizedBox(height: 16),
                  AppTextField(
                    label: context.l10n.bizFieldName,
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_edit_screen.dart'
Old=@'
import 'business_profile_provider.dart';

'@
New=@'
import 'business_avatar_editor.dart';
import 'business_profile_provider.dart';

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_edit_screen.dart'
Old=@'
            key: ValueKey<BusinessProfile>(profile),
'@
New=@'
            key: ValueKey<Object>(
              // Every field EXCEPT the photo: changing the photo must not
              // re-seed the form and wipe unsaved text edits.
              Object.hash(
                profile.id,
                profile.businessName,
                profile.businessType,
                profile.country,
                profile.city,
                profile.description,
                profile.phoneNumber,
                profile.categoryId,
                profile.isVerified,
                profile.followerCount,
                profile.isFeatured,
              ),
            ),
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_edit_screen.dart'
Old=@'
            children: [
              AppTextField(
                label: context.l10n.bizFieldName,
'@
New=@'
            children: [
              const BusinessAvatarEditor(),
              const SizedBox(height: 16),
              AppTextField(
                label: context.l10n.bizFieldName,
'@
},
@{ R='mobile'; P='lib/features/content/presentation/content_card_header.dart'
Old=@'
    this.isFeatured = false,
  });
'@
New=@'
    this.isFeatured = false,
    this.businessAvatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/content/presentation/content_card_header.dart'
Old=@'
  final bool isFeatured;

  static const double avatarSize = 32;
'@
New=@'
  final bool isFeatured;

  /// Profile photo of the business; `null` shows the name's initials.
  final String? businessAvatarUrl;

  static const double avatarSize = 32;
'@
},
@{ R='mobile'; P='lib/features/content/presentation/content_card_header.dart'
Old=@'
          AppAvatar(name: businessName, size: avatarSize),
'@
New=@'
          AppAvatar(
            imageUrl: businessAvatarUrl,
            name: businessName,
            size: avatarSize,
          ),
'@
},
@{ R='mobile'; P='lib/features/content/presentation/post_card.dart'
Old=@'
    this.isBusinessVerified = false,
  });
'@
New=@'
    this.isBusinessVerified = false,
    this.businessAvatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/content/presentation/post_card.dart'
Old=@'
  final bool isBusinessVerified;

'@
New=@'
  final bool isBusinessVerified;

  /// Business profile photo for the header avatar (`null` = initials).
  final String? businessAvatarUrl;

'@
},
@{ R='mobile'; P='lib/features/content/presentation/post_card.dart'
Old=@'
              isVerified: isBusinessVerified,
              isFeatured: post.isFeatured,
'@
New=@'
              isVerified: isBusinessVerified,
              isFeatured: post.isFeatured,
              businessAvatarUrl: businessAvatarUrl,
'@
},
@{ R='mobile'; P='lib/features/content/presentation/reel_card.dart'
Old=@'
    this.isBusinessVerified = false,
  });
'@
New=@'
    this.isBusinessVerified = false,
    this.businessAvatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/content/presentation/reel_card.dart'
Old=@'
  final bool isBusinessVerified;

'@
New=@'
  final bool isBusinessVerified;

  /// Business profile photo for the header avatar (`null` = initials).
  final String? businessAvatarUrl;

'@
},
@{ R='mobile'; P='lib/features/content/presentation/reel_card.dart'
Old=@'
              isVerified: isBusinessVerified,
              isFeatured: reel.isFeatured,
'@
New=@'
              isVerified: isBusinessVerified,
              isFeatured: reel.isFeatured,
              businessAvatarUrl: businessAvatarUrl,
'@
},
@{ R='mobile'; P='lib/features/feed/presentation/home_feed_screen.dart'
Old=@'
    // Part P-114 STEP 2: no wrapper padding;
'@
New=@'
    final String? avatarUrl = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.avatarUrl,
      _ => null,
    };

    // Part P-114 STEP 2: no wrapper padding;
'@
},
@{ R='mobile'; P='lib/features/feed/presentation/home_feed_screen.dart'
Old=@'
      PostFeedItem(:final post) => PostCard(
        post: post,
        businessName: businessName,
'@
New=@'
      PostFeedItem(:final post) => PostCard(
        post: post,
        businessName: businessName,
        businessAvatarUrl: avatarUrl,
'@
},
@{ R='mobile'; P='lib/features/feed/presentation/home_feed_screen.dart'
Old=@'
      ReelFeedItem(:final reel) => ReelCard(
        reel: reel,
        businessName: businessName,
'@
New=@'
      ReelFeedItem(:final reel) => ReelCard(
        reel: reel,
        businessName: businessName,
        businessAvatarUrl: avatarUrl,
'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
    this.businessName,
    this.previewText,
'@
New=@'
    this.businessName,
    this.businessAvatarUrl,
    this.previewText,
'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
  final String? businessName;
  final String? previewText;
'@
New=@'
  final String? businessName;

  /// Profile photo of the sharing business (`business_avatar`), or `null`.
  final String? businessAvatarUrl;
  final String? previewText;
'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
    final businessName = raw['business_name'];

'@
New=@'
    final businessName = raw['business_name'];
    final businessAvatar = raw['business_avatar'];

'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
      businessName: businessName is String ? businessName : null,

'@
New=@'
      businessName: businessName is String ? businessName : null,
      businessAvatarUrl:
          businessAvatar is String && businessAvatar.isNotEmpty
              ? businessAvatar
              : null,

'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
          other.businessName == businessName &&

'@
New=@'
          other.businessName == businessName &&
          other.businessAvatarUrl == businessAvatarUrl &&

'@
},
@{ R='mobile'; P='lib/features/chat/domain/shared_content.dart'
Old=@'
    businessName,
    previewText,
'@
New=@'
    businessName,
    businessAvatarUrl,
    previewText,
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/shared_content_card.dart'
Old=@'
          AsyncData(value: final PublicPost post) => PostCard(
            post: post,
            businessName: businessName,
'@
New=@'
          AsyncData(value: final PublicPost post) => PostCard(
            post: post,
            businessName: businessName,
            businessAvatarUrl: shared.businessAvatarUrl,
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/shared_content_card.dart'
Old=@'
          AsyncData(value: final PublicReel reel) => ReelCard(
            reel: reel,
            businessName: businessName,
'@
New=@'
          AsyncData(value: final PublicReel reel) => ReelCard(
            reel: reel,
            businessName: businessName,
            businessAvatarUrl: shared.businessAvatarUrl,
'@
},
@{ R='mobile'; P='lib/features/stories/presentation/story_ring_widget.dart'
Old=@'
    required this.businessName,
  });

  final int businessId;
  final String businessName;
'@
New=@'
    required this.businessName,
    this.avatarUrl,
  });

  final int businessId;
  final String businessName;

  /// Business profile photo (`null` = initials). Passed by the caller, which
  /// already resolves the public profile, so this widget stays provider-free.
  final String? avatarUrl;
'@
},
@{ R='mobile'; P='lib/features/stories/presentation/story_ring_widget.dart'
Old=@'
              AppAvatar(
                name: businessName,
                size: avatarSize,
'@
New=@'
              AppAvatar(
                imageUrl: avatarUrl,
                name: businessName,
                size: avatarSize,
'@
},
@{ R='mobile'; P='lib/features/discover/presentation/stories_bar_widget.dart'
Old=@'
    return StoryRingWidget(businessId: businessId, businessName: businessName);
'@
New=@'
    final String? avatarUrl = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.avatarUrl,
      _ => null,
    };

    return StoryRingWidget(
      businessId: businessId,
      businessName: businessName,
      avatarUrl: avatarUrl,
    );
'@
},
@{ R='mobile'; P='lib/features/stories/presentation/story_viewer_screen.dart'
Old=@'
import 'story_public_provider.dart';

'@
New=@'
import '../../business_profile/presentation/business_avatar_provider.dart';
import 'story_public_provider.dart';

'@
},
@{ R='mobile'; P='lib/features/stories/presentation/story_viewer_screen.dart'
Old=@'
                      AppAvatar(name: widget.businessName, size: 32),
'@
New=@'
                      AppAvatar(
                        imageUrl: ref.watch(
                          businessAvatarUrlProvider(widget.businessId),
                        ),
                        name: widget.businessName,
                        size: 32,
                      ),
'@
},
@{ R='mobile'; P='lib/features/search/presentation/search_result_card.dart'
Old=@'
          AppAvatar(
            name: business.businessName,
            size: 52,
'@
New=@'
          AppAvatar(
            imageUrl: business.avatarUrl,
            name: business.businessName,
            size: 52,
'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_profile_public_screen.dart'
Old=@'
      child: AppAvatar(
        name: profile.businessName,
        size: _size,
'@
New=@'
      child: AppAvatar(
        imageUrl: profile.avatarUrl,
        name: profile.businessName,
        size: _size,
'@
},
@{ R='mobile'; P='lib/features/profile_hub/presentation/profile_hub_screen.dart'
Old=@'
          AppAvatar(name: title, size: 64),
'@
New=@'
          AppAvatar(imageUrl: business?.avatarUrl, name: title, size: 64),
'@
},
@{ R='mobile'; P='lib/features/chat/domain/conversation.dart'
Old=@'
    required this.displayName,
  });
'@
New=@'
    required this.displayName,
    this.avatarUrl,
  });
'@
},
@{ R='mobile'; P='lib/features/chat/domain/conversation.dart'
Old=@'
  final String displayName;

'@
New=@'
  final String displayName;

  /// Profile photo of a Business participant (`avatar`); `null` for
  /// customers and businesses without one - the UI shows initials.
  final String? avatarUrl;

'@
},
@{ R='mobile'; P='lib/features/chat/domain/conversation.dart'
Old=@'
      displayName: json['display_name'] as String,
    );
'@
New=@'
      displayName: json['display_name'] as String,
      avatarUrl: switch (json['avatar']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
    );
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/chat_list_screen.dart'
Old=@'
            AppAvatar(
              name: displayName,
              size: _avatarSize,
'@
New=@'
            AppAvatar(
              imageUrl: other?.avatarUrl,
              name: displayName,
              size: _avatarSize,
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/chat_thread_screen.dart'
Old=@'
            AppAvatar(name: displayName, size: 36),
'@
New=@'
            AppAvatar(
              imageUrl: widget.conversation.otherParticipant?.avatarUrl,
              name: displayName,
              size: 36,
            ),
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/new_chat_sheet.dart'
Old=@'
import '../domain/followed_business.dart';

'@
New=@'
import '../domain/followed_business.dart';
import 'followed_business_avatar.dart';

'@
},
@{ R='mobile'; P='lib/features/chat/presentation/new_chat_sheet.dart'
Old=@'
          leading: AppAvatar(name: business.businessName, size: 44),
'@
New=@'
          leading: FollowedBusinessAvatar(business: business),
'@
},
@{ R='mobile'; P='lib/features/chat/presentation/new_chat_sheet.dart'
Old=@'
import '../../../core/widgets/app_avatar.dart';

'@
New=@'

'@
},
@{ R='end'; P='end'; Old='x'; New='x' }
)
$edits = $edits | Where-Object { $_.R -ne 'end' }

$newFiles = @(
@{ R='backend'; P='businesses/tests/test_avatar.py'; Eol='CRLF'
Content=@'
"""
Business profile photo (avatar):
POST/DELETE /api/v1/businesses/me/avatar/, the read-only `avatar` field on the
owner /me/ and public profile responses, and the chat list's
other_participant.avatar.
"""

import pytest
from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.urls import reverse
from rest_framework.test import APIClient

from accounts.models import User
from businesses.models import BusinessProfile
from businesses.services import create_business_profile
from core.tests.test_media import _DISGUISED_EXE_BYTES, _VALID_PNG_BYTES

pytestmark = pytest.mark.django_db

ME_URL = reverse("businesses:business-me")
AVATAR_URL = reverse("businesses:business-me-avatar")


def _make_user(email, account_type="business"):
    return User.objects.create_user(
        username=email,
        email=email,
        password="Str0ngPass!23",
        account_type=account_type,
    )


def _make_profile(email="avatar-owner@example.com", name="Avatar Biz"):
    user = _make_user(email)
    profile = create_business_profile(
        user=user,
        business_name=name,
        business_type="trader",
        country="EG",
        city="Cairo",
    )
    return user, profile


def _client_for(user):
    client = APIClient()
    client.force_authenticate(user=User.objects.get(pk=user.pk))
    return client


def _png(name="photo.png"):
    return SimpleUploadedFile(name, _VALID_PNG_BYTES, content_type="image/png")


def test_profile_without_avatar_reads_null_everywhere():
    user, profile = _make_profile()
    client = _client_for(user)

    assert client.get(ME_URL).json()["avatar"] is None
    public = APIClient().get(reverse("businesses:business-public", args=[profile.id]))
    assert public.status_code == 200
    assert public.json()["avatar"] is None


def test_upload_sets_avatar_and_returns_it_on_me_and_public_reads():
    user, profile = _make_profile()
    client = _client_for(user)

    response = client.post(AVATAR_URL, {"avatar": _png()}, format="multipart")

    assert response.status_code == 200, response.content
    body = response.json()
    assert body["id"] == profile.id
    assert body["avatar"]
    profile.refresh_from_db()
    assert profile.avatar

    assert client.get(ME_URL).json()["avatar"]
    public = APIClient().get(reverse("businesses:business-public", args=[profile.id]))
    assert public.json()["avatar"]


def test_upload_invalidates_the_public_profile_cache():
    user, profile = _make_profile()
    public_url = reverse("businesses:business-public", args=[profile.id])
    assert APIClient().get(public_url).json()["avatar"] is None  # primes the cache

    _client_for(user).post(AVATAR_URL, {"avatar": _png()}, format="multipart")

    assert APIClient().get(public_url).json()["avatar"]
    cache.clear()


def test_replacing_the_avatar_keeps_a_single_current_photo():
    user, profile = _make_profile()
    client = _client_for(user)
    client.post(AVATAR_URL, {"avatar": _png("one.png")}, format="multipart")
    profile.refresh_from_db()
    first_name = profile.avatar.name

    response = client.post(AVATAR_URL, {"avatar": _png("two.png")}, format="multipart")

    assert response.status_code == 200
    profile.refresh_from_db()
    assert profile.avatar
    assert profile.avatar.name != first_name


def test_delete_removes_the_avatar_and_is_idempotent():
    user, profile = _make_profile()
    client = _client_for(user)
    client.post(AVATAR_URL, {"avatar": _png()}, format="multipart")

    first = client.delete(AVATAR_URL)
    second = client.delete(AVATAR_URL)

    assert first.status_code == 200
    assert first.json()["avatar"] is None
    assert second.status_code == 200
    profile.refresh_from_db()
    assert not profile.avatar


def test_rejects_a_disguised_non_image_file():
    user, profile = _make_profile()
    fake = SimpleUploadedFile(
        "photo.png", _DISGUISED_EXE_BYTES, content_type="image/png"
    )

    response = _client_for(user).post(AVATAR_URL, {"avatar": fake}, format="multipart")

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"
    profile.refresh_from_db()
    assert not profile.avatar


def test_missing_file_is_a_validation_error():
    user, _ = _make_profile()

    response = _client_for(user).post(AVATAR_URL, {}, format="multipart")

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_unauthenticated_is_401():
    assert APIClient().post(AVATAR_URL, {"avatar": _png()}, format="multipart").status_code == 401
    assert APIClient().delete(AVATAR_URL).status_code == 401


def test_customer_account_cannot_set_a_business_avatar():
    customer = _make_user("avatar-customer@example.com", account_type="customer")

    response = _client_for(customer).post(
        AVATAR_URL, {"avatar": _png()}, format="multipart"
    )

    assert response.status_code == 400
    assert response.json()["error"]["code"] == "VALIDATION_ERROR"


def test_business_without_a_profile_yet_gets_a_validation_error():
    user = _make_user("avatar-noprofile@example.com")

    response = _client_for(user).post(AVATAR_URL, {"avatar": _png()}, format="multipart")

    assert response.status_code == 400


def test_avatar_is_not_writable_through_the_json_me_endpoint():
    user, profile = _make_profile()

    response = _client_for(user).patch(
        ME_URL, {"avatar": "https://evil.example/x.png"}, format="json"
    )

    assert response.status_code == 200
    profile.refresh_from_db()
    assert not profile.avatar


def test_a_user_can_only_change_their_own_avatar():
    owner, owner_profile = _make_profile("avatar-a@example.com", "Biz A")
    other, other_profile = _make_profile("avatar-b@example.com", "Biz B")

    _client_for(owner).post(AVATAR_URL, {"avatar": _png()}, format="multipart")

    owner_profile.refresh_from_db()
    other_profile.refresh_from_db()
    assert owner_profile.avatar
    assert not other_profile.avatar


def test_search_style_serializer_exposes_avatar_read_only():
    from businesses.serializers import BusinessProfileSerializer

    assert BusinessProfileSerializer().fields["avatar"].read_only is True
    assert BusinessProfile._meta.get_field("avatar").null is True


def test_chat_list_other_participant_carries_the_business_avatar():
    from chat.models import Conversation, ConversationParticipant

    biz_user, biz_profile = _make_profile("avatar-chat-biz@example.com", "Chat Biz")
    _client_for(biz_user).post(AVATAR_URL, {"avatar": _png()}, format="multipart")
    customer = _make_user("avatar-chat-cust@example.com", account_type="customer")
    conversation = Conversation.objects.create()
    ConversationParticipant.objects.create(conversation=conversation, user=biz_user)
    ConversationParticipant.objects.create(conversation=conversation, user=customer)

    response = _client_for(customer).get(reverse("chat:conversation-list"))

    assert response.status_code == 200
    other = response.data[0]["other_participant"]
    assert other["display_name"] == "Chat Biz"
    assert other["avatar"]


def test_chat_list_customer_participant_has_no_avatar():
    from chat.models import Conversation, ConversationParticipant

    biz_user, _ = _make_profile("avatar-chat-biz2@example.com", "Chat Biz 2")
    customer = _make_user("avatar-chat-cust2@example.com", account_type="customer")
    conversation = Conversation.objects.create()
    ConversationParticipant.objects.create(conversation=conversation, user=biz_user)
    ConversationParticipant.objects.create(conversation=conversation, user=customer)

    response = _client_for(biz_user).get(reverse("chat:conversation-list"))

    assert response.status_code == 200
    assert response.data[0]["other_participant"]["avatar"] is None

'@
},
@{ R='mobile'; P='lib/features/business_profile/data/business_avatar_repository.dart'; Eol='CRLF'
Content=@'
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';

/// Business profile photo upload / removal
/// (`/api/v1/businesses/me/avatar/`, multipart field `avatar`).
///
/// Kept apart from `BusinessProfileRepository` on purpose: that contract is
/// implemented by test fakes, and the photo has its own endpoint (the JSON
/// `/me/` POST/PATCH never carries it). Both calls answer with the owner's
/// full profile; only its `avatar` URL is read here (`null` after a removal).
///
/// A failed call rethrows the [DioException] untouched, so `.error` stays the
/// typed `ApiFailure` (same convention as the other repositories).
class BusinessAvatarRepository {
  BusinessAvatarRepository({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _avatarPath = '/api/v1/businesses/me/avatar/';

  /// Uploads [bytes] as the new photo and returns its URL.
  Future<String?> upload({
    required List<int> bytes,
    required String filename,
  }) async {
    final data = FormData.fromMap(<String, dynamic>{
      'avatar': MultipartFile.fromBytes(bytes, filename: filename),
    });
    final response = await _dio.post<Map<String, dynamic>>(
      _avatarPath,
      data: data,
    );
    return _avatarOf(response.data);
  }

  /// Removes the photo. Always resolves to `null` on success.
  Future<String?> remove() async {
    final response = await _dio.delete<Map<String, dynamic>>(_avatarPath);
    return _avatarOf(response.data);
  }

  static String? _avatarOf(Map<String, dynamic>? json) {
    final value = json?['avatar'];
    return value is String && value.isNotEmpty ? value : null;
  }
}

final businessAvatarRepositoryProvider = Provider<BusinessAvatarRepository>(
  (ref) => BusinessAvatarRepository(dio: ref.watch(dioClientProvider)),
);

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_avatar_provider.dart'; Eol='CRLF'
Content=@'
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'business_profile_public_provider.dart';

/// Profile photo URL of the business [id], or `null` while the profile is
/// loading / failed / has no photo (callers then show the initials).
///
/// Derived from [businessProfilePublicProvider], so it shares that provider's
/// fetch and cache with every other widget that shows the same business, and
/// updates when the owner changes the photo (the notifier invalidates it).
final businessAvatarUrlProvider = Provider.autoDispose.family<String?, int>((
  ref,
  id,
) {
  final async = ref.watch(businessProfilePublicProvider(id));
  return switch (async) {
    AsyncData(value: final profile) => profile?.avatarUrl,
    _ => null,
  };
});

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_avatar_picker.dart'; Eol='CRLF'
Content=@'
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

'@
},
@{ R='mobile'; P='lib/features/business_profile/presentation/business_avatar_editor.dart'; Eol='CRLF'
Content=@'
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

'@
},
@{ R='mobile'; P='lib/features/chat/presentation/followed_business_avatar.dart'; Eol='CRLF'
Content=@'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/widgets/app_avatar.dart';
import '../../business_profile/presentation/business_avatar_provider.dart';
import '../domain/followed_business.dart';

/// Avatar of a business in the "New chat" picker. The followed-businesses
/// endpoint carries no photo, so it is resolved per row from the public
/// profile (same lookup the feed rows use); initials show until it arrives.
class FollowedBusinessAvatar extends ConsumerWidget {
  const FollowedBusinessAvatar({super.key, required this.business});

  final FollowedBusiness business;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppAvatar(
      imageUrl: ref.watch(businessAvatarUrlProvider(business.businessId)),
      name: business.businessName,
      size: 44,
    );
  }
}

'@
},
@{ R='mobile'; P='test/features/business_profile/business_avatar_test.dart'; Eol='CRLF'
Content=@'
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/business_profile/data/dtos/business_profile_response_dto.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/chat/domain/conversation.dart';
import 'package:social_commerce_app/features/chat/domain/shared_content.dart';

Map<String, dynamic> _profileJson({Object? avatar = 'absent'}) => {
  'id': 7,
  'business_name': 'Acme',
  'business_type': 'trader',
  'country': 'Egypt',
  'city': 'Cairo',
  'description': '',
  'phone_number': '',
  'category': null,
  'is_verified': false,
  'follower_count': 0,
  if (avatar != 'absent') 'avatar': avatar,
};

void main() {
  group('BusinessProfileResponseDto avatar', () {
    test('reads the avatar URL', () {
      final dto = BusinessProfileResponseDto.fromJson(
        _profileJson(avatar: 'https://cdn.example/a.png?sig=1'),
      );
      expect(dto.avatarUrl, 'https://cdn.example/a.png?sig=1');
      expect(dto.toJson()['avatar'], 'https://cdn.example/a.png?sig=1');
    });

    test('null, empty and missing avatar all mean no photo', () {
      expect(
        BusinessProfileResponseDto.fromJson(_profileJson(avatar: null)).avatarUrl,
        isNull,
      );
      expect(
        BusinessProfileResponseDto.fromJson(_profileJson(avatar: '')).avatarUrl,
        isNull,
      );
      final missing = BusinessProfileResponseDto.fromJson(_profileJson());
      expect(missing.avatarUrl, isNull);
      expect(missing.toJson().containsKey('avatar'), isFalse);
    });
  });

  group('BusinessProfile.withAvatarUrl', () {
    const profile = BusinessProfile(
      id: 1,
      businessName: 'Acme',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
      avatarUrl: 'https://cdn.example/old.png',
    );

    test('sets a new photo and keeps every other field', () {
      final next = profile.withAvatarUrl('https://cdn.example/new.png');
      expect(next.avatarUrl, 'https://cdn.example/new.png');
      expect(next.businessName, 'Acme');
      expect(next.id, 1);
      expect(next == profile, isFalse);
    });

    test('null removes the photo (copyWith cannot)', () {
      expect(profile.withAvatarUrl(null).avatarUrl, isNull);
      expect(profile.copyWith(avatarUrl: null).avatarUrl, profile.avatarUrl);
    });
  });

  group('chat payloads', () {
    test('ConversationParticipantSummary reads avatar', () {
      final withPhoto = ConversationParticipantSummary.fromJson({
        'id': 2,
        'account_type': 'business',
        'display_name': 'Acme',
        'avatar': 'https://cdn.example/a.png',
      });
      final without = ConversationParticipantSummary.fromJson({
        'id': 3,
        'account_type': 'customer',
        'display_name': 'Sam',
        'avatar': null,
      });
      expect(withPhoto.avatarUrl, 'https://cdn.example/a.png');
      expect(without.avatarUrl, isNull);
    });

    test('SharedContent reads business_avatar', () {
      final shared = SharedContent.tryParse({
        'content_type': 'post',
        'object_id': 5,
        'available': true,
        'business_id': 7,
        'business_name': 'Acme',
        'business_avatar': 'https://cdn.example/a.png',
        'preview': null,
      });
      expect(shared?.businessAvatarUrl, 'https://cdn.example/a.png');
    });
  });
}

'@
},
@{ R='end'; P='end'; Eol='LF'; Content='x' }
)
$newFiles = $newFiles | Where-Object { $_.R -ne 'end' }

$arbEn = @'
  "bizAvatarAdd": "Add profile photo",
  "@bizAvatarAdd": {
    "description": "Business forms: button that picks a profile photo when there is none."
  },
  "bizAvatarChange": "Change photo",
  "@bizAvatarChange": {
    "description": "Business forms: button that picks a different profile photo."
  },
  "bizAvatarRemove": "Remove photo",
  "@bizAvatarRemove": {
    "description": "Business forms: button that removes the profile photo."
  },
  "bizAvatarUpdated": "Profile photo updated.",
  "@bizAvatarUpdated": {
    "description": "Snackbar after the business profile photo was uploaded."
  },
  "bizAvatarRemoved": "Profile photo removed.",
  "@bizAvatarRemoved": {
    "description": "Snackbar after the business profile photo was removed."
  },
  "bizAvatarUploadFailed": "Could not update the photo. Please try again.",
  "@bizAvatarUploadFailed": {
    "description": "Snackbar when picking or uploading the profile photo failed."
  },
  "bizAvatarUploadLater": "Your profile was created, but the photo could not be uploaded. You can add it from Edit profile.",
  "@bizAvatarUploadLater": {
    "description": "Snackbar after onboarding when only the photo upload failed."
  },
  "bizAvatarSemantic": "Business profile photo",
  "@bizAvatarSemantic": {
    "description": "Accessibility label of the business profile photo."
  }
'@
$arbAr = @'
  "bizAvatarAdd": "\u0625\u0636\u0627\u0641\u0629 \u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u0644\u0641",
  "bizAvatarChange": "\u062a\u063a\u064a\u064a\u0631 \u0627\u0644\u0635\u0648\u0631\u0629",
  "bizAvatarRemove": "\u0625\u0632\u0627\u0644\u0629 \u0627\u0644\u0635\u0648\u0631\u0629",
  "bizAvatarUpdated": "\u062a\u0645 \u062a\u062d\u062f\u064a\u062b \u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u0644\u0641.",
  "bizAvatarRemoved": "\u062a\u0645\u062a \u0625\u0632\u0627\u0644\u0629 \u0635\u0648\u0631\u0629 \u0627\u0644\u0645\u0644\u0641.",
  "bizAvatarUploadFailed": "\u062a\u0639\u0630\u0651\u0631 \u062a\u062d\u062f\u064a\u062b \u0627\u0644\u0635\u0648\u0631\u0629. \u062d\u0627\u0648\u0644 \u0645\u0631\u0629 \u0623\u062e\u0631\u0649.",
  "bizAvatarUploadLater": "\u062a\u0645 \u0625\u0646\u0634\u0627\u0621 \u0645\u0644\u0641\u0643\u060c \u0644\u0643\u0646 \u062a\u0639\u0630\u0651\u0631 \u0631\u0641\u0639 \u0627\u0644\u0635\u0648\u0631\u0629. \u064a\u0645\u0643\u0646\u0643 \u0625\u0636\u0627\u0641\u062a\u0647\u0627 \u0645\u0646 \u062a\u0639\u062f\u064a\u0644 \u0627\u0644\u0645\u0644\u0641.",
  "bizAvatarSemantic": "\u0635\u0648\u0631\u0629 \u0645\u0644\u0641 \u0627\u0644\u0646\u0634\u0627\u0637 \u0627\u0644\u062a\u062c\u0627\u0631\u064a"
'@

$migTemplate = @'
from django.db import migrations, models


class Migration(migrations.Migration):
    dependencies = [
        ("businesses", "@@DEP@@"),
    ]

    operations = [
        migrations.AddField(
            model_name="businessprofile",
            name="avatar",
            field=models.FileField(
                blank=True, null=True, upload_to="businesses/avatars/"
            ),
        ),
    ]
'@


# ---------------------------------------------------------------- plan (nothing is written here)
$pending = @{}     # full path -> @{Text; Eol}
$problems = @()
$applied = 0; $skipped = 0

foreach ($e in $edits) {
  $full = Join-Path $roots[$e.R] $e.P
  if (-not (Test-Path $full)) { $problems += "Missing file: $full"; continue }
  if (-not $pending.ContainsKey($full)) { $pending[$full] = Read-Lf $full }
  $t = $pending[$full].Text
  $old = Norm $e.Old; $new = Norm $e.New
  $n = Count-Occ $t $old
  if ($n -eq 1) { $pending[$full].Text = $t.Replace($old, $new); $applied++ }
  elseif ($n -eq 0 -and (Count-Occ $t $new) -ge 1) { $skipped++ }
  else {
    $first = ($old -split "`n")[0]
    $problems += "Edit does not match ($n matches) in $($e.P)  -> starts with: $first"
  }
}

foreach ($f in $newFiles) {
  $full = Join-Path $roots[$f.R] $f.P
  if (Test-Path $full) { Write-Host "  exists, skipped: $($f.P)"; continue }
  $eol = if ($f.Eol -eq 'CRLF') { "`r`n" } else { "`n" }
  $pending[$full] = @{ Text = (Norm $f.Content); Eol = $eol; IsNew = $true }
}

# migration (number and dependency are computed from YOUR migrations folder)
$migDir = Join-Path $BackendRoot 'businesses\migrations'
$migs = Get-ChildItem $migDir -Filter '*.py' | Where-Object { $_.Name -match '^\d{4}_.*\.py$' } | Sort-Object Name
if ($migs | Where-Object { $_.Name -like '*_businessprofile_avatar.py' }) {
  Write-Host '  migration already present, skipped'
} else {
  $last = $migs[-1].BaseName
  $num = ([int]$last.Substring(0, 4)) + 1
  $name = ('{0:D4}_businessprofile_avatar.py' -f $num)
  $pending[(Join-Path $migDir $name)] = @{ Text = $migTemplate.Replace('@@DEP@@', $last).Replace("`r`n", "`n"); Eol = "`r`n"; IsNew = $true }
  Write-Host "  new migration: $name (depends on $last)"
}

# ARB files: append the new keys before the final }
foreach ($pair in @(@('app_en.arb', $arbEn), @('app_ar.arb', $arbAr))) {
  $full = Join-Path $MobileRoot ('lib\l10n\' + $pair[0])
  if (-not (Test-Path $full)) { $problems += "Missing file: $full"; continue }
  if (-not $pending.ContainsKey($full)) { $pending[$full] = Read-Lf $full }
  $t = $pending[$full].Text
  if ($t.Contains('"bizAvatarAdd"')) { $skipped++; continue }
  $trim = $t.TrimEnd()
  if (-not $trim.EndsWith('}')) { $problems += "Unexpected ending in $($pair[0])"; continue }
  $body = $trim.Substring(0, $trim.Length - 1).TrimEnd()
  $pending[$full].Text = $body + ",`n" + (Norm $pair[1]) + "`n}`n"
}

if ($problems.Count -gt 0) {
  Write-Host ''
  Write-Host 'NOTHING WAS WRITTEN. These edits do not match your local files:' -ForegroundColor Red
  $problems | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
  Write-Host 'Send me those files from your machine and I will adapt the script.'
  exit 1
}

Write-Host ("Plan OK: {0} edits to apply, {1} already applied, {2} files touched/created." -f $applied, $skipped, $pending.Count)
if ($DryRun) { Write-Host 'Dry run: nothing written.'; exit 0 }

# ---------------------------------------------------------------- write
foreach ($full in $pending.Keys) {
  $p = $pending[$full]
  $dir = Split-Path $full -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  $text = $p.Text
  if ($p.Eol -eq "`r`n") { $text = $text.Replace("`n", "`r`n") }
  [System.IO.File]::WriteAllText($full, $text, $utf8)
}
Write-Host 'Files written.' -ForegroundColor Green

# ---------------------------------------------------------------- l10n regeneration
if (Get-Command flutter -ErrorAction SilentlyContinue) {
  Push-Location $MobileRoot
  try { flutter gen-l10n } finally { Pop-Location }
} else {
  Write-Host 'flutter not found in PATH: run `flutter gen-l10n` yourself in the mobile repo.' -ForegroundColor Yellow
}

Write-Host @'

Next steps
  Backend (D:\Cavallo\scd-backend):
    docker compose exec web python manage.py migrate
    docker compose exec web pytest businesses chat search -q
  Mobile (D:\Cavallo\social_commerce_app):
    flutter analyze
    flutter test test/features/business_profile test/features/chat test/features/stories test/features/discover test/features/feed test/l10n
'@