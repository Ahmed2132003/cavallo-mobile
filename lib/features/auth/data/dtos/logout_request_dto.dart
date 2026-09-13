/// Part P-020 scope. Field name confirmed against
/// `accounts/serializers.py::LogoutSerializer` (Part P-018) on the real
/// backend — body is just `{"refresh": ...}`; the access token goes in
/// the `Authorization` header instead (attached automatically by
/// `AuthInterceptor`, since `LogoutView` requires `IsAuthenticated`).
class LogoutRequestDto {
  const LogoutRequestDto({required this.refresh});

  final String refresh;

  Map<String, dynamic> toJson() => {'refresh': refresh};
}
