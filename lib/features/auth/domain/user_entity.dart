/// Part P-020 scope: the clean domain representation of an authenticated
/// user — no transport concerns (no raw JSON keys, no DTO types) cross
/// this boundary, per Clean Architecture Section 11.
///
/// Deliberately minimal (id, email, accountType only), mirroring exactly
/// what `POST /api/v1/auth/register/` returns (accounts/views.py,
/// RegisterView.create — confirmed against the real backend, not
/// assumed): `{"id": ..., "email": ..., "account_type": ...}`. No
/// `BusinessProfile`/`business_type` fields exist on this entity because
/// none exist on the backend at this point in the flow either (Part
/// P-017's own scope decision, deferred to Phase 4 / Part P-042).
library;

/// Mirrors `accounts.models.User.ACCOUNT_TYPE_CHOICES` on the backend
/// exactly (`"customer"` / `"business"`) — confirmed from
/// `accounts/models.py`, not guessed.
enum AccountType {
  customer,
  business;

  /// Parses the backend's raw `account_type` string. Throws
  /// [FormatException] on anything unrecognized rather than silently
  /// defaulting — an unknown value here means the backend's contract
  /// changed underneath this app and callers should know immediately
  /// instead of getting a wrong role.
  static AccountType fromWire(String value) {
    switch (value) {
      case 'customer':
        return AccountType.customer;
      case 'business':
        return AccountType.business;
      default:
        throw FormatException('Unknown account_type from backend: $value');
    }
  }

  /// Inverse of [fromWire] — used when this app needs to send the value
  /// back to the backend (e.g. the register request body).
  String toWire() {
    switch (this) {
      case AccountType.customer:
        return 'customer';
      case AccountType.business:
        return 'business';
    }
  }
}

/// A registered user, as far as the domain/presentation layers need to
/// know. Constructed only by [AuthRepository.register]'s mapping step
/// (auth_repository_impl.dart) — see that file's module docstring for why
/// [AuthRepository.login]/`refresh` do NOT also return one of these.
class User {
  const User({
    required this.id,
    required this.email,
    required this.accountType,
  });

  final int id;
  final String email;
  final AccountType accountType;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is User &&
          other.id == id &&
          other.email == email &&
          other.accountType == accountType);

  @override
  int get hashCode => Object.hash(id, email, accountType);

  @override
  String toString() =>
      'User(id: $id, email: $email, accountType: $accountType)';
}
