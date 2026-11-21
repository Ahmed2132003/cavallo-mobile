/// Body of `POST /api/v1/auth/password-reset/request/`: `{email}` only
/// (`PasswordResetRequestSerializer`, backend `accounts/serializers.py`).
///
/// The backend answers `202 {"detail": ...}` with the same text for every
/// well-formed email, so there is deliberately no response DTO: nothing in
/// that body is ever used.
class PasswordResetRequestDto {
  const PasswordResetRequestDto({required this.email});

  final String email;

  Map<String, dynamic> toJson() => {'email': email};

  /// Never prints the email (this object may end up in a log by accident).
  @override
  String toString() => 'PasswordResetRequestDto(<redacted>)';
}
