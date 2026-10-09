# P-115 STEP 9C fix - repair garbled characters in the 4 chat files.
# This script is pure ASCII on purpose (characters are built from codes).
# Run from the repo root:  powershell -ExecutionPolicy Bypass -File .\p115_step9c_fix_encoding.ps1
$ErrorActionPreference = 'Stop'
if (-not (Test-Path 'pubspec.yaml')) { throw 'Run this from the Flutter project root.' }
$utf8 = New-Object System.Text.UTF8Encoding($false)

function C([int[]]$codes) { -join ($codes | ForEach-Object { [char]$_ }) }
$pairs = @(
  @{ Bad = (C 0xE2,0x20AC,0x201D); Good = (C 0x2014) },   # em dash
  @{ Bad = (C 0xE2,0x20AC,0xA6);   Good = (C 0x2026) },   # ellipsis
  @{ Bad = (C 0xC2,0xB7);          Good = (C 0xB7)   },   # middle dot
  @{ Bad = (C 0xC3,0x2014);        Good = (C 0xD7)   }    # multiplication sign
)

$files = @(
  'lib/features/chat/presentation/chat_thread_screen.dart',
  'lib/features/chat/presentation/message_bubble_widget.dart',
  'lib/features/chat/presentation/share_to_conversation_sheet.dart',
  'lib/features/chat/presentation/shared_content_card.dart'
)
foreach ($f in $files) {
  $full = Join-Path (Get-Location) $f
  $text = [System.IO.File]::ReadAllText($full, $utf8)
  $n = 0
  foreach ($p in $pairs) {
    $n += ([regex]::Matches($text, [regex]::Escape($p.Bad))).Count
    $text = $text.Replace($p.Bad, $p.Good)
  }
  [System.IO.File]::WriteAllText($full, $text, $utf8)
  Write-Host ("  {0}: {1} sequences repaired" -f $f, $n)
}

cmd /c "flutter test test/l10n --reporter expanded > p115_step9c_fix_l10n.txt 2>&1"
Get-Content p115_step9c_fix_l10n.txt -Tail 6
cmd /c "flutter test test/features/chat > p115_step9c_fix_chat.txt 2>&1"
Get-Content p115_step9c_fix_chat.txt -Tail 3