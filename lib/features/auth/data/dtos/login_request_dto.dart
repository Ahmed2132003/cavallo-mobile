/// Part P-020 scope. Field names confirmed against
/// `accounts/serializers.py::LoginSerializer` (Part P-018) on the real
/// backend — `email`, `password` only (never `username`; the backend
/// bridges email → its internal `username` field itself).
class LoginRequestDto {
  const LoginRequestDto({required this.email, required this.password});

  final String email;
  final String password;

  Map<String, dynamic> toJson() => {'email': email, 'password': password};
}
