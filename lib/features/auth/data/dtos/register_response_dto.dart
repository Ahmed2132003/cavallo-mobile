/// Part P-020 scope. Field names confirmed against
/// `accounts/views.py::RegisterView.create` (Part P-017) on the real
/// backend — `{"id": ..., "email": ..., "account_type": ...}`, no
/// `password` and, notably, **no tokens** (see `AuthRepository`'s module
/// docstring for why registration doesn't return `access`/`refresh`).
class RegisterResponseDto {
  const RegisterResponseDto({
    required this.id,
    required this.email,
    required this.accountType,
  });

  factory RegisterResponseDto.fromJson(Map<String, dynamic> json) {
    return RegisterResponseDto(
      id: json['id'] as int,
      email: json['email'] as String,
      accountType: json['account_type'] as String,
    );
  }

  final int id;
  final String email;

  /// Raw wire value (`"customer"` / `"business"`) — mapped to the
  /// domain `AccountType` enum by auth_repository_impl.dart, never
  /// exposed past the repository as a bare string.
  final String accountType;

  Map<String, dynamic> toJson() => {
    'id': id,
    'email': email,
    'account_type': accountType,
  };
}
