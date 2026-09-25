/// Part P-061 scope: [FeedRepository] implementation.
///
/// ### Filename deviation, documented not silent
///
/// Every other feature in this project splits its interface/impl as
/// `\<name\>_repository.dart` (domain, abstract) / `\<name\>_repository_impl
/// .dart` (data, concrete) — e.g. `ProductRepository` /
/// `ProductRepositoryImpl`. This file is named `feed_repository.dart`
/// (no `_impl` suffix) inside `data/` because P-061's own Files
/// Expected list names that exact path literally. The class itself is
/// still named `FeedRepositoryImpl` to keep the naming convention
/// everywhere else (imports, mocks, docs) consistent with the rest of
/// the app — only the file's name is the one-off.
///
/// Follows `ProductPublicRepositoryImpl`'s (Part P-034) and
/// `BusinessProfilePublicRepositoryImpl`'s (Part P-029) exact
/// conventions otherwise: depends only on `dioClientProvider`, never
/// constructs its own [Dio].
///
/// ### Parsing — zero duplicated DTO logic
///
/// Each raw item is a strict superset of either `PostPublicSerializer`'s
/// or `ReelPublicSerializer`'s fields plus a `content_type` key
/// (`feed.serializers.FeedItemSerializer`, P-059's own docstring). So
/// each item is parsed through the EXISTING `PostPublicResponseDto`/
/// `ReelPublicResponseDto` (Part P-045) — the extra `content_type` key
/// is simply never read by those DTOs' `fromJson`, exactly the same
/// "extra keys naturally dropped at the boundary" pattern already used
/// by those two DTOs themselves for the owner-facing → public split.
/// No new per-item DTO class was written for this part.
library;

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/dio_client.dart';
import '../../content/data/dtos/post_public_response_dto.dart';
import '../../content/data/dtos/reel_public_response_dto.dart';
import '../domain/feed_item_entity.dart';
import '../domain/feed_page_entity.dart';
import '../domain/feed_repository.dart';

class FeedRepositoryImpl implements FeedRepository {
  FeedRepositoryImpl({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const _homePath = '/api/v1/feed/home/';

  @override
  Future<FeedPage> fetchHomeFeed({String? cursor}) async {
    final response = await _dio.get<Map<String, dynamic>>(
      _homePath,
      queryParameters: cursor == null ? null : {'cursor': cursor},
    );
    final data = response.data!;
    final rawItems = data['items'] as List<dynamic>;

    final items = rawItems.map((raw) {
      final json = raw as Map<String, dynamic>;
      final contentType = json['content_type'] as String;
      return switch (contentType) {
        'post' => PostFeedItem(
          PostPublicResponseDto.fromJson(json).toEntity(),
        ),
        'reel' => ReelFeedItem(
          ReelPublicResponseDto.fromJson(json).toEntity(),
        ),
        _ => throw FormatException(
          'Unknown feed content_type: "$contentType"',
        ),
      };
    }).toList();

    return FeedPage(items: items, nextCursor: data['next_cursor'] as String?);
  }
}

/// Exposes [FeedRepository] via Riverpod — a plain `Provider`, same
/// pattern as `productPublicRepositoryProvider` /
/// `businessProfilePublicRepositoryProvider`.
final feedRepositoryProvider = Provider<FeedRepository>(
  (ref) => FeedRepositoryImpl(dio: ref.watch(dioClientProvider)),
);