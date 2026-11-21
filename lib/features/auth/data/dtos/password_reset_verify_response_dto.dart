/// Response of `POST /api/v1/auth/password-reset/verify/` on success:
/// `200 {"reset_token": "<opaque string>"}` (`PasswordResetVerifyView`).
///
/// This is NOT a login token: it is a one-time value (valid 300 seconds on
/// the backend) that only `password-reset/confirm/` accepts. It is never
/// written to `SecureTokenStorage`.
class PasswordResetVerifyResponseDto {
  const PasswordResetVerifyResponseDto({required this.resetToken});

  factory PasswordResetVerifyResponseDto.fromJson(Map<String, dynamic> json) {
    return PasswordResetVerifyResponseDto(
      resetToken: json['reset_token'] as String,
    );
  }

  final String resetToken;

  @override
  String toString() => 'PasswordResetVerifyResponseDto(<redacted>)';
}
