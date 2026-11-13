/// Pure JSON mirror of `GET /api/v1/auth/me/`'s response shape
/// (`{id, email, account_type, is_moderator, is_staff}`,
/// `accounts.views.MeView` — no serializer on the backend side, see that
/// view's own docstring) — same convention as every other
/// `*ResponseDto` in this project (e.g. `RegisterResponseDto`): no
/// domain imports, raw wire field names.
///
/// `is_moderator`/`is_staff` were added to the backend ahead of Part
/// P-040 (Flutter moderator UI) specifically so this app has a real
/// source of truth for role-gating the `/moderation` route.
class MeResponseDto {
  const MeResponseDto({
    required this.id,
    required this.email,
    required this.accountType,
    required this.isModerator,
    required this.isStaff,
    this.displayName = '',
    this.avatarUrl,
  });

  factory MeResponseDto.fromJson(Map<String, dynamic> json) {
    return MeResponseDto(
      id: json['id'] as int,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      isModerator: json['is_moderator'] as bool,
      isStaff: json['is_staff'] as bool,
      displayName: switch (json['display_name']) {
        final String name => name,
        _ => '',
      },
      avatarUrl: switch (json['avatar']) {
        final String url when url.isNotEmpty => url,
        _ => null,
      },
    );
  }

  final int id;
  final String email;

  /// Raw wire string: `"customer"` | `"business"` — mapped to
  /// [AccountType] at the repository's DTO→entity boundary, not here
  /// (this DTO stays a pure JSON mirror, matching `RegisterResponseDto`'s
  /// own convention).
  final String accountType;

  final bool isModerator;
  final bool isStaff;

  /// Part P-116B: `display_name` (empty when absent).
  final String displayName;

  /// Part P-116B: `avatar` URL, or null for null / empty / missing.
  final String? avatarUrl;
}
