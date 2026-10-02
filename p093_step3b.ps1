# p093_step3b.ps1  --  run from D:\Cavallo\social_commerce_app  (branch part-083)
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

# Safety: the lib part (p093_step3a.ps1) must already be applied.
$entText = [IO.File]::ReadAllText((Join-Path (Get-Location).Path 'lib\features\business_console\domain\daily_stats_entity.dart'))
if (-not $entText.Contains('required this.newRatingsCount')) {
    throw 'Run p093_step3a.ps1 first (the entity has no P-093 fields yet).'
}

$tdir = 'test\features\business_console'

# ================================================ TEST FIXTURES (all CRLF files)
$fake = "$tdir\fake_analytics_repository.dart"
Edit-File -Path $fake -SkipIfContains 'Latest-row catalog' -Old @'
/// Totals: followers 6, likes 12, comments 3, story views 9.
'@ -New @'
/// Totals: followers 6, likes 12, comments 3, story views 9.
/// P-093 fields: new ratings 1+0+2 = 3; rating snapshots 4.0, 4.5, 4.5;
/// Latest-row catalog snapshot: 4 active products, 3 posts, 2 reels.
'@
Edit-File -Path $fake -SkipIfContains 'newRatingsCount: 1,' -Old @'
    totalStoryViews: 1,
  ),
'@ -New @'
    totalStoryViews: 1,
    newRatingsCount: 1,
    averageRatingSnapshot: 4.0,
    activeProductsCount: 3,
    publishedPostsCount: 2,
    publishedReelsCount: 1,
  ),
'@
Edit-File -Path $fake -SkipIfContains 'newRatingsCount: 0,' -Old @'
    totalStoryViews: 3,
  ),
'@ -New @'
    totalStoryViews: 3,
    newRatingsCount: 0,
    averageRatingSnapshot: 4.5,
    activeProductsCount: 3,
    publishedPostsCount: 3,
    publishedReelsCount: 1,
  ),
'@
Edit-File -Path $fake -SkipIfContains 'newRatingsCount: 2,' -Old @'
    totalStoryViews: 5,
  ),
'@ -New @'
    totalStoryViews: 5,
    newRatingsCount: 2,
    averageRatingSnapshot: 4.5,
    activeProductsCount: 4,
    publishedPostsCount: 3,
    publishedReelsCount: 2,
  ),
'@

$sum = "$tdir\presentation\analytics_summary_test.dart"
Edit-File -Path $sum -SkipIfContains 'int newRatings = 0,' -Old @'
  int views = 0,
}) {
'@ -New @'
  int views = 0,
  int newRatings = 0,
  double rating = 0.0,
  int products = 0,
  int posts = 0,
  int reels = 0,
}) {
'@
Edit-File -Path $sum -SkipIfContains 'newRatingsCount: newRatings,' -Old @'
    totalStoryViews: views,
  );
}
'@ -New @'
    totalStoryViews: views,
    newRatingsCount: newRatings,
    averageRatingSnapshot: rating,
    activeProductsCount: products,
    publishedPostsCount: posts,
    publishedReelsCount: reels,
  );
}
'@

Edit-File -Path "$tdir\presentation\analytics_line_chart_test.dart" -SkipIfContains 'newRatingsCount: 0,' -Old @'
    totalStoryViews: 0,
  );
}
'@ -New @'
    totalStoryViews: 0,
    newRatingsCount: 0,
    averageRatingSnapshot: 0.0,
    activeProductsCount: 0,
    publishedPostsCount: 0,
    publishedReelsCount: 0,
  );
}
'@

Edit-File -Path "$tdir\presentation\analytics_provider_test.dart" -SkipIfContains 'newRatingsCount: 0,' -Old @'
  totalStoryViews: 0,
);
'@ -New @'
  totalStoryViews: 0,
  newRatingsCount: 0,
  averageRatingSnapshot: 0.0,
  activeProductsCount: 0,
  publishedPostsCount: 0,
  publishedReelsCount: 0,
);
'@

Edit-File -Path "$tdir\presentation\analytics_screen_test.dart" -SkipIfContains 'newRatingsCount: 0,' -Old @'
    totalStoryViews: views,
  );
}
'@ -New @'
    totalStoryViews: views,
    newRatingsCount: 0,
    averageRatingSnapshot: 0.0,
    activeProductsCount: 0,
    publishedPostsCount: 0,
    publishedReelsCount: 0,
  );
}
'@

# ---- repository test
$repo = "$tdir\data\analytics_repository_test.dart"
Edit-File -Path $repo -SkipIfContains 'int newRatings = 0,' -Old @'
    int storyViews = 0,
  }) => {
'@ -New @'
    int storyViews = 0,
    int newRatings = 0,
    String averageRating = '0.00',
    int activeProducts = 0,
    int publishedPosts = 0,
    int publishedReels = 0,
  }) => {
'@
Edit-File -Path $repo -SkipIfContains "'new_ratings_count': newRatings," -Old @'
    'total_story_views': storyViews,
  };
'@ -New @'
    'total_story_views': storyViews,
    'new_ratings_count': newRatings,
    'average_rating_snapshot': averageRating,
    'active_products_count': activeProducts,
    'published_posts_count': publishedPosts,
    'published_reels_count': publishedReels,
  };
'@
Edit-File -Path $repo -SkipIfContains "averageRating: '4.25'," -Old @'
              comments: 2,
              storyViews: 30,
            ),
'@ -New @'
              comments: 2,
              storyViews: 30,
              newRatings: 2,
              averageRating: '4.25',
              activeProducts: 8,
              publishedPosts: 5,
              publishedReels: 3,
            ),
'@
Edit-File -Path $repo -SkipIfContains 'averageRatingSnapshot: 4.25,' -Old @'
          totalStoryViews: 30,
        ),
'@ -New @'
          totalStoryViews: 30,
          newRatingsCount: 2,
          averageRatingSnapshot: 4.25,
          activeProductsCount: 8,
          publishedPostsCount: 5,
          publishedReelsCount: 3,
        ),
'@

# ---- DTO test
$dtot = "$tdir\data\daily_stats_response_dto_test.dart"
Edit-File -Path $dtot -SkipIfContains 'average_rating_snapshot, active_products_count' -Old @'
/// total_likes_received, total_comments_received, total_story_views).
'@ -New @'
/// total_likes_received, total_comments_received, total_story_views,
/// new_ratings_count, average_rating_snapshot, active_products_count,
/// published_posts_count, published_reels_count).
'@
Edit-File -Path $dtot -SkipIfContains 'Object? newRatings = 2,' -Old @'
    Object? storyViews = 27,
  }) => {
'@ -New @'
    Object? storyViews = 27,
    Object? newRatings = 2,
    Object? averageRating = '4.50',
    Object? activeProducts = 8,
    Object? publishedPosts = 5,
    Object? publishedReels = 3,
  }) => {
'@
Edit-File -Path $dtot -SkipIfContains "'new_ratings_count': newRatings," -Old @'
    'total_story_views': storyViews,
  };
'@ -New @'
    'total_story_views': storyViews,
    'new_ratings_count': newRatings,
    'average_rating_snapshot': averageRating,
    'active_products_count': activeProducts,
    'published_posts_count': publishedPosts,
    'published_reels_count': publishedReels,
  };
'@
Edit-File -Path $dtot -SkipIfContains 'averageRatingSnapshot: 4.5,' -Old @'
          totalStoryViews: 27,
        ),
'@ -New @'
          totalStoryViews: 27,
          newRatingsCount: 2,
          averageRatingSnapshot: 4.5,
          activeProductsCount: 8,
          publishedPostsCount: 5,
          publishedReelsCount: 3,
        ),
'@
Edit-File -Path $dtot -SkipIfContains "isNot(contains('productview'))" -Old @'
      expect(entity.toString().toLowerCase(), isNot(contains('product')));
'@ -New @'
      expect(entity.toString().toLowerCase(), isNot(contains('productview')));
'@
Edit-File -Path $dtot -SkipIfContains "'published_reels_count',`r`n    ]) {" -Old @'
      'total_story_views',
    ]) {
'@ -New @'
      'total_story_views',
      'new_ratings_count',
      'average_rating_snapshot',
      'active_products_count',
      'published_posts_count',
      'published_reels_count',
    ]) {
'@
Edit-File -Path $dtot -SkipIfContains 'rating snapshot is parsed from the DRF decimal string' -Old @'
    test('a metric sent as a string throws FormatException', () {
'@ -New @'
    test('the rating snapshot is parsed from the DRF decimal string', () {
      final entity =
          DailyStatsResponseDto.fromJson(
            row(averageRating: '4.25'),
          ).toEntity();
      final unrated =
          DailyStatsResponseDto.fromJson(
            row(averageRating: '0.00'),
          ).toEntity();

      expect(entity.averageRatingSnapshot, 4.25);
      expect(unrated.averageRatingSnapshot, 0.0);
    });

    test('the rating snapshot also accepts a plain JSON number', () {
      expect(
        DailyStatsResponseDto.fromJson(
          row(averageRating: 4.5),
        ).toEntity().averageRatingSnapshot,
        4.5,
      );
      expect(
        DailyStatsResponseDto.fromJson(
          row(averageRating: 4),
        ).toEntity().averageRatingSnapshot,
        4.0,
      );
    });

    test('an invalid rating snapshot throws FormatException', () {
      for (final bad in const <Object>['abc', 'NaN', '5.01', '-1.00', '', true]) {
        expect(
          () => DailyStatsResponseDto.fromJson(row(averageRating: bad)),
          throwsFormatException,
          reason: 'rating "$bad" must be rejected',
        );
      }
    });

    test('a P-093 count sent as a string throws FormatException', () {
      expect(
        () => DailyStatsResponseDto.fromJson(row(publishedPosts: '5')),
        throwsFormatException,
      );
      expect(
        () => DailyStatsResponseDto.fromJson(row(newRatings: '2')),
        throwsFormatException,
      );
    });

    test('a metric sent as a string throws FormatException', () {
'@


Write-Host ''
Write-Host 'P-093 STEP3B script finished.'