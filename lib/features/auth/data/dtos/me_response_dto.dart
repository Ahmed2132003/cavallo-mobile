/// Pure JSON mirror of `GET /api/v1/auth/me/`'s response shape
/// (`{id, email, account_type}`, `accounts.serializers.MeSerializer`) —
/// same convention as every other `*ResponseDto` in this project (e.g.
/// `RegisterResponseDto`): no domain imports, raw wire field names.
class MeResponseDto {
  const MeResponseDto({
    required this.id,
    required this.email,
    required this.accountType,
  });

  factory MeResponseDto.fromJson(Map<String, dynamic> json) {
    return MeResponseDto(
      id: json['id'] as int,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
    );
  }

  final int id;
  final String email;

  /// Raw wire string: `"customer"` | `"business"` — mapped to
  /// [AccountType] at the repository's DTO→entity boundary, not here
  /// (this DTO stays a pure JSON mirror, matching `RegisterResponseDto`'s
  /// own convention).
  final String accountType;
}