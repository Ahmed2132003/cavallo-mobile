<#
 Cavallo - fix reels playback + video upload.
 Usage (PowerShell), from anywhere:
   .\apply-reels-fix.ps1 -AppRepo "C:\path\cavallo-app" -MobileRepo "C:\path\cavallo-mobile"
 Add -DryRun to only check that every patch applies, without writing anything.
 Safe to run twice: patches already applied are skipped. Originals are saved
 next to each changed file as *.bak_reelsfix.
#>
param(
  [Parameter(Mandatory=$true)][string]$AppRepo,
  [Parameter(Mandatory=$true)][string]$MobileRepo,
  [switch]$DryRun
)
$ErrorActionPreference = 'Stop'
$utf8 = New-Object System.Text.UTF8Encoding($false)
$roots = @{ app = (Resolve-Path $AppRepo).Path; mobile = (Resolve-Path $MobileRepo).Path }
if (-not (Test-Path (Join-Path $roots.app 'manage.py'))) { throw "AppRepo does not look like cavallo-app (no manage.py)." }
if (-not (Test-Path (Join-Path $roots.mobile 'pubspec.yaml'))) { throw "MobileRepo does not look like cavallo-mobile (no pubspec.yaml)." }

function Read-Text($path) {
  $t = [IO.File]::ReadAllText($path, $utf8)
  $crlf = $t.Contains("`r`n")
  return @{ Text = $t.Replace("`r`n", "`n"); Crlf = $crlf }
}
function Write-Text($path, $text, $crlf) {
  if ($DryRun) { return }
  if ($crlf) { $text = $text.Replace("`n", "`r`n") }
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  [IO.File]::WriteAllText($path, $text, $utf8)
}
function Backup($path) {
  if ($DryRun) { return }
  $bak = "$path.bak_reelsfix"
  if ((Test-Path $path) -and -not (Test-Path $bak)) { Copy-Item $path $bak }
}
$script:failed = 0
function Apply-Patch($repo, $rel, $old, $new) {
  $old = $old.Replace("`r`n", "`n"); $new = $new.Replace("`r`n", "`n")
  $path = Join-Path $roots[$repo] $rel
  if (-not (Test-Path $path)) { Write-Host "MISSING  $rel" -ForegroundColor Red; $script:failed++; return }
  $f = Read-Text $path
  $t = $f.Text
  if ($t.Contains($new)) { Write-Host "skip     $rel (already applied)"; return }
  $first = $t.IndexOf($old)
  if ($first -lt 0) { Write-Host "NO MATCH $rel  (file differs from what the patch expects)" -ForegroundColor Red; $script:failed++; return }
  if ($t.IndexOf($old, $first + 1) -ge 0) { Write-Host "AMBIGUOUS $rel" -ForegroundColor Red; $script:failed++; return }
  Backup $path
  Write-Text $path ($t.Substring(0, $first) + $new + $t.Substring($first + $old.Length)) $f.Crlf
  Write-Host "patched  $rel" -ForegroundColor Green
}
function Append-Once($repo, $rel, $marker, $text) {
  $path = Join-Path $roots[$repo] $rel
  if (-not (Test-Path $path)) { Write-Host "MISSING  $rel" -ForegroundColor Red; $script:failed++; return }
  $f = Read-Text $path
  if ($f.Text.Contains($marker)) { Write-Host "skip     $rel (already applied)"; return }
  Backup $path
  Write-Text $path ($f.Text.TrimEnd("`n") + "`n`n" + $text.Replace("`r`n", "`n") + "`n") $f.Crlf
  Write-Host "patched  $rel (appended helper)" -ForegroundColor Green
}
function Add-ArbKeys($repo) {
  $files = Get-ChildItem -Path (Join-Path $roots[$repo] 'lib') -Recurse -Filter 'app_*.arb' -ErrorAction SilentlyContinue
  if (-not $files) { Write-Host "NO ARB  no app_*.arb found" -ForegroundColor Red; $script:failed++; return }
  $en = [ordered]@{
    reelPlayerMute  = @('Mute', 'Tooltip of the mute button on the full-screen reel player.')
    reelPlayerUnmute = @('Unmute', 'Tooltip of the unmute button on the full-screen reel player.')
    reelPlayerError = @('Could not play this video.', 'Shown over the reel player when the video fails to load, next to a Retry button.')
    reelFormUploading = @('Uploading your video... large videos can take a few minutes. Please keep this screen open.', 'Hint shown under the reel form while the video is uploading.')
  }
  $ar = @{
    reelPlayerMute  = [regex]::Unescape('\u0643\u062A\u0645 \u0627\u0644\u0635\u0648\u062A')
    reelPlayerUnmute = [regex]::Unescape('\u062A\u0634\u063A\u064A\u0644 \u0627\u0644\u0635\u0648\u062A')
    reelPlayerError = [regex]::Unescape('\u062A\u0639\u0630\u0651\u0631 \u062A\u0634\u063A\u064A\u0644 \u0647\u0630\u0627 \u0627\u0644\u0641\u064A\u062F\u064A\u0648.')
    reelFormUploading = [regex]::Unescape('\u062C\u0627\u0631\u064D \u0631\u0641\u0639 \u0627\u0644\u0641\u064A\u062F\u064A\u0648... \u0642\u062F \u064A\u0633\u062A\u063A\u0631\u0642 \u0627\u0644\u0641\u064A\u062F\u064A\u0648 \u0627\u0644\u0643\u0628\u064A\u0631 \u0628\u0636\u0639 \u062F\u0642\u0627\u0626\u0642. \u0623\u0628\u0642\u0650 \u0647\u0630\u0647 \u0627\u0644\u0634\u0627\u0634\u0629 \u0645\u0641\u062A\u0648\u062D\u0629.')
  }
  foreach ($file in $files) {
    $f = Read-Text $file.FullName
    if ($f.Text.Contains('"reelPlayerMute"')) { Write-Host "skip     $($file.Name) (keys already there)"; continue }
    $isAr = $file.Name -match '^app_ar'
    $body = $f.Text.TrimEnd()
    if (-not $body.EndsWith('}')) { Write-Host "BAD ARB  $($file.Name)" -ForegroundColor Red; $script:failed++; continue }
    $body = $body.Substring(0, $body.Length - 1).TrimEnd()
    $add = ''
    foreach ($k in $en.Keys) {
      $val = if ($isAr) { $ar[$k] } else { $en[$k][0] }
      $valJson = ($val | ConvertTo-Json -Compress)
      $descJson = ($en[$k][1] | ConvertTo-Json -Compress)
      $add += ",`n  `"$k`": $valJson,`n  `"@$k`": {`n    `"description`": $descJson`n  }"
    }
    Backup $file.FullName
    Write-Text $file.FullName ($body + $add + "`n}`n") $f.Crlf
    Write-Host "patched  $($file.Name) (+4 reel player keys)" -ForegroundColor Green
  }
}
function Put-File($repo, $rel, $content, $requires = '') {
  $content = $content.Replace("`r`n", "`n")
  $path = Join-Path $roots[$repo] $rel
  $crlf = $false
  if (Test-Path $path) {
    $cur = Read-Text $path
    if ($cur.Text -eq $content) { Write-Host "skip     $rel (identical)"; return }
    if ($requires -ne '' -and -not $cur.Text.Contains($requires)) { Write-Host "CHANGED  $rel (expected marker '$requires' not found - already modified? not overwritten)" -ForegroundColor Red; $script:failed++; return }
    $crlf = $cur.Crlf
    Backup $path
  }
  Write-Text $path $content $crlf
  Write-Host "wrote    $rel" -ForegroundColor Green
}
$old = @'
from core.media import validate_upload
'@
$new = @'
from core.media import validate_upload
from core.video_validation import validate_video_upload
'@
Apply-Patch 'app' 'content/serializers.py' $old $new
$old = @'
    def validate_video(self, value):
'@
$new = @'
    def validate_video(self, value):
        # Accept any real video (phone formats included) up to
        # settings.REEL_MAX_UPLOAD_BYTES; transcode_reel normalises it to MP4.
        validate_video_upload(value)
        return value

    def _legacy_validate_video(self, value):
'@
Apply-Patch 'app' 'content/serializers.py' $old $new
$old = @'
FFMPEG_TIMEOUT_SECONDS = 300  # Generous ceiling for a single Reel's transcode.
'@
$new = @'
FFMPEG_TIMEOUT_SECONDS = 1800  # Long phone videos need far more than 5 minutes.
'@
Apply-Patch 'app' 'content/tasks.py' $old $new
$old = @'
                    "-vf",
'@
$new = @'
                    "-map",
                    "0:v:0",
                    "-map",
                    "0:a:0?",
                    "-sn",
                    "-dn",
                    "-vf",
'@
Apply-Patch 'app' 'content/tasks.py' $old $new
$old = @'
            # 4. Real duration via ffprobe (never trust client-supplied
'@
$new = @'
            # 3b. Clips shorter than THUMBNAIL_SECOND produce no frame at
            #     all (ffmpeg exits 0 but writes nothing) - retry at 0s so
            #     such a reel does not end up FAILED for lack of a thumbnail.
            if not thumbnail_path.exists():
                subprocess.run(
                    [
                        "ffmpeg", "-y", "-ss", "0", "-i", str(output_path),
                        "-frames:v", "1", str(thumbnail_path),
                    ],
                    check=True,
                    capture_output=True,
                    timeout=FFMPEG_TIMEOUT_SECONDS,
                )

            # 4. Real duration via ffprobe (never trust client-supplied
'@
Apply-Patch 'app' 'content/tasks.py' $old $new
$old = @'
STATIC_ROOT = BASE_DIR / "staticfiles"
'@
$new = @'
STATIC_ROOT = BASE_DIR / "staticfiles"

# Reel video upload ceiling (bytes). Was a hard-coded 100 MB, which rejected
# ordinary phone videos. Override with REEL_MAX_UPLOAD_BYTES in .env.
# NOTE: a reverse proxy in front of Django (nginx: client_max_body_size,
# Cloudflare plan limits, ...) must allow at least this much too.
REEL_MAX_UPLOAD_BYTES = env.int("REEL_MAX_UPLOAD_BYTES", default=2 * 1024 * 1024 * 1024)
'@
Apply-Patch 'app' 'config/settings/base.py' $old $new
$old = @'
  fl_chart: 1.0.0
'@
$new = @'
  fl_chart: 1.0.0

  # Real video playback for Reels (replaces the old "Coming soon" stub) and
  # the inline preview in the reel upload form. Caret on purpose: pub picks the
  # newest release whose SDK floor fits this project's Flutter/Dart.
  video_player: ^2.9.2
'@
Apply-Patch 'mobile' 'pubspec.yaml' $old $new
$old = @'
    final response = await _dio.post<Map<String, dynamic>>(
      _reelsPath,
      data: data,
    );
'@
$new = @'
    // The app-wide Dio timeouts are 15 s, which aborts any real video upload
    // (and the server also needs time to store the file before answering).
    final response = await _dio.post<Map<String, dynamic>>(
      _reelsPath,
      data: data,
      options: Options(
        sendTimeout: const Duration(minutes: 30),
        receiveTimeout: const Duration(minutes: 30),
      ),
    );
'@
Apply-Patch 'mobile' 'lib/features/content/data/reel_repository_impl.dart' $old $new
$old = @'
        final retryOptions =
            err.requestOptions
              ..headers['Authorization'] = 'Bearer $newAccess'
              ..extra[_retriedFlag] = true;
'@
$new = @'
        final retryOptions =
            err.requestOptions
              ..headers['Authorization'] = 'Bearer $newAccess'
              ..extra[_retriedFlag] = true
              ..data = _freshBody(err.requestOptions.data);
'@
Apply-Patch 'mobile' 'lib/core/network/interceptors/refresh_interceptor.dart' $old $new
$old = @'
    final retryOptions = err.requestOptions..extra[_retriedFlag] = true;
'@
$new = @'
    final retryOptions = err.requestOptions
      ..extra[_retriedFlag] = true
      ..data = _freshBody(err.requestOptions.data);
'@
Apply-Patch 'mobile' 'lib/core/network/interceptors/refresh_interceptor.dart' $old $new
$old = @'
        android:label="Social Commerce App"
'@
$new = @'
        android:label="Social Commerce App"
        android:usesCleartextTraffic="true"
'@
Apply-Patch 'mobile' 'android/app/src/main/AndroidManifest.xml' $old $new
$old = @'
</dict>
</plist>
'@
$new = @'
	<key>NSAppTransportSecurity</key>
	<dict>
		<key>NSAllowsArbitraryLoadsForMedia</key>
		<true/>
	</dict>
</dict>
</plist>
'@
Apply-Patch 'mobile' 'ios/Runner/Info.plist' $old $new
$content = @'
"""
Permissive-but-safe validation for user-uploaded VIDEO (Reels).

Why this exists: ``core.media.validate_upload`` is an allow-list of exact
MIME types. For video that rejects perfectly good phone recordings (3GP,
M4V, MKV, AVI, MP4 files whose brand libmagic reports as
``application/octet-stream`` ...) and caps the size at 100 MB, which a
one-minute 4K clip already exceeds.

Rules here:
  1. Size ceiling comes from ``settings.REEL_MAX_UPLOAD_BYTES`` (default 2 GB).
  2. Anything libmagic sniffs as ``video/*`` is accepted.
  3. If libmagic says something ambiguous (octet-stream, application/mp4, ...)
     the file is probed with ffprobe and accepted only if it really contains a
     video stream. An executable renamed to .mp4 is still rejected.
The real format normalisation happens later in ``content.tasks.transcode_reel``
(everything becomes H.264/AAC MP4), so accepting more input formats is safe.
"""

import json
import os
import shutil
import subprocess
import tempfile

import magic
from django.conf import settings
from django.core.exceptions import ValidationError

_SNIFF_BYTES = 4096
_AMBIGUOUS_MIME_TYPES = {
    "application/octet-stream",
    "application/mp4",
    "application/x-matroska",
    "application/ogg",
    "application/vnd.apple.mpegurl",
    "audio/mp4",
    "audio/x-m4a",
}
_PROBE_TIMEOUT_SECONDS = 30


def _max_bytes():
    return int(getattr(settings, "REEL_MAX_UPLOAD_BYTES", 2 * 1024 * 1024 * 1024))


def _has_video_stream(file):
    """True iff ffprobe finds at least one video stream in ``file``."""
    path = None
    cleanup = None
    try:
        temp_path = getattr(file, "temporary_file_path", None)
        if callable(temp_path):
            path = temp_path()
        else:
            handle = tempfile.NamedTemporaryFile(delete=False)
            cleanup = handle.name
            file.seek(0)
            shutil.copyfileobj(file, handle)
            handle.close()
            path = handle.name
        result = subprocess.run(
            [
                "ffprobe", "-v", "error", "-select_streams", "v:0",
                "-show_entries", "stream=codec_type", "-of", "json", path,
            ],
            capture_output=True,
            text=True,
            timeout=_PROBE_TIMEOUT_SECONDS,
        )
        if result.returncode != 0:
            return False
        streams = json.loads(result.stdout or "{}").get("streams", [])
        return any(s.get("codec_type") == "video" for s in streams)
    except (OSError, ValueError, subprocess.SubprocessError):
        return False
    finally:
        file.seek(0)
        if cleanup and os.path.exists(cleanup):
            os.unlink(cleanup)


def validate_video_upload(file):
    """Raise Django ``ValidationError`` unless ``file`` is a real video."""
    max_size = _max_bytes()
    size = getattr(file, "size", None)
    if size is None:
        pos = file.tell()
        file.seek(0, 2)
        size = file.tell()
        file.seek(pos)

    if size > max_size:
        raise ValidationError(
            "Video is too large (%(size)d MB). Maximum allowed size is "
            "%(max_size)d MB.",
            code="file_too_large",
            params={"size": size // (1024 * 1024), "max_size": max_size // (1024 * 1024)},
        )

    file.seek(0)
    head = file.read(_SNIFF_BYTES)
    file.seek(0)
    detected = magic.from_buffer(head, mime=True)

    if detected.startswith("video/"):
        return
    if detected in _AMBIGUOUS_MIME_TYPES and _has_video_stream(file):
        return

    raise ValidationError(
        "Unsupported file type: %(detected_mime)s. Please upload a video file.",
        code="unsupported_file_type",
        params={"detected_mime": detected},
    )
'@
Put-File 'app' 'core/video_validation.py' ($content + "`n") ''
$content = @'
"""Tests for core.video_validation.validate_video_upload (reel upload fix)."""

import os

import pytest
from django.core.exceptions import ValidationError
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings

from core.video_validation import validate_video_upload

_FIXTURE = os.path.join(os.path.dirname(__file__), "fixtures", "small_test_reel.mp4")
with open(_FIXTURE, "rb") as _f:
    _MP4 = _f.read()


def _upload(name, data, ctype="video/mp4"):
    return SimpleUploadedFile(name, data, content_type=ctype)


def test_real_mp4_is_accepted():
    validate_video_upload(_upload("a.mp4", _MP4))


def test_wrong_extension_and_content_type_still_accepted_when_really_video():
    validate_video_upload(_upload("clip.bin", _MP4, "application/octet-stream"))


def test_file_position_is_reset():
    f = _upload("a.mp4", _MP4)
    validate_video_upload(f)
    assert f.tell() == 0


def test_disguised_executable_is_rejected():
    exe = b"MZ\x90\x00\x03\x00\x00\x00" + b"\x00" * 600
    with pytest.raises(ValidationError) as exc:
        validate_video_upload(_upload("raw.mp4", exe))
    assert exc.value.code == "unsupported_file_type"


def test_plain_text_is_rejected():
    with pytest.raises(ValidationError):
        validate_video_upload(_upload("raw.mp4", b"just text, not a video"))


@override_settings(REEL_MAX_UPLOAD_BYTES=100)
def test_size_ceiling_comes_from_settings():
    with pytest.raises(ValidationError) as exc:
        validate_video_upload(_upload("a.mp4", _MP4))
    assert exc.value.code == "file_too_large"


def test_large_but_under_default_ceiling_is_not_rejected_for_size():
    # 150 MB is above the old 100 MB cap but below the new default.
    big = _MP4 + b"\0" * (150 * 1024 * 1024)
    validate_video_upload(_upload("big.mp4", big))
'@
Put-File 'app' 'content/tests/test_video_validation.py' ($content + "`n") ''
$content = @'
/// Instagram-style video surface for Reels: real playback (autoplay when the
/// page becomes active, loop, tap to pause/resume, thin progress bar you can
/// scrub, spinner while buffering, retry on failure).
///
/// This replaces the old "Video playback - Coming soon" stub on
/// `ReelDetailScreen`. The project had no video package at all before this
/// (`video_player` is now in `pubspec.yaml`).
///
/// Design notes:
/// * The controller is created only while [isActive] is true and disposed as
///   soon as the page goes off-screen, so a long swipe session never keeps
///   more than one hardware decoder alive.
/// * The thumbnail is shown as a poster until the first frame is ready.
/// * Portrait videos fill the screen (cover); landscape/square videos are
///   letterboxed (contain) so nothing important is cropped.
/// * Backend media URLs are presigned and expire after one hour. If playback
///   fails, Retry first asks [onRefreshUrl] for a fresh URL (when provided)
///   and then re-initialises the player.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_context.dart';

/// Builds the controller for a network [uri]. Injectable so tests never have
/// to touch the real platform video plugin.
typedef ReelControllerFactory = VideoPlayerController Function(Uri uri);

VideoPlayerController _defaultControllerFactory(Uri uri) {
  return VideoPlayerController.networkUrl(uri);
}

class ReelVideoPlayer extends StatefulWidget {
  const ReelVideoPlayer({
    super.key,
    required this.videoUrl,
    required this.isActive,
    this.thumbnailUrl,
    this.muted = false,
    this.onRefreshUrl,
    this.controllerFactory,
  });

  final String? videoUrl;
  final String? thumbnailUrl;

  /// Only the active page plays. Becoming inactive disposes the controller.
  final bool isActive;

  final bool muted;

  /// Optional: returns a fresh (not yet expired) video URL, or null.
  final Future<String?> Function()? onRefreshUrl;

  final ReelControllerFactory? controllerFactory;

  @override
  State<ReelVideoPlayer> createState() => _ReelVideoPlayerState();
}

class _ReelVideoPlayerState extends State<ReelVideoPlayer>
    with WidgetsBindingObserver {
  VideoPlayerController? _controller;
  String? _url;

  bool _starting = false;
  bool _failed = false;
  bool _buffering = false;
  bool _playing = false;
  bool _userPaused = false;
  bool _foreground = true;

  // Bumped on every stop/restart so results of an in-flight initialise()
  // that belong to an older controller are ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _url = widget.videoUrl;
    if (widget.isActive) {
      unawaited(_start());
    }
  }

  @override
  void didUpdateWidget(covariant ReelVideoPlayer oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.videoUrl != oldWidget.videoUrl) {
      _url = widget.videoUrl;
      _stop();
      _failed = false;
      _userPaused = false;
      if (widget.isActive) {
        unawaited(_start());
      }
      return;
    }

    if (widget.isActive != oldWidget.isActive) {
      _userPaused = false;
      if (widget.isActive) {
        unawaited(_start());
      } else {
        _stop();
      }
    }

    if (widget.muted != oldWidget.muted) {
      final controller = _controller;
      if (controller != null && controller.value.isInitialized) {
        unawaited(controller.setVolume(widget.muted ? 0.0 : 1.0));
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stop();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final foreground = state == AppLifecycleState.resumed;
    if (foreground == _foreground) return;
    _foreground = foreground;
    _applyPlayback();
  }

  /// Creates and initialises the controller. Synchronous part only assigns
  /// fields (safe from initState/didUpdateWidget, a build always follows);
  /// everything after the first await goes through setState guarded by
  /// [_generation].
  Future<void> _start() async {
    if (_controller != null) {
      _applyPlayback();
      return;
    }

    final url = _url;
    final uri = (url == null || url.isEmpty) ? null : Uri.tryParse(url);
    if (uri == null) {
      _failed = true;
      return;
    }

    final generation = ++_generation;
    _failed = false;
    _starting = true;

    final factory = widget.controllerFactory ?? _defaultControllerFactory;
    final controller = factory(uri);
    _controller = controller;

    try {
      await controller.initialize();
      if (generation != _generation) return;

      await controller.setLooping(true);
      await controller.setVolume(widget.muted ? 0.0 : 1.0);
      if (generation != _generation) return;

      controller.addListener(_onControllerTick);
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = controller.value.hasError;
      });
      _applyPlayback();
    } catch (_) {
      if (generation != _generation) return;
      if (!mounted) return;
      setState(() {
        _starting = false;
        _failed = true;
      });
    }
  }

  /// Tears the controller down (no setState: callers are either about to
  /// rebuild anyway or are disposing).
  void _stop() {
    _generation++;
    _starting = false;
    _buffering = false;
    _playing = false;

    final old = _controller;
    _controller = null;
    if (old != null) {
      old.removeListener(_onControllerTick);
      unawaited(old.dispose().catchError((Object _) {}));
    }
  }

  void _applyPlayback() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (widget.isActive && !_userPaused && _foreground) {
      unawaited(controller.play());
    } else {
      unawaited(controller.pause());
    }
  }

  void _onControllerTick() {
    final controller = _controller;
    if (controller == null || !mounted) return;

    final value = controller.value;
    final buffering = value.isBuffering;
    final playing = value.isPlaying;
    final failed = value.hasError;

    if (buffering != _buffering || playing != _playing || failed != _failed) {
      setState(() {
        _buffering = buffering;
        _playing = playing;
        _failed = failed;
      });
    }
  }

  void _togglePlay() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;

    if (controller.value.isPlaying) {
      setState(() => _userPaused = true);
      unawaited(controller.pause());
    } else {
      setState(() => _userPaused = false);
      unawaited(controller.play());
    }
  }

  Future<void> _retry() async {
    String? fresh;
    final refresh = widget.onRefreshUrl;
    if (refresh != null) {
      try {
        fresh = await refresh();
      } catch (_) {
        fresh = null;
      }
    }
    if (!mounted) return;

    _stop();
    if (fresh != null && fresh.isNotEmpty) {
      _url = fresh;
    }
    setState(() {
      _failed = false;
      _userPaused = false;
    });
    if (widget.isActive) {
      unawaited(_start());
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final ready =
        controller != null && controller.value.isInitialized && !_failed;
    final thumbnail = widget.thumbnailUrl;
    final showSpinner = !_failed && (_starting || (ready && _buffering));

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _togglePlay,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (!ready && thumbnail != null && thumbnail.isNotEmpty)
            Image.network(
              thumbnail,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          if (ready) _buildVideo(controller!),
          if (showSpinner)
            const Center(
              child: SizedBox(
                width: 36,
                height: 36,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          if (ready)
            IgnorePointer(
              child: Center(
                child: AnimatedOpacity(
                  opacity: _userPaused ? 1 : 0,
                  duration: const Duration(milliseconds: 150),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                    ),
                    padding: const EdgeInsets.all(16),
                    child: const Icon(
                      Icons.play_arrow,
                      color: Colors.white,
                      size: 56,
                    ),
                  ),
                ),
              ),
            ),
          if (_failed) _buildError(),
          if (ready)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VideoProgressIndicator(
                controller!,
                allowScrubbing: true,
                padding: EdgeInsets.zero,
                colors: const VideoProgressColors(
                  playedColor: Colors.white,
                  bufferedColor: Colors.white38,
                  backgroundColor: Colors.white24,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo(VideoPlayerController controller) {
    final size = controller.value.size;
    if (size.isEmpty) {
      return Center(
        child: AspectRatio(
          aspectRatio: controller.value.aspectRatio,
          child: VideoPlayer(controller),
        ),
      );
    }

    final landscape = size.width > size.height;
    return FittedBox(
      fit: landscape ? BoxFit.contain : BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: size.width,
        height: size.height,
        child: VideoPlayer(controller),
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline, color: Colors.white70, size: 40),
          const SizedBox(height: 8),
          Text(
            context.l10n.reelPlayerError,
            style: const TextStyle(color: Colors.white),
          ),
          const SizedBox(height: 12),
          FilledButton.tonal(
            key: const Key('reelPlayer_retryButton'),
            onPressed: _retry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}
'@
Put-File 'mobile' 'lib/features/content/presentation/reel_video_player.dart' ($content + "`n") ''
$content = @'
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/network/paginated_response.dart';
import '../../../core/widgets/cavallo_app_bar.dart';
import '../../../core/widgets/empty_state_widget.dart';
import '../../../core/widgets/error_state_widget.dart';
import '../../../core/widgets/loading_indicator.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';
import '../../social/presentation/comments_section.dart';
import '../../social/presentation/content_action_row.dart';
import '../../social/presentation/content_overflow_menu.dart';
import '../data/dtos/reel_public_response_dto.dart';
import '../data/reel_public_repository.dart';
import '../domain/public_reel_entity.dart';
import 'content_public_providers.dart';
import 'reel_video_player.dart';

/// The customer-facing Reel screen behind `/reel/:id`.
///
/// Reels playback fix: this screen used to show the thumbnail with a fake
/// play button ("coming soon") because the project had no video package. It
/// is now an Instagram-style Reels viewer:
///
/// * Full-screen vertical pager. The reel you tapped is page 0; more
///   published reels (`GET /api/v1/reels/public/`, cursor-paginated) are
///   appended below it and loaded lazily while you swipe.
/// * The active page autoplays with sound, loops, tap pauses/resumes, a thin
///   progress bar can be scrubbed, a mute button sits in the top bar.
/// * Like / comment / share / save reuse the app's own [ContentActionRow]
///   (same optimistic state as the cards), comments open in the existing
///   bottom sheet ([showCommentsSheet]), Report stays in the "..." menu.
///
/// Not-found / error / loading states are unchanged.
class ReelDetailScreen extends ConsumerWidget {
  const ReelDetailScreen({super.key, required this.reelId});

  /// The raw `:id` path parameter, as `go_router` hands it over.
  final String reelId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = int.tryParse(reelId);
    if (id == null) {
      return Scaffold(
        appBar: CavalloAppBar(title: Text(context.l10n.consoleTypeReel)),
        body: const SafeArea(child: _NotFoundView()),
      );
    }

    final reelAsync = ref.watch(reelPublicDetailProvider(id));

    if (reelAsync case AsyncData(value: final PublicReel reel)) {
      return _ReelViewer(initialReel: reel);
    }

    return Scaffold(
      appBar: CavalloAppBar(title: Text(context.l10n.consoleTypeReel)),
      body: switch (reelAsync) {
        AsyncData(value: null) => const _NotFoundView(),
        AsyncError(:final error) => _LoadErrorView(error: error, id: id),
        _ => const LoadingIndicator(),
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Injection points (tests override these; production uses the defaults).
// ---------------------------------------------------------------------------

/// Loads one page of the public reels list. `cursorUrl == null` is the first
/// page; afterwards the `next` URL of the previous page is passed back as is.
typedef ReelFeedLoader =
    Future<PaginatedResponse<PublicReel>> Function({String? cursorUrl});

final reelFeedLoaderProvider = Provider<ReelFeedLoader>((ref) {
  final dio = ref.watch(dioClientProvider);
  return ({String? cursorUrl}) async {
    final response = await dio.get<Map<String, dynamic>>(
      cursorUrl ?? '/api/v1/reels/public/',
    );
    return PaginatedResponse.fromJson<PublicReel>(
      response.data!,
      (json) => ReelPublicResponseDto.fromJson(json).toEntity(),
    );
  };
});

/// Everything the video surface of one page needs.
class ReelPlayerArgs {
  const ReelPlayerArgs({
    required this.reel,
    required this.isActive,
    required this.muted,
    required this.onRefreshUrl,
  });

  final PublicReel reel;
  final bool isActive;
  final bool muted;
  final Future<String?> Function() onRefreshUrl;
}

typedef ReelPlayerBuilder =
    Widget Function(BuildContext context, ReelPlayerArgs args);

/// Builds the video surface of a page. Overridden in widget tests so they
/// never touch the platform video plugin.
final reelPlayerBuilderProvider = Provider<ReelPlayerBuilder>((ref) {
  return (context, args) => ReelVideoPlayer(
    key: ValueKey('reelPlayer_${args.reel.id}'),
    videoUrl: args.reel.videoUrl,
    thumbnailUrl: args.reel.thumbnailUrl,
    isActive: args.isActive,
    muted: args.muted,
    onRefreshUrl: args.onRefreshUrl,
  );
});

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class _NotFoundView extends StatelessWidget {
  const _NotFoundView();

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      message: context.l10n.contentReelNotFound,
      icon: Icons.movie_outlined,
    );
  }
}

class _LoadErrorView extends ConsumerWidget {
  const _LoadErrorView({required this.error, required this.id});

  final Object error;
  final int id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final message = switch (error) {
      DioException(error: final ApiFailure failure) => failure.message,
      ApiFailure(:final message) => message,
      _ => context.l10n.reelLoadError,
    };

    return ErrorStateWidget(
      message: message,
      onRetry: () => ref.invalidate(reelPublicDetailProvider(id)),
    );
  }
}

// ---------------------------------------------------------------------------
// The vertical pager
// ---------------------------------------------------------------------------

class _ReelViewer extends ConsumerStatefulWidget {
  const _ReelViewer({required this.initialReel});

  final PublicReel initialReel;

  @override
  ConsumerState<_ReelViewer> createState() => _ReelViewerState();
}

class _ReelViewerState extends ConsumerState<_ReelViewer> {
  final PageController _pageController = PageController();
  late final List<PublicReel> _reels;

  String? _nextCursor;
  bool _loadingMore = false;
  bool _exhausted = false;
  int _index = 0;
  bool _muted = false;

  @override
  void initState() {
    super.initState();
    _reels = [widget.initialReel];
    Future.microtask(_loadMore);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _loadMore() async {
    if (_loadingMore || _exhausted || !mounted) return;
    _loadingMore = true;
    try {
      final page = await ref.read(reelFeedLoaderProvider)(
        cursorUrl: _nextCursor,
      );
      if (!mounted) return;
      setState(() {
        final known = _reels.map((r) => r.id).toSet();
        for (final reel in page.results) {
          final hasVideo = (reel.videoUrl ?? '').isNotEmpty;
          if (hasVideo && known.add(reel.id)) {
            _reels.add(reel);
          }
        }
        _nextCursor = page.next;
        _exhausted = page.next == null;
      });
    } catch (_) {
      // Best effort: the tapped reel is already playable. The next page
      // change tries again.
    } finally {
      _loadingMore = false;
    }
  }

  /// Media URLs are presigned and expire; re-fetching the reel gives a fresh
  /// one for the player's Retry button.
  Future<String?> _refreshUrl(int reelId) async {
    final fresh = await ref
        .read(reelPublicRepositoryProvider)
        .fetchPublicReel(reelId);
    return fresh?.videoUrl;
  }

  void _onPageChanged(int index) {
    setState(() => _index = index);
    if (index >= _reels.length - 2) {
      _loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentReel = _reels[_index];
    final canPop = Navigator.of(context).canPop();
    final l10n = context.l10n;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: _reels.length,
              onPageChanged: _onPageChanged,
              itemBuilder: (context, index) {
                final reel = _reels[index];
                return _ReelPage(
                  key: ValueKey('reelPage_${reel.id}'),
                  reel: reel,
                  isActive: index == _index,
                  muted: _muted,
                  onRefreshUrl: () => _refreshUrl(reel.id),
                );
              },
            ),
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    children: [
                      if (canPop)
                        IconButton(
                          icon: const Icon(
                            Icons.arrow_back,
                            color: Colors.white,
                          ),
                          tooltip: MaterialLocalizations.of(
                            context,
                          ).backButtonTooltip,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _muted ? Icons.volume_off : Icons.volume_up,
                          color: Colors.white,
                        ),
                        tooltip: _muted
                            ? l10n.reelPlayerUnmute
                            : l10n.reelPlayerMute,
                        onPressed: () => setState(() => _muted = !_muted),
                      ),
                      Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: Theme.of(context).colorScheme.copyWith(
                            onSurfaceVariant: Colors.white,
                          ),
                        ),
                        child: ContentOverflowMenu(
                          contentType: 'reel',
                          objectId: currentReel.id,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// One page = video + gradient + info + action row
// ---------------------------------------------------------------------------

class _ReelPage extends ConsumerStatefulWidget {
  const _ReelPage({
    super.key,
    required this.reel,
    required this.isActive,
    required this.muted,
    required this.onRefreshUrl,
  });

  final PublicReel reel;
  final bool isActive;
  final bool muted;
  final Future<String?> Function() onRefreshUrl;

  @override
  ConsumerState<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends ConsumerState<_ReelPage>
    with AutomaticKeepAliveClientMixin {
  bool _captionExpanded = false;

  // Keeps the page (and its like/save state) alive while scrolled away. The
  // video controller itself is disposed by the player when the page becomes
  // inactive.
  @override
  bool get wantKeepAlive => true;

  void _openComments() {
    showCommentsSheet(
      context,
      contentType: 'reel',
      objectId: widget.reel.id,
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);

    final reel = widget.reel;
    final playerBuilder = ref.watch(reelPlayerBuilderProvider);
    final theme = Theme.of(context);
    const shadow = [Shadow(blurRadius: 4, color: Colors.black54)];

    final profileAsync = ref.watch(
      businessProfilePublicProvider(reel.businessId),
    );
    final businessName = switch (profileAsync) {
      AsyncData(value: final profile) => profile?.businessName ?? '',
      _ => '',
    };

    final captionStyle = theme.textTheme.bodyMedium?.copyWith(
      color: Colors.white,
      shadows: shadow,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        playerBuilder(
          context,
          ReelPlayerArgs(
            reel: reel,
            isActive: widget.isActive,
            muted: widget.muted,
            onRefreshUrl: widget.onRefreshUrl,
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 320,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.75),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (businessName.isNotEmpty)
                        Row(
                          children: [
                            const CircleAvatar(
                              radius: 14,
                              backgroundColor: Colors.white24,
                              child: Icon(
                                Icons.storefront_outlined,
                                size: 16,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                businessName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  shadows: shadow,
                                ),
                              ),
                            ),
                          ],
                        ),
                      if (reel.caption.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        GestureDetector(
                          onTap: () => setState(
                            () => _captionExpanded = !_captionExpanded,
                          ),
                          child: _captionExpanded
                              ? ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: 160,
                                  ),
                                  child: SingleChildScrollView(
                                    child: Text(
                                      reel.caption,
                                      style: captionStyle,
                                    ),
                                  ),
                                )
                              : Text(
                                  reel.caption,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: captionStyle,
                                ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 4),
                // The app's own action row, recoloured for a dark surface.
                Theme(
                  data: theme.copyWith(
                    colorScheme: theme.colorScheme.copyWith(
                      onSurfaceVariant: Colors.white,
                      onSurface: Colors.white,
                    ),
                    textTheme: theme.textTheme.apply(
                      bodyColor: Colors.white,
                      displayColor: Colors.white,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: ContentActionRow(
                      contentType: 'reel',
                      objectId: reel.id,
                      onCommentTap: _openComments,
                      isLiked: reel.isLiked,
                      isSaved: reel.isSaved,
                      likesCount: reel.likesCount,
                      commentsCount: reel.commentsCount,
                      sharesCount: reel.sharesCount,
                      updatedAt: reel.updatedAt,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
'@
Put-File 'mobile' 'lib/features/content/presentation/reel_detail_screen.dart' ($content + "`n") 'contentReelPlaybackSoon'
$content = @'
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_context.dart';
import '../../../core/network/api_failure.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import 'own_content_provider.dart';
import '../../../core/widgets/cavallo_app_bar.dart';

/// Part P-044 scope: `lib/features/content/presentation/
/// reel_form_screen.dart` - the Reel creation form (caption + required
/// video), calling `OwnContentNotifier.createReel` (STEP 4 of this
/// part) - always a multipart request, since `content.models.Reel.video`
/// is REQUIRED (no `null=True`/`blank=True`, unlike `Post.image`) and
/// `content.serializers.ReelSerializer.validate_video` always runs.
///
/// Create-only, same reasoning as `PostFormScreen` - this part's spec
/// asks only for creation screens, and `ReelDetailView`'s PATCH (Part
/// P-042) has no Flutter caller in this part's scope either.
///
/// ### Upload UX pattern - reused/adapted from `ProductFormScreen`
/// (Part P-033), per this part's own spec, adapted for video:
/// * `image_picker`'s `pickVideo(source: ImageSource.gallery)` - the
///   same package already used for Post's/Product's image picking,
///   just its video-picking method instead of `pickImage`. No new
///   dependency added.
/// * The picked video gets a real inline preview (tap to play/pause,
///   looping, muted) built on `video_player` - the same package the Reel
///   viewer uses - plus the file size. If the preview cannot be created on a
///   device it falls back to a static "video selected" box; uploading is
///   never blocked by the preview.
/// * Large uploads can take minutes: `ReelRepositoryImpl.createReel` uses long
///   per-request timeouts and this screen shows an "uploading" hint.
/// * A Reel has no "existing video" branch to preview either
///   (create-only, same as Post) - the preview only ever has the two
///   states just described (none picked yet / one picked).
/// * Field-level backend errors read from a [ValidationFailure]'s
///   `fields` map, keyed by `content.serializers.ReelSerializer`'s own
///   field names (`caption`, `video`) - same `switch (failure)` shape
///   as `PostFormScreen._submit`'s catch block. A missing video is
///   additionally caught client-side, before ever calling the
///   repository - see [_submit]'s own guard, since `video` has no
///   [TextEditingController]/[FormField] for `Form.validate()` to run
///   against the way [AppTextField]'s caption does.
///
/// ### Navigation - same deliberate, flagged choice as
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
/// (`processing_status: "uploaded"`) - this screen pops immediately
/// after that, on success, without waiting for transcoding.
/// `ContentListScreen`'s own polling (Part P-044 STEP 5, already
/// implemented) is what observes the status progress to `"ready"` once
/// the user is back on that screen - this file has no polling logic of
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
  int? _videoBytes;
  bool _isSubmitting = false;

  /// Backend-driven, field-specific error text - same convention as
  /// `PostFormScreen`'s own `_captionError`/`_imageError` pair, keyed
  /// by `ReelSerializer`'s field names (`caption`, `video`).
  String? _captionError;

  /// Covers BOTH a backend-reported `video` validation error (e.g. an
  /// unsupported format/oversized file, from `ReelSerializer.
  /// validate_video`) AND the purely local "you haven't picked a video
  /// yet" case - shown in the same place either way, see
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
    final file = File(picked.path);
    int? bytes;
    try {
      bytes = await file.length();
    } catch (_) {
      bytes = null;
    }
    if (!mounted) return;
    setState(() {
      _videoFile = file;
      _videoBytes = bytes;
      _videoError = null;
    });
  }

  void _removeVideo() {
    setState(() {
      _videoFile = null;
      _videoBytes = null;
    });
  }

  String _formatSize(int bytes) {
    const mb = 1024 * 1024;
    if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
    return '${(bytes / 1024).toStringAsFixed(0)} KB';
  }

  Future<void> _submit() async {
    setState(() {
      _captionError = null;
      _videoError = null;
      _generalError = null;
    });

    final formValid = _formKey.currentState?.validate() ?? false;
    // `video` has no Form-registered field to carry this error the way
    // `AppTextField`'s `validator` does for `caption` - checked here,
    // explicitly, before ever calling the repository. See this class's
    // module docstring.
    final videoMissing = _videoFile == null;
    if (videoMissing) {
      setState(() => _videoError = context.l10n.reelVideoRequired);
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
          _generalError = context.l10n.commonGenericError;
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
    const previewWidth = 160.0;
    const previewHeight = 240.0;

    Widget preview;
    final videoFile = _videoFile;
    if (videoFile != null) {
      preview = SizedBox(
        width: previewWidth,
        height: previewHeight,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: _PickedVideoPreview(
            key: ValueKey(videoFile.path),
            file: videoFile,
          ),
        ),
      );
    } else {
      preview = Container(
        width: previewWidth,
        height: previewHeight,
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(8),
        ),
        child: const Icon(Icons.video_call_outlined),
      );
    }

    final bytes = _videoBytes;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(context.l10n.contentFormVideoLabel),
        const SizedBox(height: 8),
        preview,
        if (videoFile != null) ...[
          const SizedBox(height: 6),
          Text(
            [
              videoFile.uri.pathSegments.last,
              if (bytes != null) _formatSize(bytes),
            ].join(' - '),
            style: theme.textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 8),
        Row(
          children: [
            TextButton.icon(
              key: const Key('reelForm_pickVideoButton'),
              onPressed: _isSubmitting ? null : _pickVideo,
              icon: const Icon(Icons.video_library_outlined),
              label: Text(
                _videoFile == null
                    ? context.l10n.contentFormChooseVideo
                    : context.l10n.contentFormChangeVideo,
              ),
            ),
            if (_videoFile != null)
              TextButton(
                key: const Key('reelForm_removeVideoButton'),
                onPressed: _isSubmitting ? null : _removeVideo,
                child: Text(context.l10n.commonRemove),
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
      appBar: CavalloAppBar(title: Text(context.l10n.reelFormTitle)),
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
                  label: context.l10n.contentFormCaption,
                  controller: _captionController,
                  maxLines: 4,
                  validator: (value) {
                    if (_captionError != null) return _captionError;
                    if ((value ?? '').trim().isEmpty) {
                      return context.l10n.validationCaptionRequired;
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                _buildVideoPicker(context),
                const SizedBox(height: 8),
                Text(
                  context.l10n.reelFormReviewNote,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                if (_isSubmitting) ...[
                  const SizedBox(height: 12),
                  Text(
                    context.l10n.reelFormUploading,
                    key: const Key('reelForm_uploadingHint'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                if (_generalError != null) ...[
                  const SizedBox(height: 16),
                  Text(
                    _generalError!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                AppButton(
                  key: const Key('reelForm_submitButton'),
                  label: context.l10n.reelFormSubmit,
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

/// Small looping, muted inline preview of the picked local video file.
/// Tap toggles play/pause. Falls back to a static "video selected" tile when
/// the platform cannot create the preview - it only ever affects this
/// preview, never the upload.
class _PickedVideoPreview extends StatefulWidget {
  const _PickedVideoPreview({super.key, required this.file});

  final File file;

  @override
  State<_PickedVideoPreview> createState() => _PickedVideoPreviewState();
}

class _PickedVideoPreviewState extends State<_PickedVideoPreview> {
  VideoPlayerController? _controller;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final controller = VideoPlayerController.file(widget.file);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.setVolume(0);
      if (!mounted) return;
      setState(() {});
      await controller.play();
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _toggle() {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) return;
    if (controller.value.isPlaying) {
      controller.pause();
    } else {
      controller.play();
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = _controller;

    if (_failed || controller == null) {
      return _fallback(theme);
    }
    if (!controller.value.isInitialized) {
      return ColoredBox(
        color: theme.colorScheme.surfaceContainerHighest,
        child: const Center(child: CircularProgressIndicator()),
      );
    }

    final size = controller.value.size;
    return GestureDetector(
      onTap: _toggle,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          FittedBox(
            fit: BoxFit.cover,
            clipBehavior: Clip.hardEdge,
            child: SizedBox(
              width: size.width <= 0 ? 1 : size.width,
              height: size.height <= 0 ? 1 : size.height,
              child: VideoPlayer(controller),
            ),
          ),
          if (!controller.value.isPlaying)
            const Center(
              child: Icon(
                Icons.play_circle_outline,
                color: Colors.white,
                size: 48,
              ),
            ),
        ],
      ),
    );
  }

  Widget _fallback(ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(8),
      color: theme.colorScheme.surfaceContainerHighest,
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
            widget.file.uri.pathSegments.last,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
'@
Put-File 'mobile' 'lib/features/content/presentation/reel_form_screen.dart' ($content + "`n") 'contentFormVideoLabel'
$content = @'
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/network/api_failure.dart';
import 'package:social_commerce_app/core/network/paginated_response.dart';
import 'package:social_commerce_app/core/widgets/app_button.dart';
import 'package:social_commerce_app/features/business_profile/data/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_entity.dart';
import 'package:social_commerce_app/features/business_profile/domain/business_profile_public_repository.dart';
import 'package:social_commerce_app/features/content/data/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/domain/public_reel_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_public_repository.dart';
import 'package:social_commerce_app/features/content/presentation/reel_detail_screen.dart';
import 'package:social_commerce_app/features/social/data/social_interaction_repository_impl.dart';

import '../../social/fake_social_interaction_repository.dart';

/// Part P-045 (STEP 8) scope: widget tests for `ReelDetailScreen`
/// (`/reel/:id`). Same fake-repository shape as
/// `post_detail_screen_test.dart`'s `_FakePostPublicRepository`.
///
/// Part P-058 update: every test also overrides the social repository with
/// a controllable fake, since the screen now contains the real action row,
/// the comments section and a Report menu.
class _FakeReelPublicRepository implements ReelPublicRepository {
  _FakeReelPublicRepository({this.result, this.error, this.pending});

  PublicReel? result;
  Object? error;
  Completer<PublicReel?>? pending;
  int fetchPublicReelCallCount = 0;

  @override
  Future<PublicReel?> fetchPublicReel(int id) async {
    fetchPublicReelCallCount++;
    if (pending != null) {
      return pending!.future;
    }
    if (error != null) {
      throw error!;
    }
    return result;
  }

  // Unused by this screen - implemented to satisfy the interface.
  @override
  Future<PaginatedResponse<PublicReel>> fetchBusinessReels(
    int businessId,
  ) async => const PaginatedResponse<PublicReel>(
    results: [],
    next: null,
    previous: null,
  );
}

class _FakeBusinessProfilePublicRepository
    implements BusinessProfilePublicRepository {
  @override
  Future<BusinessProfile?> fetchPublicProfile(int id) async {
    return BusinessProfile(
      id: id,
      businessName: 'Test Business',
      businessType: BusinessType.trader,
      country: 'Egypt',
      city: 'Cairo',
      isVerified: false,
    );
  }
}

const _reel602 = PublicReel(
  id: 602,
  businessId: 7,
  caption: 'Second reel in the pager.',
  videoUrl: 'https://example.com/reel-602.mp4',
);

const _reelWithoutVideo = PublicReel(
  id: 603,
  businessId: 7,
  caption: 'Has no video url, must never be paged in.',
);

Future<PaginatedResponse<PublicReel>> _emptyPage({String? cursorUrl}) async =>
    const PaginatedResponse<PublicReel>(results: [], next: null, previous: null);

const _reel = PublicReel(
  id: 601,
  businessId: 7,
  caption: 'A published reel, seen at /reel/601.',
  videoUrl: 'https://example.com/reel-601.mp4',
  thumbnailUrl: 'https://example.com/reel-601-thumb.jpg',
  durationSeconds: 125,
);

Future<void> _pumpScreen(
  WidgetTester tester, {
  required String reelId,
  required _FakeReelPublicRepository repository,
  FakeSocialInteractionRepository? social,
  ReelFeedLoader? feedLoader,
}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        reelPublicRepositoryProvider.overrideWithValue(repository),
        socialInteractionRepositoryProvider.overrideWithValue(
          social ?? FakeSocialInteractionRepository(),
        ),
        businessProfilePublicRepositoryProvider.overrideWithValue(
          _FakeBusinessProfilePublicRepository(),
        ),
        reelFeedLoaderProvider.overrideWithValue(feedLoader ?? _emptyPage),
        // The real surface is the platform video plugin; tests use a stub.
        reelPlayerBuilderProvider.overrideWithValue(
          (context, args) => SizedBox.expand(
            child: Center(
              child: Text(
                'player ${args.reel.id} active=${args.isActive} '
                'muted=${args.muted}',
              ),
            ),
          ),
        ),
      ],
      child: MaterialApp(home: ReelDetailScreen(reelId: reelId)),
    ),
  );
}

void main() {
  group('ReelDetailScreen - non-numeric id', () {
    testWidgets(
      'shows not-found immediately, without calling the repository',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(
          tester,
          reelId: 'not-a-number',
          repository: repository,
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Reel not found.\nIt may have been removed.'),
          findsOneWidget,
        );
        expect(repository.fetchPublicReelCallCount, 0);
      },
    );
  });

  group('ReelDetailScreen - loading', () {
    testWidgets('shows a LoadingIndicator before the fetch resolves', (
      tester,
    ) async {
      final completer = Completer<PublicReel?>();
      final repository = _FakeReelPublicRepository(pending: completer);

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byTooltip('More options'), findsNothing);

      completer.complete(_reel);
      await tester.pumpAndSettle();

      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });

  group('ReelDetailScreen - found', () {
    testWidgets(
      'plays the tapped reel and shows business name, caption and actions',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('player 601 active=true muted=false'), findsOneWidget);
        expect(find.text('Test Business'), findsOneWidget);
        expect(
          find.text('A published reel, seen at /reel/601.'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.favorite_border), findsOneWidget);
        expect(find.byTooltip('Like'), findsOneWidget);
        expect(find.byTooltip('Comment'), findsOneWidget);
        expect(find.byTooltip('Share'), findsOneWidget);
        expect(find.byTooltip('Save'), findsOneWidget);

        // The old "coming soon" stub is gone for good.
        expect(find.byIcon(Icons.play_arrow), findsNothing);
      },
    );

    testWidgets('an empty caption shows no caption text', (tester) async {
      final repository = _FakeReelPublicRepository(
        result: const PublicReel(id: 603, businessId: 7, caption: ''),
      );

      await _pumpScreen(tester, reelId: '603', repository: repository);
      await tester.pumpAndSettle();

      expect(find.text('player 603 active=true muted=false'), findsOneWidget);
    });

    testWidgets('the mute button mutes the player and flips its tooltip', (
      tester,
    ) async {
      final repository = _FakeReelPublicRepository(result: _reel);

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Mute'));
      await tester.pumpAndSettle();

      expect(find.text('player 601 active=true muted=true'), findsOneWidget);
      expect(find.byTooltip('Unmute'), findsOneWidget);
    });

    testWidgets(
      'tapping Like shows the liked state immediately, before any response',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);
        final social = FakeSocialInteractionRepository();

        await _pumpScreen(
          tester,
          reelId: '601',
          repository: repository,
          social: social,
        );
        await tester.pumpAndSettle();

        social.gate = Completer<void>();

        await tester.tap(find.byTooltip('Like'));
        await tester.pump();

        expect(find.byIcon(Icons.favorite), findsOneWidget);
        expect(find.byIcon(Icons.favorite_border), findsNothing);

        social.gate!.complete();
        await tester.pumpAndSettle();

        expect(social.calls, contains('like:reel:601'));
      },
    );

    testWidgets('the Comment button opens the comments sheet', (tester) async {
      final repository = _FakeReelPublicRepository(result: _reel);

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Comment'));
      await tester.pumpAndSettle();

      expect(find.text('Comments'), findsWidgets);
      expect(find.byType(TextField), findsOneWidget);
    });

    testWidgets('the "..." menu appears once loaded and reports the Reel', (
      tester,
    ) async {
      final repository = _FakeReelPublicRepository(result: _reel);
      final social = FakeSocialInteractionRepository();

      await _pumpScreen(
        tester,
        reelId: '601',
        repository: repository,
        social: social,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('More options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Report'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Other'));
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, 'Submit'));
      await tester.pumpAndSettle();

      expect(social.calls, contains('report:reel:601:other'));
    });
  });

  group('ReelDetailScreen - vertical pager', () {
    testWidgets(
      'more published reels are appended and swiping up activates the next '
      'one (duplicates and reels without a video are never paged in)',
      (tester) async {
        final repository = _FakeReelPublicRepository(result: _reel);
        final cursorsRequested = <String?>[];

        Future<PaginatedResponse<PublicReel>> loader({
          String? cursorUrl,
        }) async {
          cursorsRequested.add(cursorUrl);
          return const PaginatedResponse<PublicReel>(
            results: [_reel, _reel602, _reelWithoutVideo],
            next: null,
            previous: null,
          );
        }

        await _pumpScreen(
          tester,
          reelId: '601',
          repository: repository,
          feedLoader: loader,
        );
        await tester.pumpAndSettle();

        expect(cursorsRequested, [null]);
        expect(find.text('player 601 active=true muted=false'), findsOneWidget);

        await tester.fling(find.byType(PageView), const Offset(0, -500), 2000);
        await tester.pumpAndSettle();

        expect(find.text('player 602 active=true muted=false'), findsOneWidget);
        expect(find.text('Second reel in the pager.'), findsOneWidget);
        expect(find.textContaining('player 603'), findsNothing);
      },
    );

    testWidgets('a failing "more reels" call never breaks the tapped reel', (
      tester,
    ) async {
      final repository = _FakeReelPublicRepository(result: _reel);

      Future<PaginatedResponse<PublicReel>> failingLoader({
        String? cursorUrl,
      }) async {
        throw const ServerFailure(message: 'boom');
      }

      await _pumpScreen(
        tester,
        reelId: '601',
        repository: repository,
        feedLoader: failingLoader,
      );
      await tester.pumpAndSettle();

      expect(find.text('player 601 active=true muted=false'), findsOneWidget);
    });
  });

  group(
    'ReelDetailScreen - not found (numeric id, real 404 / unpublished / not-ready)',
    () {
      testWidgets(
        'AsyncData(null) shows the not-found state, not a generic error',
        (tester) async {
          final repository = _FakeReelPublicRepository(result: null);

          await _pumpScreen(
            tester,
            reelId: '999999',
            repository: repository,
          );
          await tester.pumpAndSettle();

          expect(
            find.text('Reel not found.\nIt may have been removed.'),
            findsOneWidget,
          );
        },
      );
    },
  );

  group('ReelDetailScreen - error', () {
    testWidgets(
      'a genuine failure shows the backend message and a Retry button',
      (tester) async {
        final repository = _FakeReelPublicRepository(
          error: const ServerFailure(message: 'Something broke.'),
        );

        await _pumpScreen(tester, reelId: '601', repository: repository);
        await tester.pumpAndSettle();

        expect(find.text('Something broke.'), findsOneWidget);
        expect(find.widgetWithText(AppButton, 'Retry'), findsOneWidget);
      },
    );

    testWidgets('tapping Retry re-invokes the repository', (tester) async {
      final repository = _FakeReelPublicRepository(
        error: const ServerFailure(message: 'Something broke.'),
      );

      await _pumpScreen(tester, reelId: '601', repository: repository);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicReelCallCount, 1);

      repository.error = null;
      repository.result = _reel;

      final retryButton = find.widgetWithText(AppButton, 'Retry');
      await tester.ensureVisible(retryButton);
      await tester.pumpAndSettle();

      await tester.tap(retryButton);
      await tester.pumpAndSettle();

      expect(repository.fetchPublicReelCallCount, 2);
      expect(
        find.text('A published reel, seen at /reel/601.'),
        findsOneWidget,
      );
    });
  });
}
'@
Put-File 'mobile' 'test/features/content/presentation/reel_detail_screen_test.dart' ($content + "`n") 'fetchPublicReelCallCount'

$helper = @'
/// A multipart FormData can only be sent once; re-sending the same instance
/// after the token refresh throws "already finalized", which made any upload
/// started with an expired access token fail. A clone is a fresh copy.
dynamic _freshBody(dynamic data) {
  if (data is FormData) {
    return data.clone();
  }
  return data;
}
'@
Add-ArbKeys 'mobile'
Append-Once 'mobile' 'lib/core/network/interceptors/refresh_interceptor.dart' 'dynamic _freshBody(dynamic data)' $helper

if ($script:failed -gt 0) {
  Write-Host "`n$($script:failed) step(s) failed - nothing else was touched for those. Send me the red lines above." -ForegroundColor Red
  exit 1
}
if ($DryRun) { Write-Host "`nDry run OK - every patch applies cleanly." -ForegroundColor Cyan; exit 0 }
Write-Host "`nDone. Next:" -ForegroundColor Cyan
Write-Host "  cd `"$($roots.mobile)`"; flutter pub get; flutter gen-l10n; flutter analyze; flutter test test/features/content"
Write-Host "  backend: add REEL_MAX_UPLOAD_BYTES to .env if you want a different limit, then rebuild/restart web + celery_worker"
Write-Host "  Android/iOS native files changed -> do a full rebuild (stop the app, flutter run again), not hot reload."