/// Part P-020 scope. Shared by both `POST /api/v1/auth/login/` and
/// `POST /api/v1/auth/refresh/` — both return the exact same
/// `{"access": ..., "refresh": ...}` shape (confirmed against
/// `accounts/views.py::LoginView.post` / the real login response
/// captured during backend validation, and simplejwt's stock
/// `TokenRefreshView` response with `ROTATE_REFRESH_TOKENS=True`).
///
/// Named `TokenPairDto` rather than `AuthResponseDto` (the part spec's
/// original name) since it deliberately carries no user fields at all —
/// see `AuthRepository`'s module docstring for why login/refresh don't
/// return a `User`.
class TokenPairDto {
  const TokenPairDto({required this.access, required this.refresh});

  factory TokenPairDto.fromJson(Map<String, dynamic> json) {
    return TokenPairDto(
      access: json['access'] as String,
      refresh: json['refresh'] as String,
    );
  }

  final String access;
  final String refresh;

  Map<String, dynamic> toJson() => {'access': access, 'refresh': refresh};
}
