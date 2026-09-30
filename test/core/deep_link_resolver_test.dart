import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/core/deep_link_resolver.dart';
import 'package:social_commerce_app/routing/route_names.dart';

/// Part P-080: unit tests for [resolveDeepLink].
///
/// The literal strings below ('business_profile', '/business/5', ...) are
/// written out on purpose instead of reusing [DeepLinkTypes] / [RouteNames]
/// everywhere: they pin the exact cross-repo contract with the backend's
/// `notifications/models.py` (P-078) and the exact existing route paths, so
/// an accidental rename on either side fails a test here.
void main() {
  const knownTypes = <String>[
    'business_profile',
    'post_detail',
    'reel_detail',
    'product_detail',
    'chat_thread',
  ];

  group('resolveDeepLink - known deep_link_type values', () {
    test('business_profile + 5 -> /business/5', () {
      expect(resolveDeepLink('business_profile', 5), '/business/5');
    });

    test('post_detail + 12 -> /post/12', () {
      expect(resolveDeepLink('post_detail', 12), '/post/12');
    });

    test('reel_detail + 7 -> /reel/7', () {
      expect(resolveDeepLink('reel_detail', 7), '/reel/7');
    });

    test('product_detail + 33 -> /product/33', () {
      expect(resolveDeepLink('product_detail', 33), '/product/33');
    });

    test('chat_thread + 101 -> /chat/101', () {
      expect(resolveDeepLink('chat_thread', 101), '/chat/101');
    });

    test('a large id is interpolated intact', () {
      expect(
        resolveDeepLink('business_profile', 2147483647),
        '/business/2147483647',
      );
    });
  });

  group('resolveDeepLink - unrecognized deepLinkType', () {
    test('an unknown type returns the safe fallback, not an exception', () {
      expect(resolveDeepLink('story_detail', 5), '/home');
      expect(resolveDeepLink('story_detail', 5), RouteNames.homePath);
    });

    test(
      'an empty type (backend: "navigates nowhere") returns the fallback',
      () {
        expect(resolveDeepLink('', 5), '/home');
        expect(resolveDeepLink('', null), '/home');
      },
    );

    test('matching is case-sensitive (Business_Profile is not known)', () {
      expect(resolveDeepLink('Business_Profile', 5), '/home');
    });

    test('a type with surrounding whitespace is not known', () {
      expect(resolveDeepLink(' business_profile ', 5), '/home');
    });
  });

  group('resolveDeepLink - missing or invalid targetId', () {
    for (final type in knownTypes) {
      test(
        '$type with a null targetId returns the fallback, never .../null',
        () {
          final result = resolveDeepLink(type, null);
          expect(result, '/home');
          expect(result, isNot(contains('null')));
        },
      );
    }

    test('a zero targetId returns the fallback', () {
      for (final type in knownTypes) {
        expect(resolveDeepLink(type, 0), '/home', reason: type);
      }
    });

    test('a negative targetId returns the fallback', () {
      for (final type in knownTypes) {
        expect(resolveDeepLink(type, -3), '/home', reason: type);
      }
    });

    test('an unknown type with a null targetId returns the fallback', () {
      expect(resolveDeepLink('nonsense', null), '/home');
    });
  });

  group('deep link contract', () {
    test('DeepLinkTypes.all is exactly the five backend P-078 values', () {
      expect(DeepLinkTypes.all, <String>{
        'business_profile',
        'post_detail',
        'reel_detail',
        'product_detail',
        'chat_thread',
      });
    });

    test('the fallback route is /home', () {
      expect(deepLinkFallbackRoute, '/home');
      expect(deepLinkFallbackRoute, RouteNames.homePath);
    });

    test(
      'every known type resolves to a concrete path with no placeholder',
      () {
        for (final type in knownTypes) {
          final result = resolveDeepLink(type, 42);
          expect(result, startsWith('/'), reason: type);
          expect(result, endsWith('/42'), reason: type);
          expect(result, isNot(contains(':')), reason: type);
        }
      },
    );

    test('resolved paths come from the existing RouteNames path patterns', () {
      String fill(String pattern, int id) =>
          pattern.replaceFirst(':${RouteNames.idParam}', '$id');

      expect(
        resolveDeepLink('business_profile', 5),
        fill(RouteNames.businessProfilePath, 5),
      );
      expect(
        resolveDeepLink('post_detail', 5),
        fill(RouteNames.postDetailPath, 5),
      );
      expect(
        resolveDeepLink('reel_detail', 5),
        fill(RouteNames.reelDetailPath, 5),
      );
      expect(
        resolveDeepLink('product_detail', 5),
        fill(RouteNames.productDetailPath, 5),
      );
      expect(
        resolveDeepLink('chat_thread', 5),
        fill(RouteNames.chatThreadPath, 5),
      );
    });

    test('never throws for odd input', () {
      expect(
        () => resolveDeepLink('\u0645\u062d\u0645\u062f', 1),
        returnsNormally,
      );
      expect(() => resolveDeepLink('x' * 10000, 1), returnsNormally);
      expect(() => resolveDeepLink('post_detail', 1 << 62), returnsNormally);
    });
  });
}
