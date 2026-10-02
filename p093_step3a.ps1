# p093_step3a.ps1  --  run from D:\Cavallo\social_commerce_app  (branch part-083)
$ErrorActionPreference = 'Stop'

if (-not (Test-Path .\pubspec.yaml) -or -not (Test-Path .\lib\features\business_console\domain\daily_stats_entity.dart)) {
    throw 'Run this script from D:\Cavallo\social_commerce_app (pubspec.yaml / business_console not found).'
}
$branch = (git rev-parse --abbrev-ref HEAD).Trim()
if ($branch -ne 'part-083') {
    throw "Current branch is '$branch' but P-085 analytics code lives on 'part-083'. Run: git checkout part-083"
}

$utf8 = New-Object System.Text.UTF8Encoding($false)

function ConvertTo-Eol([string]$s, [string]$eol) {
    $lf = $s -replace "`r?`n", "`n"
    if ($eol -eq 'CRLF') { return $lf -replace "`n", "`r`n" }
    return $lf
}

function Edit-File {
    param(
        [string]$Path,
        [string]$Old,
        [string]$New,
        [string]$SkipIfContains,
        [string]$Eol = 'CRLF'
    )
    $full = Join-Path (Get-Location).Path $Path
    $text = [IO.File]::ReadAllText($full)
    if ($text.Contains($SkipIfContains)) {
        Write-Host "SKIP (already applied): $Path  [$SkipIfContains]"
        return
    }
    $oldC = ConvertTo-Eol $Old $Eol
    $newC = ConvertTo-Eol $New $Eol
    $count = ([regex]::Matches($text, [regex]::Escape($oldC))).Count
    if ($count -ne 1) {
        throw "Anchor found $count time(s) (expected exactly 1) in $Path :: $($Old.Substring(0, [Math]::Min(70, $Old.Length)))"
    }
    $text = $text.Replace($oldC, $newC)
    [IO.File]::WriteAllText($full, $text, $utf8)
    Write-Host "EDITED: $Path"
}

$ent = 'lib\features\business_console\domain\daily_stats_entity.dart'
$dto = 'lib\features\business_console\data\dtos\daily_stats_response_dto.dart'

# ============================================================ ENTITY (LF file)
Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'The tracked metrics' -Old @'
/// ### Exactly four metrics
'@ -New @'
/// ### The tracked metrics
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'P-093 adds new' -Old @'
/// P-084 only tracks followers, likes, comments and story views. Product
/// views and profile views
'@ -New @'
/// P-084 tracks followers, likes, comments and story views; P-093 adds new
/// ratings, an average-rating snapshot and three catalog-size snapshots.
/// Product views and profile views
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'POINT-IN-TIME SNAPSHOT' -Old @'
/// across a DST change.
library;
'@ -New @'
/// across a DST change.
///
/// ### P-093 fields
///
/// * [newRatingsCount]: ratings first created that day (a customer
///   re-rating a business edits their row and is not counted again).
/// * [averageRatingSnapshot]: the business's average rating as of the
///   rollup run - a stored POINT-IN-TIME SNAPSHOT, not a live value. A
///   business with no ratings yet snapshots 0.0; the backend never
///   produces a real average below 1, so 0.0 means "not rated yet".
/// * [activeProductsCount], [publishedPostsCount], [publishedReelsCount]:
///   catalog totals as of the rollup run (snapshots, not daily deltas).
library;
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'required this.newRatingsCount' -Old @'
    required this.totalStoryViews,
  });

  final DateTime date;
'@ -New @'
    required this.totalStoryViews,
    required this.newRatingsCount,
    required this.averageRatingSnapshot,
    required this.activeProductsCount,
    required this.publishedPostsCount,
    required this.publishedReelsCount,
  });

  final DateTime date;
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'final int newRatingsCount;' -Old @'
  final int totalStoryViews;

  @override
  bool operator ==
'@ -New @'
  final int totalStoryViews;
  final int newRatingsCount;
  final double averageRatingSnapshot;
  final int activeProductsCount;
  final int publishedPostsCount;
  final int publishedReelsCount;

  @override
  bool operator ==
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains 'other.newRatingsCount == newRatingsCount' -Old @'
          other.totalStoryViews == totalStoryViews);
'@ -New @'
          other.totalStoryViews == totalStoryViews &&
          other.newRatingsCount == newRatingsCount &&
          other.averageRatingSnapshot == averageRatingSnapshot &&
          other.activeProductsCount == activeProductsCount &&
          other.publishedPostsCount == publishedPostsCount &&
          other.publishedReelsCount == publishedReelsCount);
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains '    newRatingsCount,' -Old @'
    totalStoryViews,
  );

  @override
  String toString()
'@ -New @'
    totalStoryViews,
    newRatingsCount,
    averageRatingSnapshot,
    activeProductsCount,
    publishedPostsCount,
    publishedReelsCount,
  );

  @override
  String toString()
'@

Edit-File -Path $ent -Eol 'LF' -SkipIfContains "'newRatingsCount: " -Old @'
      'totalStoryViews: $totalStoryViews)';
'@ -New @'
      'totalStoryViews: $totalStoryViews, '
      'newRatingsCount: $newRatingsCount, '
      'averageRatingSnapshot: $averageRatingSnapshot, '
      'activeProductsCount: $activeProductsCount, '
      'publishedPostsCount: $publishedPostsCount, '
      'publishedReelsCount: $publishedReelsCount)';
'@

# ============================================================== DTO (CRLF file)
Edit-File -Path $dto -SkipIfContains '"new_ratings_count": 2' -Old @'
///   "total_story_views": 27
/// }
'@ -New @'
///   "total_story_views": 27,
///   "new_ratings_count": 2,
///   "average_rating_snapshot": "4.50",
///   "active_products_count": 8,
///   "published_posts_count": 5,
///   "published_reels_count": 3
/// }
'@

Edit-File -Path $dto -SkipIfContains 'all ten fields' -Old @'
/// The backend serializer always emits all five fields (the four metrics
/// are non-null `PositiveIntegerField`s). A missing or null field
'@ -New @'
/// The backend serializer always emits all ten fields (date plus nine
/// non-null metrics: eight `PositiveIntegerField`s and one `DecimalField`).
/// A missing or null field
'@

Edit-File -Path $dto -SkipIfContains 'average_rating_snapshot (P-093)' -Old @'
/// the repository turns that into a visible failure instead of a chart.
library;
'@ -New @'
/// the repository turns that into a visible failure instead of a chart.
///
/// ### average_rating_snapshot (P-093)
///
/// DRF serializes a `DecimalField` as a STRING by default (`"4.50"`), so
/// the value is parsed from that string; a plain JSON number is accepted
/// too. Anything else, a non-finite number, or a value outside 0..5 is a
/// contract break and throws [FormatException] (never a silent 0).
library;
'@

Edit-File -Path $dto -SkipIfContains 'required this.newRatingsCount' -Old @'
    required this.totalStoryViews,
  });

  factory DailyStatsResponseDto.fromJson
'@ -New @'
    required this.totalStoryViews,
    required this.newRatingsCount,
    required this.averageRatingSnapshot,
    required this.activeProductsCount,
    required this.publishedPostsCount,
    required this.publishedReelsCount,
  });

  factory DailyStatsResponseDto.fromJson
'@

Edit-File -Path $dto -SkipIfContains "_requireInt(json, 'new_ratings_count')" -Old @'
      totalStoryViews: _requireInt(json, 'total_story_views'),
    );
'@ -New @'
      totalStoryViews: _requireInt(json, 'total_story_views'),
      newRatingsCount: _requireInt(json, 'new_ratings_count'),
      averageRatingSnapshot: _requireRating(json, 'average_rating_snapshot'),
      activeProductsCount: _requireInt(json, 'active_products_count'),
      publishedPostsCount: _requireInt(json, 'published_posts_count'),
      publishedReelsCount: _requireInt(json, 'published_reels_count'),
    );
'@

Edit-File -Path $dto -SkipIfContains 'final int newRatingsCount;' -Old @'
  final int totalStoryViews;

  DailyStats toEntity()
'@ -New @'
  final int totalStoryViews;
  final int newRatingsCount;
  final double averageRatingSnapshot;
  final int activeProductsCount;
  final int publishedPostsCount;
  final int publishedReelsCount;

  DailyStats toEntity()
'@

Edit-File -Path $dto -SkipIfContains 'newRatingsCount: newRatingsCount,' -Old @'
      totalStoryViews: totalStoryViews,
    );
'@ -New @'
      totalStoryViews: totalStoryViews,
      newRatingsCount: newRatingsCount,
      averageRatingSnapshot: averageRatingSnapshot,
      activeProductsCount: activeProductsCount,
      publishedPostsCount: publishedPostsCount,
      publishedReelsCount: publishedReelsCount,
    );
'@

Edit-File -Path $dto -SkipIfContains 'static double _requireRating' -Old @'
      'Daily stats row: "$key" must be an integer, got ${value.runtimeType}.',
    );
  }
}
'@ -New @'
      'Daily stats row: "$key" must be an integer, got ${value.runtimeType}.',
    );
  }

  /// A rating average: a DRF decimal string ("4.50") or a JSON number,
  /// finite and within 0..5.
  static double _requireRating(Map<String, dynamic> json, String key) {
    final value = json[key];
    double? parsed;
    if (value is String) {
      parsed = double.tryParse(value);
    } else if (value is num) {
      parsed = value.toDouble();
    }
    if (parsed == null || !parsed.isFinite || parsed < 0 || parsed > 5) {
      throw FormatException(
        'Daily stats row: "$key" must be a decimal between 0 and 5, '
        'got ${value.runtimeType} $value.',
      );
    }
    return parsed;
  }
}
'@


Write-Host ''
Write-Host 'P-093 STEP3A script finished.'