import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_colors.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/app_status_chip.dart';
import 'package:social_commerce_app/features/business_console/presentation/console_row.dart';
import 'package:social_commerce_app/features/content/domain/content_item_entity.dart';
import 'package:social_commerce_app/features/content/domain/moderation_status.dart';
import 'package:social_commerce_app/features/content/domain/post_entity.dart';
import 'package:social_commerce_app/features/content/domain/reel_entity.dart';
import 'package:social_commerce_app/features/content/presentation/content_list_screen.dart';
import 'package:social_commerce_app/features/content/presentation/own_content_provider.dart';
import 'package:social_commerce_app/features/stories/domain/own_story_entity.dart';
import 'package:social_commerce_app/features/stories/presentation/own_stories_provider.dart';
import 'package:social_commerce_app/features/stories/presentation/story_list_screen.dart';
import 'package:social_commerce_app/l10n/app_localizations.dart';

/// Part P-115 (STEP 6B): status chips on REAL rows of the Business Console.
///
/// Guards the architecture rules of the plan:
///  * the business sees an honest status per item (never "live" too early);
///  * the rejection reason is ALWAYS fully visible (wraps, never cut);
///  * meaning never rides on colour alone (every chip = icon + text);
///  * colours come from the AppColors tokens in Light and Dark;
///  * English and Arabic.
///
/// Test-only step: no lib file changed. Arabic text is read from the
/// generated localizations, so this file stays ASCII.

class _Variant {
  const _Variant(this.name, this.locale, this.dark);

  final String name;
  final Locale locale;
  final bool dark;

  ThemeData get theme => dark ? AppTheme.dark : AppTheme.light;
  AppColors get colors => dark ? AppColors.dark : AppColors.light;
  AppLocalizations get l10n => lookupAppLocalizations(locale);
}

const List<_Variant> _variants = <_Variant>[
  _Variant('en light', Locale('en'), false),
  _Variant('en dark', Locale('en'), true),
  _Variant('ar light', Locale('ar'), false),
  _Variant('ar dark', Locale('ar'), true),
];

const String _longReason =
    'The product photo is blurry, the logo is cropped and the price tag is '
    'not readable. Please upload a clear photo of the whole product on a '
    'plain background, then submit it again for review so we can approve it.';

// ---------------------------------------------------------------- content

class _FixedContent extends OwnContentNotifier {
  _FixedContent(this._items);

  final List<ContentItem> _items;

  @override
  Future<List<ContentItem>> build() async => _items;
}

const Post _pendingPost = Post(
  id: 1,
  businessId: 1,
  caption: 'Pending post caption',
  status: ModerationStatus.pendingReview,
);

const Post _livePost = Post(
  id: 2,
  businessId: 1,
  caption: 'Live post caption',
  status: ModerationStatus.published,
);

const Post _rejectedPost = Post(
  id: 3,
  businessId: 1,
  caption: 'Rejected post caption',
  status: ModerationStatus.rejected,
  rejectionReason: _longReason,
);

const Post _rejectedNoReasonPost = Post(
  id: 4,
  businessId: 1,
  caption: 'Rejected without reason caption',
  status: ModerationStatus.rejected,
);

// Deliberately `published`: the screen must trust processingStatus first.
const Reel _processingReel = Reel(
  id: 10,
  businessId: 1,
  caption: 'Processing reel caption',
  processingStatus: ReelProcessingStatus.processing,
  status: ModerationStatus.published,
);

const Reel _failedReel = Reel(
  id: 11,
  businessId: 1,
  caption: 'Failed reel caption',
  processingStatus: ReelProcessingStatus.failed,
  status: ModerationStatus.pendingReview,
);

// ---------------------------------------------------------------- stories

class _FixedStories extends OwnStoriesNotifier {
  _FixedStories(this._stories);

  final List<OwnStory> _stories;

  @override
  Future<List<OwnStory>> build() async => _stories;
}

final DateTime _now = DateTime.utc(2026, 10, 1, 12);

OwnStory _story({
  required int id,
  required OwnStoryStatus status,
  required Duration expiresIn,
  String? rejectionReason,
}) {
  final DateTime expiresAt = _now.add(expiresIn);
  return OwnStory(
    id: id,
    businessId: 7,
    // .mp4 keeps the thumbnail on the placeholder icon (no network image).
    mediaUrl: 'https://cdn.example.com/stories/$id.mp4',
    status: status,
    publishedAt: expiresAt.subtract(const Duration(hours: 24)),
    expiresAt: expiresAt,
    rejectionReason: rejectionReason,
  );
}

// ---------------------------------------------------------------- helpers

Future<void> _pump(
  WidgetTester tester,
  Widget home,
  List<dynamic> overrides,
  _Variant variant,
) async {
  tester.view.physicalSize = const Size(800, 3000);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [...overrides],
      child: MaterialApp(
        locale: variant.locale,
        theme: variant.theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

/// Unmounts the screen so ContentListScreen cancels its 5 second poll timer
/// (a pending timer would fail the test).
Future<void> _unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
}

Finder _chip(String label) {
  return find.ancestor(
    of: find.text(label),
    matching: find.byType(AppStatusChip),
  );
}

/// One chip = exactly one icon + exactly one text, token colours, and a text
/// that wraps (no ellipsis, no max lines) so it is never cut.
void _expectChip(
  WidgetTester tester,
  String label, {
  required IconData icon,
  required Color background,
  required Color foreground,
}) {
  final Finder chip = _chip(label);
  expect(chip, findsOneWidget, reason: 'chip "$label"');

  final Container box = tester.widget<Container>(
    find.descendant(of: chip, matching: find.byType(Container)).first,
  );
  expect((box.decoration! as BoxDecoration).color, background);

  final Finder icons = find.descendant(of: chip, matching: find.byType(Icon));
  expect(icons, findsOneWidget);
  expect(tester.widget<Icon>(icons).icon, icon);

  final Finder texts = find.descendant(of: chip, matching: find.byType(Text));
  expect(texts, findsOneWidget);
  final Text text = tester.widget<Text>(texts);
  expect(text.style?.color, foreground);
  expect(text.overflow, isNull);
  expect(text.maxLines, isNull);
}

void main() {
  group('content tab rows', () {
    for (final _Variant v in _variants) {
      testWidgets('every state has its own chip - ${v.name}', (tester) async {
        final AppLocalizations l10n = v.l10n;
        final AppColors c = v.colors;

        await _pump(
          tester,
          ContentListScreen(onCreatePost: () {}, onCreateReel: () {}),
          [
            ownContentProvider.overrideWith(
              () => _FixedContent(const <ContentItem>[
                PostContentItem(_pendingPost),
                PostContentItem(_livePost),
                PostContentItem(_rejectedPost),
                ReelContentItem(_processingReel),
                ReelContentItem(_failedReel),
              ]),
            ),
          ],
          v,
        );

        // One row and exactly one chip per item.
        expect(find.byType(ConsoleRow), findsNWidgets(5));
        expect(find.byType(AppStatusChip), findsNWidgets(5));

        _expectChip(
          tester,
          l10n.consoleStatusUnderReview,
          icon: Icons.hourglass_bottom,
          background: c.warningSubtle,
          foreground: c.warningText,
        );
        _expectChip(
          tester,
          l10n.consoleStatusLive,
          icon: Icons.check_circle_outline,
          background: c.successSubtle,
          foreground: c.successText,
        );
        _expectChip(
          tester,
          l10n.consoleStatusRejectedWithReason(_longReason),
          icon: Icons.cancel_outlined,
          background: c.dangerSubtle,
          foreground: c.dangerText,
        );
        // The processing Reel shows the processing chip, never "Live" even
        // though its raw moderation status is published.
        _expectChip(
          tester,
          l10n.consoleStatusProcessing,
          icon: Icons.hourglass_top,
          background: c.surfaceVariant,
          foreground: c.textSecondary,
        );
        _expectChip(
          tester,
          l10n.consoleStatusProcessingFailed,
          icon: Icons.error_outline,
          background: c.dangerSubtle,
          foreground: c.dangerText,
        );

        // The long rejection reason wraps onto more lines: the chip is taller
        // than a one-line chip, and the whole reason is in the tree.
        final double rejectedHeight =
            tester
                .getSize(
                  _chip(l10n.consoleStatusRejectedWithReason(_longReason)),
                )
                .height;
        final double liveHeight =
            tester.getSize(_chip(l10n.consoleStatusLive)).height;
        expect(rejectedHeight, greaterThan(liveHeight));

        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }

    testWidgets('a rejected item without a reason never shows a blank reason', (
      tester,
    ) async {
      final _Variant v = _variants[0];
      final AppLocalizations l10n = v.l10n;

      await _pump(
        tester,
        ContentListScreen(onCreatePost: () {}, onCreateReel: () {}),
        [
          ownContentProvider.overrideWith(
            () => _FixedContent(const <ContentItem>[
              PostContentItem(_rejectedNoReasonPost),
            ]),
          ),
        ],
        v,
      );

      expect(
        _chip(
          l10n.consoleStatusRejectedWithReason(l10n.consoleStatusNoReasonGiven),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await _unmount(tester);
    });
  });

  group('stories tab rows', () {
    for (final _Variant v in _variants) {
      testWidgets('every state has its own chip - ${v.name}', (tester) async {
        final AppLocalizations l10n = v.l10n;
        final AppColors c = v.colors;

        await _pump(tester, const StoryListScreen(), [
          ownStoriesProvider.overrideWith(
            () => _FixedStories(<OwnStory>[
              _story(
                id: 1,
                status: OwnStoryStatus.pendingReview,
                expiresIn: const Duration(hours: 20),
              ),
              _story(
                id: 2,
                status: OwnStoryStatus.published,
                expiresIn: const Duration(hours: 5, minutes: 30),
              ),
              _story(
                id: 3,
                status: OwnStoryStatus.rejected,
                expiresIn: const Duration(hours: 10),
                rejectionReason: _longReason,
              ),
              // Published on the server but past expires_at: shown Expired.
              _story(
                id: 4,
                status: OwnStoryStatus.published,
                expiresIn: const Duration(hours: -1),
              ),
            ]),
          ),
          storyListClockProvider.overrideWithValue(() => _now),
        ], v);

        expect(find.byType(ConsoleRow), findsNWidgets(4));
        expect(find.byType(AppStatusChip), findsNWidgets(4));

        _expectChip(
          tester,
          l10n.consoleStoryPending,
          icon: Icons.hourglass_bottom,
          background: c.warningSubtle,
          foreground: c.warningText,
        );
        _expectChip(
          tester,
          l10n.consoleStoryPublished,
          icon: Icons.check_circle_outline,
          background: c.successSubtle,
          foreground: c.successText,
        );
        _expectChip(
          tester,
          l10n.consoleStoryRejected,
          icon: Icons.cancel_outlined,
          background: c.dangerSubtle,
          foreground: c.dangerText,
        );
        _expectChip(
          tester,
          l10n.consoleStoryExpired,
          icon: Icons.timer_off_outlined,
          background: c.surfaceVariant,
          foreground: c.textSecondary,
        );

        // Only the live story shows a countdown.
        expect(find.text(l10n.consoleStoryTimeLeftHM(5, 30)), findsOneWidget);

        // The rejection reason stays fully visible under the rejected story.
        final Finder reason = find.text(l10n.consoleStoryReason(_longReason));
        expect(reason, findsOneWidget);
        final Text reasonText = tester.widget<Text>(reason);
        expect(reasonText.overflow, isNull);
        expect(reasonText.maxLines, isNull);
        expect(reasonText.style?.color, c.dangerText);

        expect(tester.takeException(), isNull);
        await _unmount(tester);
      });
    }
  });
}
