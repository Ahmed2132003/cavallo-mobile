import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_shimmer_box.dart';
import 'package:social_commerce_app/features/feed/presentation/feed_skeleton.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-114 STEP 2: the Home feed skeletons replace the spinners. They are
/// built from the shared AppShimmerBox, keep the post card's fixed 1:1 media
/// box, and work in Light, Dark, left-to-right and right-to-left.
Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  ThemeData? theme,
  Locale locale = const Locale('en'),
}) async {
  // Tall on purpose: a ListView only builds the items near the screen.
  tester.view.physicalSize = const Size(400, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: theme ?? AppTheme.light,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('FeedSkeletonList shows two post skeletons and no spinner', (
    tester,
  ) async {
    await _pump(tester, const FeedSkeletonList());

    expect(find.byType(FeedPostSkeleton), findsNWidgets(2));
    expect(find.byType(AppShimmerBox), findsWidgets);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('FeedSkeletonList honours the count', (tester) async {
    await _pump(tester, const FeedSkeletonList(count: 3));

    expect(find.byType(FeedPostSkeleton), findsNWidgets(3));
  });

  testWidgets('a post skeleton keeps the fixed 1:1 media box', (tester) async {
    await _pump(tester, const FeedPostSkeleton(animate: false));

    final AspectRatio box = tester.widget<AspectRatio>(
      find.descendant(
        of: find.byType(FeedPostSkeleton),
        matching: find.byType(AspectRatio),
      ),
    );
    expect(box.aspectRatio, 1);
  });

  testWidgets('renders in Dark and in right-to-left without errors', (
    tester,
  ) async {
    await _pump(
      tester,
      const FeedSkeletonList(),
      theme: AppTheme.dark,
      locale: const Locale('ar'),
    );

    expect(find.byType(FeedPostSkeleton), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
