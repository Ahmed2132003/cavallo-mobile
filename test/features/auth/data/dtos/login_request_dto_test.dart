import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/data/dtos/login_request_dto.dart';

void main() {
  test('toJson sends email/password only — never username', () {
    const dto = LoginRequestDto(
      email: 'trader@example.com',
      password: 'S3curePass!',
    );

    expect(dto.toJson(), {
      'email': 'trader@example.com',
      'password': 'S3curePass!',
    });
  });
}
