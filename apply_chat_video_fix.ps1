<#
.SYNOPSIS
  Cavallo - chat video fix (backend + Flutter). ASCII-only script (safe for
  Windows PowerShell 5.1 regardless of file encoding).

.DESCRIPTION
  1. Chat videos can now be OPENED: tapping a video bubble opens a full-screen
     player (autoplay, pause/resume, scrubbing, retry, "open in another app"
     fallback). Before, a video bubble was a static placeholder icon.
  2. Chat accepts videos in any common format (mp4, mov, mkv, webm, avi, 3gp,
     flv, mpeg, ts, ...) - detected from the real file content, not the
     extension - with a configurable size cap (CHAT_VIDEO_MAX_MB, default 1024).
  3. Chat video upload no longer dies after 15 s (30 min send/receive timeouts).

  SAFE to run: validates EVERY edit first and changes nothing if one anchor is
  missing; keeps a backup (*.bak_chatvideo) next to each edited file; can be
  re-run (already-applied edits are skipped).

.PARAMETER BackendRoot
  Django project root (default D:\Cavallo\scd-backend).
.PARAMETER FlutterRoot
  Flutter project root (default D:\Cavallo\social_commerce_app, branch part-111).
.PARAMETER DryRun
  Validate only, write nothing.
.PARAMETER SkipFlutterCommands
  Do not run `flutter pub get` / `flutter gen-l10n` at the end.
#>
[CmdletBinding()]
param(
    [string]$BackendRoot = 'D:\Cavallo\scd-backend',
    [string]$FlutterRoot = 'D:\Cavallo\social_commerce_app',
    [switch]$DryRun,
    [switch]$SkipFlutterCommands
)

$ErrorActionPreference = 'Stop'

function Read-TextFile {
    param([string]$Path)
    $bytes = [System.IO.File]::ReadAllBytes($Path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    if ($hasBom) {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    } else {
        $text = [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    $crlf = $text.Contains("`r`n")
    $norm = $text.Replace("`r`n", "`n")
    return [pscustomobject]@{ Text = $norm; Crlf = $crlf; Bom = $hasBom }
}

function Write-TextFile {
    param([string]$Path, [string]$Text, [bool]$Crlf, [bool]$Bom)
    if ($Crlf) { $Text = $Text.Replace("`n", "`r`n") }
    $enc = New-Object System.Text.UTF8Encoding($Bom)
    [System.IO.File]::WriteAllText($Path, $Text, $enc)
}

function Get-RootPath {
    param([string]$Root)
    if ($Root -eq 'Backend') { return $BackendRoot }
    return $FlutterRoot
}

# Arabic / special characters are written as {{U+XXXX}} so this script stays
# pure ASCII; they are decoded to real characters at run time.
function Decode-Text {
    param([string]$Text)
    return [regex]::Replace($Text, '\{\{U\+([0-9A-F]{4})\}\}', {
        param($m)
        [string][char][Convert]::ToInt32($m.Groups[1].Value, 16)
    })
}


$Edits = @(
  @{
    Root = 'Backend'
    File = 'config/settings/base.py'
    Marker = '# Chat video size cap, in MB (chat/serializers.py reads it). Chat videos are'
    Old = @'
OBJECT_STORAGE_PUBLIC_ENDPOINT_URL = (
    OBJECT_STORAGE_PUBLIC_ENDPOINT_URL or OBJECT_STORAGE_ENDPOINT_URL
)
'@
    New = @'
OBJECT_STORAGE_PUBLIC_ENDPOINT_URL = (
    OBJECT_STORAGE_PUBLIC_ENDPOINT_URL or OBJECT_STORAGE_ENDPOINT_URL
)

# Chat video size cap, in MB (chat/serializers.py reads it). Chat videos are
# accepted in any common video format, so this one env var is the only knob
# that bounds an upload. Keep it in sync with the Flutter client
# (chat_thread_screen.dart `_maxVideoBytes`) and make sure the reverse proxy
# allows it too (nginx `client_max_body_size`, gunicorn `--timeout`).
CHAT_VIDEO_MAX_MB = env.int("CHAT_VIDEO_MAX_MB", default=1024)
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/serializers.py'
    Marker = 'import tempfile'
    Old = @'
from django.apps import apps
'@
    New = @'
import os
import shutil
import subprocess
import tempfile

from django.apps import apps
from django.conf import settings
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/serializers.py'
    Marker = '#         recognised by its REAL content (libmagic, plus an ffprobe check for'
    Old = @'
# Video:  video/mp4 only, 25 MB. Chat video is NOT transcoded (no ffmpeg
#         pipeline like Reel's), so the stricter 25 MB cap (vs Reel's
#         100 MB) is the chosen alternative to transcoding. To also accept
#         iPhone .mov later, add "video/quicktime" to CHAT_VIDEO_MIME_TYPES.
# ---------------------------------------------------------------------------
CHAT_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
CHAT_IMAGE_MAX_BYTES = 5 * 1024 * 1024
CHAT_VIDEO_MIME_TYPES = ["video/mp4"]
CHAT_VIDEO_MAX_BYTES = 25 * 1024 * 1024
'@
    New = @'
# Video:  any common video container (mp4, mov, mkv, webm, avi, 3gp, ...),
#         recognised by its REAL content (libmagic, plus an ffprobe check for
#         containers libmagic has no signature for) - never by file
#         extension. The size cap is settings.CHAT_VIDEO_MAX_MB (env
#         CHAT_VIDEO_MAX_MB, default 1024 MB). Chat video is stored exactly
#         as uploaded (no transcoding); the Flutter client offers an external
#         player for codecs the phone itself cannot decode.
# ---------------------------------------------------------------------------
CHAT_IMAGE_MIME_TYPES = ["image/jpeg", "image/png", "image/webp"]
CHAT_IMAGE_MAX_BYTES = 5 * 1024 * 1024
CHAT_VIDEO_MIME_TYPES = [
    "video/mp4",
    "video/quicktime",
    "video/webm",
    "video/x-matroska",
    "video/x-msvideo",
    "video/3gpp",
    "video/3gpp2",
    "video/mpeg",
    "video/mp2t",
    "video/x-m4v",
    "video/x-flv",
    "video/x-ms-asf",
    "video/x-ms-wmv",
    "video/ogg",
    "video/x-ogm",
    "video/h264",
    "video/h265",
    "video/hevc",
    "video/avi",
    "video/x-mpeg",
    "video/mj2",
    "video/divx",
]
CHAT_VIDEO_MAX_BYTES = settings.CHAT_VIDEO_MAX_MB * 1024 * 1024

# libmagic's answer when it has no signature for the container (MPEG-TS and
# some camera/exotic formats end up here). It is the ONLY answer that is
# second-guessed with ffprobe; every other type was positively identified
# as "not a video" and stays rejected.
_UNKNOWN_BINARY_MIME = "application/octet-stream"
_FFPROBE_TIMEOUT_SECONDS = 30


def _unknown_binary_is_video(file, exc):
    """
    True only when `exc` says libmagic could not identify the file AND
    ffprobe (already installed for the Reel pipeline) finds a real video
    stream with a positive duration in it.
    """
    params = getattr(exc, "params", None) or {}
    if params.get("detected_mime") != _UNKNOWN_BINARY_MIME:
        return False
    if shutil.which("ffprobe") is None:
        return False

    temp_path = None
    try:
        path_getter = getattr(file, "temporary_file_path", None)
        if callable(path_getter):
            target = path_getter()
        else:
            with tempfile.NamedTemporaryFile(delete=False) as tmp:
                temp_path = tmp.name
                file.seek(0)
                for chunk in file.chunks():
                    tmp.write(chunk)
            target = temp_path
        result = subprocess.run(
            [
                "ffprobe",
                "-v",
                "error",
                "-protocol_whitelist",
                "file",
                "-select_streams",
                "v:0",
                "-show_entries",
                "stream=codec_type:format=duration",
                "-of",
                "default=noprint_wrappers=1",
                target,
            ],
            capture_output=True,
            text=True,
            timeout=_FFPROBE_TIMEOUT_SECONDS,
            check=False,
        )
        if result.returncode != 0:
            return False
        fields = dict(
            line.split("=", 1) for line in result.stdout.splitlines() if "=" in line
        )
        return (
            fields.get("codec_type") == "video"
            and float(fields.get("duration", "0")) > 0
        )
    except (OSError, ValueError, subprocess.SubprocessError):
        return False
    finally:
        file.seek(0)
        if temp_path is not None:
            try:
                os.unlink(temp_path)
            except OSError:
                pass

'@
  }
  @{
    Root = 'Backend'
    File = 'chat/serializers.py'
    Marker = 'if not _unknown_binary_is_video(value, video_exc):'
    Old = @'
            validate_upload(value, CHAT_VIDEO_MIME_TYPES, CHAT_VIDEO_MAX_BYTES)
            self._media_type = Message.MediaType.VIDEO
'@
    New = @'
            try:
                validate_upload(value, CHAT_VIDEO_MIME_TYPES, CHAT_VIDEO_MAX_BYTES)
            except DjangoValidationError as video_exc:
                if not _unknown_binary_is_video(value, video_exc):
                    raise
            self._media_type = Message.MediaType.VIDEO
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/serializers.py'
    Marker = '1) {{U+0646}}{{U+0648}}{{U+0639}} {{U+0635}}{{U+0648}}{{U+0631}}{{U+0629}} + {{U+0633}}{{U+0642}}{{U+0641}} {{U+0627}}{{U+0644}}{{U+0641}}{{U+064A}}{{U+062F}}{{U+064A}}{{U+0648}} (CHAT_VIDEO_MAX_MB)'
    Old = @'
      1) {{U+0646}}{{U+0648}}{{U+0639}} {{U+0635}}{{U+0648}}{{U+0631}}{{U+0629}} + {{U+0633}}{{U+0642}}{{U+0641}} {{U+0627}}{{U+0644}}{{U+0641}}{{U+064A}}{{U+062F}}{{U+064A}}{{U+0648}} (25MB) {{U+2014}} {{U+0646}}{{U+062C}}{{U+062D}} => {{U+0635}}{{U+0648}}{{U+0631}}{{U+0629}}{{U+060C}} {{U+0648}}{{U+0628}}{{U+0639}}{{U+062F}}{{U+0647}}{{U+0627}} {{U+0646}}{{U+0637}}{{U+0628}}{{U+0642}} {{U+0633}}{{U+0642}}{{U+0641}}
'@
    New = @'
      1) {{U+0646}}{{U+0648}}{{U+0639}} {{U+0635}}{{U+0648}}{{U+0631}}{{U+0629}} + {{U+0633}}{{U+0642}}{{U+0641}} {{U+0627}}{{U+0644}}{{U+0641}}{{U+064A}}{{U+062F}}{{U+064A}}{{U+0648}} (CHAT_VIDEO_MAX_MB) {{U+2014}} {{U+0646}}{{U+062C}}{{U+062D}} => {{U+0635}}{{U+0648}}{{U+0631}}{{U+0629}}{{U+060C}} {{U+0648}}{{U+0628}}{{U+0639}}{{U+062F}}{{U+0647}}{{U+0627}} {{U+0646}}{{U+0637}}{{U+0628}}{{U+0642}} {{U+0633}}{{U+0642}}{{U+0641}}
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/serializers.py'
    Marker = '# file_too_large ({{U+0623}}{{U+0643}}{{U+0628}}{{U+0631}} {{U+0645}}{{U+0646}} {{U+0627}}{{U+0644}}{{U+0633}}{{U+0642}}{{U+0641}}'
    Old = @'
                # file_too_large ({{U+0623}}{{U+0643}}{{U+0628}}{{U+0631}} {{U+0645}}{{U+0646}} 25MB {{U+0623}}{{U+064A}}{{U+064B}}{{U+0627}} {{U+0643}}{{U+0627}}{{U+0646}} {{U+0627}}{{U+0644}}{{U+0646}}{{U+0648}}{{U+0639}}) {{U+2014}} {{U+0646}}{{U+0631}}{{U+0641}}{{U+0636}}{{U+0647}} {{U+0643}}{{U+0645}}{{U+0627}} {{U+0647}}{{U+0648}}.
'@
    New = @'
                # file_too_large ({{U+0623}}{{U+0643}}{{U+0628}}{{U+0631}} {{U+0645}}{{U+0646}} {{U+0627}}{{U+0644}}{{U+0633}}{{U+0642}}{{U+0641}} {{U+0623}}{{U+064A}}{{U+064B}}{{U+0627}} {{U+0643}}{{U+0627}}{{U+0646}} {{U+0627}}{{U+0644}}{{U+0646}}{{U+0648}}{{U+0639}}) {{U+2014}} {{U+0646}}{{U+0631}}{{U+0641}}{{U+0636}}{{U+0647}} {{U+0643}}{{U+0645}}{{U+0627}} {{U+0647}}{{U+0648}}.
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/test_media_messages.py'
    Marker = 'video cap), that a media-only message is valid, and that a message with'
    Old = @'
25 MB video), that a media-only message is valid, and that a message with
'@
    New = @'
video cap), that a media-only message is valid, and that a message with
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/test_media_messages.py'
    Marker = 'import subprocess'
    Old = @'
from unittest.mock import patch
'@
    New = @'
import shutil
import subprocess
from unittest.mock import patch
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/test_media_messages.py'
    Marker = 'from django.conf import settings'
    Old = @'
from django.contrib.auth import get_user_model
'@
    New = @'
from django.conf import settings
from django.contrib.auth import get_user_model
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/test_media_messages.py'
    Marker = 'from chat import serializers as chat_serializers'
    Old = @'
from chat.models import Conversation, ConversationParticipant, Message
'@
    New = @'
from chat import serializers as chat_serializers
from chat.models import Conversation, ConversationParticipant, Message
'@
  }
  @{
    Root = 'Backend'
    File = 'chat/test_media_messages.py'
    Marker = 'def test_container_libmagic_cannot_name_is_accepted_when_ffprobe_sees_video(tmp_path):'
    Old = @'
def test_video_over_25mb_is_rejected():
    client, url, conversation, _, _ = _setup("big_vid")

    response = client.post(url, {"media": _mp4(extra=25 * _MB)}, format="multipart")

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["error"]["code"] == "VALIDATION_ERROR"
    assert not Message.objects.filter(conversation=conversation).exists()
'@
    New = @'
def test_video_cap_comes_from_settings_and_is_far_above_25mb():
    assert chat_serializers.CHAT_VIDEO_MAX_BYTES == (
        settings.CHAT_VIDEO_MAX_MB * 1024 * 1024
    )
    assert chat_serializers.CHAT_VIDEO_MAX_BYTES > 25 * _MB


def test_video_over_the_configured_cap_is_rejected(monkeypatch):
    # Shrink the cap so the test never has to build a gigabyte-sized upload.
    monkeypatch.setattr(chat_serializers, "CHAT_VIDEO_MAX_BYTES", 8 * _MB)
    client, url, conversation, _, _ = _setup("big_vid")

    response = client.post(url, {"media": _mp4(extra=8 * _MB)}, format="multipart")

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["error"]["code"] == "VALIDATION_ERROR"
    assert not Message.objects.filter(conversation=conversation).exists()


def test_video_just_under_the_configured_cap_is_accepted(monkeypatch):
    monkeypatch.setattr(chat_serializers, "CHAT_VIDEO_MAX_BYTES", 8 * _MB)
    client, url, _, _, _ = _setup("edge_vid")

    response = client.post(url, {"media": _mp4(extra=7 * _MB)}, format="multipart")

    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["media_type"] == "video"


# Minimal real container headers: libmagic identifies them from content, the
# filename and the client-declared Content-Type are deliberately misleading.
_OTHER_VIDEO_HEADERS = {
    "clip.mov": b"\x00\x00\x00\x14ftypqt  \x00\x00\x00\x00qt  ",
    "clip.3gp": b"\x00\x00\x00\x14ftyp3gp4\x00\x00\x00\x00 3gp4",
    "clip.m4v": b"\x00\x00\x00\x18ftypM4V \x00\x00\x00\x00M4V ",
    "clip.mkv": b"\x1a\x45\xdf\xa3\x93\x42\x82\x88matroska",
    "clip.webm": b"\x1a\x45\xdf\xa3\x93\x42\x82\x84webm",
    "clip.avi": b"RIFF\x00\x00\x00\x00AVI LIST",
    "clip.flv": b"FLV\x01\x05\x00\x00\x00\x09\x00\x00\x00\x00",
    "clip.mpg": b"\x00\x00\x01\xba\x44\x00\x04\x00\x04\x01\x00\x00\x00",
}


@pytest.mark.parametrize("name", sorted(_OTHER_VIDEO_HEADERS))
def test_common_video_formats_other_than_mp4_are_accepted(name):
    client, url, _, _, _ = _setup("fmt_" + name.split(".")[-1])
    upload = SimpleUploadedFile(
        name,
        _OTHER_VIDEO_HEADERS[name] + b"\0" * 64,
        content_type="application/octet-stream",
    )

    response = client.post(url, {"media": upload}, format="multipart")

    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["media_type"] == "video"
    assert response.data["media"]


@pytest.mark.skipif(
    shutil.which("ffmpeg") is None or shutil.which("ffprobe") is None,
    reason="ffmpeg/ffprobe not installed",
)
def test_container_libmagic_cannot_name_is_accepted_when_ffprobe_sees_video(tmp_path):
    # MPEG-TS is the classic case: libmagic answers application/octet-stream.
    clip = tmp_path / "clip.ts"
    subprocess.run(
        [
            "ffmpeg",
            "-y",
            "-f",
            "lavfi",
            "-i",
            "testsrc=duration=1:size=160x120:rate=10",
            "-c:v",
            "libx264",
            "-pix_fmt",
            "yuv420p",
            str(clip),
        ],
        check=True,
        capture_output=True,
        timeout=120,
    )
    client, url, _, _, _ = _setup("ts_vid")
    upload = SimpleUploadedFile("clip.ts", clip.read_bytes(), content_type="video/mp2t")

    response = client.post(url, {"media": upload}, format="multipart")

    assert response.status_code == status.HTTP_201_CREATED
    assert response.data["media_type"] == "video"


def test_unknown_binary_that_is_not_a_video_is_still_rejected():
    client, url, conversation, _, _ = _setup("junk_bin")
    upload = SimpleUploadedFile(
        "movie.mp4", b"\x01\x02\x03" * 200, content_type="video/mp4"
    )

    response = client.post(url, {"media": upload}, format="multipart")

    assert response.status_code == status.HTTP_400_BAD_REQUEST
    assert response.data["error"]["code"] == "VALIDATION_ERROR"
    assert not Message.objects.filter(conversation=conversation).exists()
'@
  }
  @{
    Root = 'Flutter'
    File = 'pubspec.yaml'
    Marker = '# Chat video viewer: "open in another app" fallback for a video whose codec'
    Old = @'
  video_player: ^2.9.2
'@
    New = @'
  video_player: ^2.9.2

  # Chat video viewer: "open in another app" fallback for a video whose codec
  # this phone cannot decode in-app (chat_video_viewer_screen.dart).
  url_launcher: ^6.3.1
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/l10n/app_en.arb'
    Marker = '"chatVideoCannotPlay": "This video cannot be played here. Its format may not be supported on your device.",'
    Old = @'
  "chatVideoTooLarge":
'@
    New = @'
  "chatVideoCannotPlay": "This video cannot be played here. Its format may not be supported on your device.",
  "@chatVideoCannotPlay": {
    "description": "Chat video viewer: shown when the video fails to load or decode."
  },
  "chatVideoRetry": "Try again",
  "@chatVideoRetry": {
    "description": "Chat video viewer: retry loading the video."
  },
  "chatVideoOpenExternal": "Open in another app",
  "@chatVideoOpenExternal": {
    "description": "Chat video viewer: open the video URL in an external player/browser."
  },
  "chatVideoTooLarge":
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/l10n/app_ar.arb'
    Marker = '"chatVideoCannotPlay":'
    Old = @'
  "chatVideoTooLarge":
'@
    New = @'
  "chatVideoCannotPlay": "\u062a\u0639\u0630\u0651\u0631 \u062a\u0634\u063a\u064a\u0644 \u0647\u0630\u0627 \u0627\u0644\u0641\u064a\u062f\u064a\u0648 \u0647\u0646\u0627. \u0642\u062f \u062a\u0643\u0648\u0646 \u0635\u064a\u063a\u062a\u0647 \u063a\u064a\u0631 \u0645\u062f\u0639\u0648\u0645\u0629 \u0639\u0644\u0649 \u062c\u0647\u0627\u0632\u0643.",
  "chatVideoRetry": "\u0625\u0639\u0627\u062f\u0629 \u0627\u0644\u0645\u062d\u0627\u0648\u0644\u0629",
  "chatVideoOpenExternal": "\u0641\u062a\u062d \u0641\u064a \u062a\u0637\u0628\u064a\u0642 \u0622\u062e\u0631",
  "chatVideoTooLarge":
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/chat_thread_screen.dart'
    Marker = '/// (`chat/serializers.py`): 5 MB image / `CHAT_VIDEO_MAX_MB` video'
    Old = @'
  /// (`chat/serializers.py`): 5 MB image / 25 MB video. The backend is
'@
    New = @'
  /// (`chat/serializers.py`): 5 MB image / `CHAT_VIDEO_MAX_MB` video
  /// (backend default 1024 MB, any video format). The backend is
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/chat_thread_screen.dart'
    Marker = 'static const _maxVideoBytes = 1024 * 1024 * 1024;'
    Old = @'
  static const _maxVideoBytes = 25 * 1024 * 1024;
'@
    New = @'
  static const _maxVideoBytes = 1024 * 1024 * 1024;
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/data/message_repository.dart'
    Marker = '// The app-wide Dio timeouts are 15 s, which aborts any real video'
    Old = @'
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath$conversationId/messages/',
        data: data,
      );
'@
    New = @'
      // The app-wide Dio timeouts are 15 s, which aborts any real video
      // upload (and the server needs time to store the file before it
      // answers) - same fix as the Reel upload.
      final response = await _dio.post<Map<String, dynamic>>(
        '$_basePath$conversationId/messages/',
        data: data,
        options: Options(
          sendTimeout: const Duration(minutes: 30),
          receiveTimeout: const Duration(minutes: 30),
        ),
      );
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/message_bubble_widget.dart'
    Marker = 'import ''chat_video_viewer_screen.dart'';'
    Old = @'
import 'outbound_message_queue_provider.dart';
'@
    New = @'
import 'chat_video_viewer_screen.dart';
import 'outbound_message_queue_provider.dart';
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/message_bubble_widget.dart'
    Marker = 'tapKey: canOpenVideo ? ValueKey(''chatVideoOpen_${message.id}'') : null,'
    Old = @'
    final mediaType = message.mediaType;
    return _BubbleShell(
      text: message.text,
      isMine: isMine,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      media:
'@
    New = @'
    final mediaType = message.mediaType;
    final videoUrl = message.mediaUrl;
    final canOpenVideo =
        mediaType == ChatMediaType.video &&
        videoUrl != null &&
        videoUrl.isNotEmpty;
    return _BubbleShell(
      text: message.text,
      isMine: isMine,
      isFirstInGroup: isFirstInGroup,
      isLastInGroup: isLastInGroup,
      onTap:
          canOpenVideo
              ? () => openChatVideoViewer(context, networkUrl: videoUrl)
              : null,
      tapKey: canOpenVideo ? ValueKey('chatVideoOpen_${message.id}') : null,
      media:
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/message_bubble_widget.dart'
    Marker = 'mediaType == ChatMediaType.video && localVideoPath != null;'
    Old = @'
    final mediaType = outbound.mediaType;
'@
    New = @'
    final mediaType = outbound.mediaType;
    final localVideoPath = outbound.mediaPath;
    final canPreviewVideo =
        mediaType == ChatMediaType.video && localVideoPath != null;
'@
  }
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/message_bubble_widget.dart'
    Marker = '? () => openChatVideoViewer(context, localPath: localVideoPath)'
    Old = @'
      onTap: isFailed ? onRetry : null,
      tapKey: isFailed ? ValueKey('outbound_retry_${outbound.id}') : null,
'@
    New = @'
      onTap:
          isFailed
              ? onRetry
              : (canPreviewVideo
                  ? () => openChatVideoViewer(context, localPath: localVideoPath)
                  : null),
      tapKey:
          isFailed
              ? ValueKey('outbound_retry_${outbound.id}')
              : (canPreviewVideo
                  ? ValueKey('outbound_open_${outbound.id}')
                  : null),
'@
  }
)

$NewFiles = @(
  @{
    Root = 'Flutter'
    File = 'lib/features/chat/presentation/chat_video_viewer_screen.dart'
    Content = @'
import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:video_player/video_player.dart';

import '../../../core/l10n/l10n_context.dart';

/// Opens the full-screen chat video player.
///
/// Pass [networkUrl] for a received / already-sent video (the presigned URL
/// from the backend) or [localPath] for a video that is still queued on this
/// phone. Before this screen existed a chat video bubble was only a static
/// placeholder, so tapping a video did nothing.
Future<void> openChatVideoViewer(
  BuildContext context, {
  String? networkUrl,
  String? localPath,
}) {
  return Navigator.of(context).push<void>(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder:
          (_) => ChatVideoViewerScreen(
            networkUrl: networkUrl,
            localPath: localPath,
          ),
    ),
  );
}

/// Builds the controller. Injectable so tests never touch the real plugin.
typedef ChatVideoControllerFactory =
    VideoPlayerController Function({String? networkUrl, String? localPath});

/// Full-screen video player for a chat message: autoplay, tap to pause /
/// resume, scrubbable progress bar, retry on failure, and an "open in another
/// app" fallback for videos whose codec this phone cannot decode in-app (the
/// backend stores chat videos exactly as uploaded, in any format).
class ChatVideoViewerScreen extends StatefulWidget {
  const ChatVideoViewerScreen({
    super.key,
    this.networkUrl,
    this.localPath,
    this.controllerFactory,
  }) : assert(networkUrl != null || localPath != null);

  final String? networkUrl;
  final String? localPath;
  final ChatVideoControllerFactory? controllerFactory;

  @override
  State<ChatVideoViewerScreen> createState() => _ChatVideoViewerScreenState();
}

class _ChatVideoViewerScreenState extends State<ChatVideoViewerScreen> {
  VideoPlayerController? _controller;
  bool _loading = true;
  bool _failed = false;

  // Bumped on every (re)start and on dispose so the result of an in-flight
  // initialize() that belongs to an older attempt is ignored.
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    unawaited(_start(notify: false));
  }

  @override
  void dispose() {
    _generation++;
    _releaseController();
    super.dispose();
  }

  void _releaseController() {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      unawaited(_safeDispose(controller));
    }
  }

  Future<void> _safeDispose(VideoPlayerController controller) async {
    try {
      await controller.dispose();
    } catch (error) {
      debugPrint('ChatVideoViewer: dispose failed: $error');
    }
  }

  VideoPlayerController _createController() {
    final factory = widget.controllerFactory;
    if (factory != null) {
      return factory(
        networkUrl: widget.networkUrl,
        localPath: widget.localPath,
      );
    }
    final path = widget.localPath;
    if (path != null) {
      return VideoPlayerController.file(File(path));
    }
    return VideoPlayerController.networkUrl(Uri.parse(widget.networkUrl!));
  }

  Future<void> _start({required bool notify}) async {
    final generation = ++_generation;
    _releaseController();
    if (notify && mounted) {
      setState(() {
        _loading = true;
        _failed = false;
      });
    }

    VideoPlayerController? controller;
    try {
      controller = _createController();
      await controller.initialize();
      if (!mounted || generation != _generation) {
        await _safeDispose(controller);
        return;
      }
      controller.addListener(_onControllerChanged);
      _controller = controller;
      await controller.play();
      if (!mounted || generation != _generation) return;
      setState(() => _loading = false);
    } catch (error) {
      debugPrint('ChatVideoViewer: failed to start playback: $error');
      if (controller != null) {
        await _safeDispose(controller);
      }
      if (!mounted || generation != _generation) return;
      setState(() {
        _controller = null;
        _loading = false;
        _failed = true;
      });
    }
  }

  void _onControllerChanged() {
    final controller = _controller;
    if (controller == null || !mounted) return;
    if (controller.value.hasError && !_failed) {
      setState(() => _failed = true);
      return;
    }
    // Position / play-state changes: rebuild the controls.
    setState(() {});
  }

  Future<void> _togglePlay() async {
    final controller = _controller;
    if (controller == null) return;
    final value = controller.value;
    if (value.isPlaying) {
      await controller.pause();
      return;
    }
    final atEnd =
        value.duration > Duration.zero && value.position >= value.duration;
    if (atEnd) {
      await controller.seekTo(Duration.zero);
    }
    await controller.play();
  }

  Future<void> _openExternally() async {
    final url = widget.networkUrl;
    if (url == null) return;
    try {
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (error) {
      debugPrint('ChatVideoViewer: could not open externally: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: const ValueKey('chatVideoViewer'),
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(child: _buildBody(context)),
    );
  }

  Widget _buildBody(BuildContext context) {
    final l10n = context.l10n;

    if (_failed) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.white70, size: 48),
              const SizedBox(height: 16),
              Text(
                l10n.chatVideoCannotPlay,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15),
              ),
              const SizedBox(height: 20),
              Wrap(
                alignment: WrapAlignment.center,
                spacing: 12,
                runSpacing: 12,
                children: [
                  FilledButton.tonal(
                    key: const ValueKey('chatVideoRetry'),
                    onPressed: () => unawaited(_start(notify: true)),
                    child: Text(l10n.chatVideoRetry),
                  ),
                  if (widget.networkUrl != null)
                    OutlinedButton(
                      key: const ValueKey('chatVideoOpenExternal'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white54),
                      ),
                      onPressed: () => unawaited(_openExternally()),
                      child: Text(l10n.chatVideoOpenExternal),
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final controller = _controller;
    if (_loading || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final value = controller.value;
    final aspect = value.aspectRatio > 0 ? value.aspectRatio : 16 / 9;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: GestureDetector(
              key: const ValueKey('chatVideoSurface'),
              behavior: HitTestBehavior.opaque,
              onTap: () => unawaited(_togglePlay()),
              child: AspectRatio(
                aspectRatio: aspect,
                child: VideoPlayer(controller),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 16, 12),
          child: Row(
            children: [
              IconButton(
                key: const ValueKey('chatVideoPlayPause'),
                color: Colors.white,
                icon: Icon(value.isPlaying ? Icons.pause : Icons.play_arrow),
                onPressed: () => unawaited(_togglePlay()),
              ),
              Expanded(
                child: VideoProgressIndicator(
                  controller,
                  allowScrubbing: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  colors: const VideoProgressColors(
                    playedColor: Colors.white,
                    bufferedColor: Colors.white30,
                    backgroundColor: Colors.white12,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${_formatDuration(value.position)} / '
                '${_formatDuration(value.duration)}',
                style: const TextStyle(color: Colors.white70, fontSize: 12),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

String _formatDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ 3600;
  final minutes = (totalSeconds % 3600) ~/ 60;
  final seconds = totalSeconds % 60;
  String two(int n) => n.toString().padLeft(2, '0');
  return hours > 0
      ? '$hours:${two(minutes)}:${two(seconds)}'
      : '${two(minutes)}:${two(seconds)}';
}
'@
  }
)

# ---------------------------------------------------------------------------
# Phase 0: sanity
# ---------------------------------------------------------------------------
foreach ($r in @($BackendRoot, $FlutterRoot)) {
    if (-not (Test-Path -LiteralPath $r)) {
        throw "Folder not found: $r  (use -BackendRoot / -FlutterRoot)"
    }
}
try {
    $branch = (& git -C $FlutterRoot rev-parse --abbrev-ref HEAD 2>$null)
    if ($branch -and ($branch -ne 'part-111')) {
        Write-Warning "Flutter repo is on branch '$branch'. This script was written against branch 'part-111'."
    }
} catch { }

# ---------------------------------------------------------------------------
# Phase 1: validate + compute every edit IN MEMORY (nothing is written yet)
# ---------------------------------------------------------------------------
$plans = [ordered]@{}
$problems = New-Object System.Collections.ArrayList
$applied = 0
$skipped = 0

foreach ($e in $Edits) {
    $full = Join-Path (Get-RootPath $e.Root) ($e.File.Replace('/', '\'))
    if (-not $plans.Contains($full)) {
        if (-not (Test-Path -LiteralPath $full)) {
            [void]$problems.Add("Missing file: $full")
            continue
        }
        $f = Read-TextFile $full
        $plans[$full] = [pscustomobject]@{
            Path = $full; Rel = $e.File; Text = $f.Text; Crlf = $f.Crlf; Bom = $f.Bom; Changed = $false
        }
    }
    $plan = $plans[$full]
    $old = (Decode-Text $e.Old).Replace("`r`n", "`n")
    $new = (Decode-Text $e.New).Replace("`r`n", "`n")
    $marker = (Decode-Text $e.Marker).Replace("`r`n", "`n")

    if ($plan.Text.Contains($marker)) {
        $skipped++
        continue
    }
    $count = ([regex]::Matches($plan.Text, [regex]::Escape($old))).Count
    if ($count -ne 1) {
        $firstLine = ($old -split "`n")[0]
        [void]$problems.Add("$($e.File): anchor found $count times (expected 1). First line: $firstLine")
        continue
    }
    $plan.Text = $plan.Text.Replace($old, $new)
    $plan.Changed = $true
    $applied++
}

$newPlans = New-Object System.Collections.ArrayList
foreach ($nf in $NewFiles) {
    $full = Join-Path (Get-RootPath $nf.Root) ($nf.File.Replace('/', '\'))
    $content = (Decode-Text $nf.Content).Replace("`r`n", "`n") + "`n"
    $state = 'create'
    if (Test-Path -LiteralPath $full) {
        $existing = Read-TextFile $full
        if ($existing.Text -eq $content) { $state = 'same' } else { $state = 'overwrite' }
    }
    [void]$newPlans.Add([pscustomobject]@{ Path = $full; Rel = $nf.File; Content = $content; State = $state })
}

if ($problems.Count -gt 0) {
    Write-Host ''
    Write-Host 'NOTHING WAS CHANGED. These edits could not be matched:' -ForegroundColor Red
    foreach ($p in $problems) { Write-Host "  - $p" -ForegroundColor Red }
    Write-Host ''
    Write-Host 'Your local file differs from the GitHub version this script was built on.' -ForegroundColor Yellow
    Write-Host 'Send me the file(s) above (or run: git status / git pull) and I will adjust the script.' -ForegroundColor Yellow
    throw 'Validation failed.'
}

Write-Host ''
Write-Host "Validation OK: $applied edit(s) to apply, $skipped already applied, $($newPlans.Count) new file(s)." -ForegroundColor Green

if ($DryRun) {
    Write-Host 'DryRun: nothing written.' -ForegroundColor Yellow
    return
}

# ---------------------------------------------------------------------------
# Phase 2: write (backup first)
# ---------------------------------------------------------------------------
foreach ($plan in $plans.Values) {
    if (-not $plan.Changed) { continue }
    $bak = $plan.Path + '.bak_chatvideo'
    if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $plan.Path -Destination $bak }
    Write-TextFile -Path $plan.Path -Text $plan.Text -Crlf $plan.Crlf -Bom $plan.Bom
    Write-Host "  edited   $($plan.Rel)"
}

foreach ($np in $newPlans) {
    if ($np.State -eq 'same') {
        Write-Host "  same     $($np.Rel)"
        continue
    }
    $dir = Split-Path -Parent $np.Path
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    if ($np.State -eq 'overwrite') {
        $bak = $np.Path + '.bak_chatvideo'
        if (-not (Test-Path -LiteralPath $bak)) { Copy-Item -LiteralPath $np.Path -Destination $bak }
    }
    Write-TextFile -Path $np.Path -Text $np.Content -Crlf $false -Bom $false
    Write-Host "  created  $($np.Rel)"
}

# ---------------------------------------------------------------------------
# Phase 3: Flutter dependency + localization refresh
# ---------------------------------------------------------------------------
if (-not $SkipFlutterCommands) {
    if (Get-Command flutter -ErrorAction SilentlyContinue) {
        Push-Location $FlutterRoot
        try {
            Write-Host ''
            Write-Host '> flutter pub get' -ForegroundColor Cyan
            & flutter pub get
            if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed' }
            Write-Host '> flutter gen-l10n' -ForegroundColor Cyan
            & flutter gen-l10n
            if ($LASTEXITCODE -ne 0) { throw 'flutter gen-l10n failed' }
        } finally {
            Pop-Location
        }
    } else {
        Write-Warning "flutter is not on PATH. Run 'flutter pub get' and 'flutter gen-l10n' in $FlutterRoot yourself."
    }
}

Write-Host ''
Write-Host 'DONE. Next steps:' -ForegroundColor Green
Write-Host "  1) Backend tests:   cd $BackendRoot ; docker compose exec web pytest chat -q"
Write-Host "                      docker compose exec web flake8 chat config ; docker compose exec web black --check chat config"
Write-Host "  2) Flutter checks:  cd $FlutterRoot ; flutter analyze ; flutter test test/features/chat"
Write-Host '  3) Optional (.env): CHAT_VIDEO_MAX_MB=1024   (raise/lower the cap; restart web + celery after changing)'
Write-Host '  4) PRODUCTION only: raise nginx client_max_body_size (and proxy timeouts / gunicorn --timeout) to match the cap.'
Write-Host '  Backups of every edited file: *.bak_chatvideo'