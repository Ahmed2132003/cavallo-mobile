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
  });

  factory MeResponseDto.fromJson(Map<String, dynamic> json) {
    return MeResponseDto(
      id: json['id'] as int,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
      isModerator: json['is_moderator'] as bool,
      isStaff: json['is_staff'] as bool,
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
}