/// Part P-020 scope. Field names confirmed against
/// `accounts/serializers.py::RegisterSerializer` (Part P-017) on the real
/// backend — `email`, `password`, `password_confirm`, `account_type` —
/// not assumed.
class RegisterRequestDto {
  const RegisterRequestDto({
    required this.email,
    required this.password,
    required this.passwordConfirm,
    required this.accountType,
  });

  final String email;
  final String password;
  final String passwordConfirm;

  /// Raw wire value (`"customer"` / `"business"`) — already converted
  /// from the domain `AccountType` enum by the caller
  /// (auth_repository_impl.dart), so this DTO stays a pure
  /// data-shape/JSON concern with no domain-layer imports.
  final String accountType;

  Map<String, dynamic> toJson() => {
    'email': email,
    'password': password,
    'password_confirm': passwordConfirm,
    'account_type': accountType,
  };
}
