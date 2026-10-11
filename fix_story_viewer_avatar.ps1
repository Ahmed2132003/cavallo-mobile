<# fix_story_viewer_avatar.ps1 - run from anywhere:  .\fix_story_viewer_avatar.ps1 [-MobileRoot D:\Cavallo\social_commerce_app] #>
param([string]$MobileRoot = 'D:\Cavallo\social_commerce_app')
$ErrorActionPreference = 'Stop'
$path = Join-Path $MobileRoot 'lib\features\stories\presentation\story_viewer_screen.dart'
$raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
$eol = if ($raw.Contains("`r`n")) { "`r`n" } else { "`n" }
$t = $raw.Replace("`r`n", "`n")
$edits = @(
@{
Old=@'
import '../../business_profile/presentation/business_avatar_provider.dart';

'@
New=@'
import '../../business_profile/presentation/business_avatar_provider.dart';
import '../../business_profile/presentation/business_profile_public_provider.dart';

'@
},
@{
Old=@'
                        imageUrl: ref.watch(
                          businessAvatarUrlProvider(widget.businessId),
                        ),

'@
New=@'
                        // Only reuse a business profile that is ALREADY loaded
                        // (the tray ring / profile screen that opened this
                        // viewer keeps it alive). The viewer never starts its
                        // own network request just for the photo; on a deep
                        // link it simply shows the initials.
                        imageUrl:
                            ref.exists(
                                  businessProfilePublicProvider(
                                    widget.businessId,
                                  ),
                                )
                                ? ref.watch(
                                  businessAvatarUrlProvider(widget.businessId),
                                )
                                : null,

'@
},
@{ Old = 'x'; New = 'x' }
)
$edits = $edits | Select-Object -SkipLast 1
foreach ($e in $edits) {
  $old = $e.Old.Replace("`r`n", "`n"); $new = $e.New.Replace("`r`n", "`n")
  $n = ([regex]::Matches($t, [regex]::Escape($old))).Count
  if ($n -eq 1) { $t = $t.Replace($old, $new) }
  elseif ($n -eq 0 -and $t.Contains($new)) { Write-Host 'already applied, skipped' }
  else { throw "Edit does not match ($n matches). Nothing written." }
}
[System.IO.File]::WriteAllText($path, $t.Replace("`n", $eol), (New-Object System.Text.UTF8Encoding($false)))
Write-Host 'story_viewer_screen.dart fixed.' -ForegroundColor Green