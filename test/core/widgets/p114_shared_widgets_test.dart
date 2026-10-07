import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/theme/app_theme.dart';
import 'package:social_commerce_app/core/widgets/expandable_caption.dart';
import 'package:social_commerce_app/core/widgets/grid_tile_media.dart';
import 'package:social_commerce_app/core/widgets/media_carousel.dart';
import 'package:social_commerce_app/core/widgets/profile_tab_bar.dart';
import 'package:social_commerce_app/core/widgets/stat_item.dart';

/// Part P-114 STEP 1: widget tests of the five shared presentation widgets,
/// each in left-to-right and right-to-left.
Widget _wrap(
  Widget child, {
  TextDirection direction = TextDirection.ltr,
  ThemeData? theme,
}) {
  return MaterialApp(
    theme: theme ?? AppTheme.light,
    builder:
        (BuildContext context, Widget? app) =>
            Directionality(textDirection: direction, child: app!),
    home: Scaffold(body: Center(child: child)),
  );
}

class _TabHost extends StatefulWidget {
  const _TabHost({required this.onController});

  final void Function(TabController controller) onController;

  @override
  State<_TabHost> createState() => _TabHostState();
}

class _TabHostState extends State<_TabHost>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 4, vsync: this);

  @override
  void initState() {
    super.initState();
    widget.onController(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ProfileTabBar(
      controller: _controller,
      items: const <ProfileTabItem>[
        ProfileTabItem(icon: Icons.grid_on, label: 'Posts'),
        ProfileTabItem(icon: Icons.movie_outlined, label: 'Reels'),
        ProfileTabItem(icon: Icons.shopping_bag_outlined, label: 'Products'),
        ProfileTabItem(icon: Icons.info_outline, label: 'Info'),
      ],
    );
  }
}

void main() {
  group('P-114 STEP 1: StatItem', () {
    testWidgets('shows the value over the label', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(const StatItem(value: '12.4K', label: 'Followers')),
      );
      expect(find.text('12.4K'), findsOneWidget);
      expect(find.text('Followers'), findsOneWidget);
      expect(
        tester.getCenter(find.text('12.4K')).dy,
        lessThan(tester.getCenter(find.text('Followers')).dy),
      );
    });

    testWidgets('with onTap: callback fires and target is at least 44', (
      WidgetTester tester,
    ) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(StatItem(value: '3', label: 'Posts', onTap: () => taps++)),
      );
      final Size size = tester.getSize(find.byType(InkWell));
      expect(size.width, greaterThanOrEqualTo(44));
      expect(size.height, greaterThanOrEqualTo(44));
      await tester.tap(find.text('Posts'));
      expect(taps, 1);
    });

    testWidgets('works in right-to-left and dark', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const StatItem(value: '5', label: 'Products'),
          direction: TextDirection.rtl,
          theme: AppTheme.dark,
        ),
      );
      expect(find.text('Products'), findsOneWidget);
    });
  });

  group('P-114 STEP 1: ProfileTabBar', () {
    testWidgets('four icon tabs; tapping one changes the controller', (
      WidgetTester tester,
    ) async {
      late TabController controller;
      await tester.pumpWidget(
        _wrap(_TabHost(onController: (TabController c) => controller = c)),
      );
      expect(find.byIcon(Icons.grid_on), findsOneWidget);
      expect(find.byIcon(Icons.movie_outlined), findsOneWidget);
      expect(find.byIcon(Icons.shopping_bag_outlined), findsOneWidget);
      expect(find.byIcon(Icons.info_outline), findsOneWidget);
      expect(controller.index, 0);

      await tester.tap(find.byIcon(Icons.shopping_bag_outlined));
      await tester.pumpAndSettle();
      expect(controller.index, 2);
    });

    testWidgets('RTL: the first tab sits at the right (start) side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          _TabHost(onController: (TabController c) {}),
          direction: TextDirection.rtl,
        ),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.grid_on)).dx,
        greaterThan(tester.getCenter(find.byIcon(Icons.info_outline)).dx),
      );
    });

    testWidgets('LTR: the first tab sits at the left (start) side', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(_TabHost(onController: (TabController c) {})),
      );
      expect(
        tester.getCenter(find.byIcon(Icons.grid_on)).dx,
        lessThan(tester.getCenter(find.byIcon(Icons.info_outline)).dx),
      );
    });
  });

  group('P-114 STEP 1: MediaCarousel', () {
    const List<String> urls = <String>[
      'https://example.com/a.jpg',
      'https://example.com/b.jpg',
      'https://example.com/c.jpg',
    ];

    testWidgets('keeps a fixed 4:5 aspect ratio and shows one dot per image', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, aspectRatio: 4 / 5),
          ),
        ),
      );
      expect(tester.getSize(find.byType(MediaCarousel)), const Size(200, 250));
      for (int i = 0; i < 3; i++) {
        expect(
          find.byKey(ValueKey<String>('media_carousel_dot_$i')),
          findsOneWidget,
        );
      }
    });

    testWidgets('a single image has no dots', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: <String>['https://example.com/a']),
          ),
        ),
      );
      expect(
        find.byKey(const ValueKey<String>('media_carousel_dot_0')),
        findsNothing,
      );
    });

    testWidgets('LTR: swiping towards the left shows the next image', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, onPageChanged: pages.add),
          ),
        ),
      );
      await tester.drag(find.byType(PageView), const Offset(-150, 0));
      await tester.pumpAndSettle();
      expect(pages, <int>[1]);
    });

    testWidgets('RTL: swiping towards the right shows the next image', (
      WidgetTester tester,
    ) async {
      final List<int> pages = <int>[];
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: MediaCarousel(imageUrls: urls, onPageChanged: pages.add),
          ),
          direction: TextDirection.rtl,
        ),
      );
      await tester.drag(find.byType(PageView), const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(pages, <int>[1]);
    });
  });

  group('P-114 STEP 1: ExpandableCaption', () {
    testWidgets('a short caption has no "more" button', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 300,
            child: ExpandableCaption(text: 'Short text', authorName: 'Shop'),
          ),
        ),
      );
      expect(find.text('more'), findsNothing);
    });

    testWidgets('a long caption is cut and "more" expands it', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: ExpandableCaption(
              text: List<String>.filled(60, 'word').join(' '),
              authorName: 'Shop',
            ),
          ),
        ),
      );
      expect(find.text('more'), findsOneWidget);
      final double collapsedHeight = tester.getSize(find.byType(ExpandableCaption)).height;

      await tester.tap(find.text('more'));
      await tester.pumpAndSettle();

      expect(find.text('more'), findsNothing);
      expect(
        tester.getSize(find.byType(ExpandableCaption)).height,
        greaterThan(collapsedHeight),
      );
    });

    testWidgets('works in right-to-left', (WidgetTester tester) async {
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 200,
            child: ExpandableCaption(
              text: List<String>.filled(60, 'word').join(' '),
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.text('more'), findsOneWidget);
    });
  });

  group('P-114 STEP 1: GridTileMedia', () {
    testWidgets('square by default, 9:16 for reels', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(
        _wrap(const SizedBox(width: 90, child: GridTileMedia())),
      );
      expect(tester.getSize(find.byType(GridTileMedia)), const Size(90, 90));

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 90,
            child: GridTileMedia(aspectRatio: 9 / 16),
          ),
        ),
      );
      expect(tester.getSize(find.byType(GridTileMedia)), const Size(90, 160));
    });

    testWidgets('badge icons and tap callback', (WidgetTester tester) async {
      int taps = 0;
      await tester.pumpWidget(
        _wrap(
          SizedBox(
            width: 90,
            child: GridTileMedia(
              badge: GridTileBadge.video,
              onTap: () => taps++,
            ),
          ),
          direction: TextDirection.rtl,
        ),
      );
      expect(find.byIcon(Icons.play_arrow), findsOneWidget);
      await tester.tap(find.byType(GridTileMedia));
      expect(taps, 1);

      await tester.pumpWidget(
        _wrap(
          const SizedBox(
            width: 90,
            child: GridTileMedia(badge: GridTileBadge.carousel),
          ),
        ),
      );
      expect(find.byIcon(Icons.collections), findsOneWidget);
    });
  });
}