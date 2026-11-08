/// Body of `POST /api/v1/auth/password-reset/confirm/`:
/// `{email, reset_token, new_password}` (`PasswordResetConfirmSerializer`).
///
/// Success is `200 {"detail": "Password has been reset."}`; the body is
/// not used, so there is no response DTO.
class PasswordResetConfirmRequestDto {
  const PasswordResetConfirmRequestDto({
    required this.email,
    required this.resetToken,
    required this.newPassword,
  });

  final String email;
  final String resetToken;
  final String newPassword;

  Map<String, dynamic> toJson() => {
    'email': email,
    'reset_token': resetToken,
    'new_password': newPassword,
  };

  @override
  String toString() => 'PasswordResetConfirmRequestDto(<redacted>)';
}
