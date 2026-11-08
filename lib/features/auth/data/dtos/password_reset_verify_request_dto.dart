/// Body of `POST /api/v1/auth/password-reset/verify/`: `{email, otp}`
/// (`PasswordResetVerifySerializer`). The OTP is sent exactly as typed
/// (after trimming by the caller): the backend decides whether it is valid.
class PasswordResetVerifyRequestDto {
  const PasswordResetVerifyRequestDto({required this.email, required this.otp});

  final String email;
  final String otp;

  Map<String, dynamic> toJson() => {'email': email, 'otp': otp};

  @override
  String toString() => 'PasswordResetVerifyRequestDto(<redacted>)';
}
