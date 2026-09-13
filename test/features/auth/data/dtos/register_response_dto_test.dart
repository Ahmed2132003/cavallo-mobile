import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/data/dtos/register_response_dto.dart';

void main() {
  test(
    'fromJson/toJson round-trip matches the real backend response shape',
    () {
      final json = {
        'id': 3,
        'email': 'customer@example.com',
        'account_type': 'customer',
      };

      final dto = RegisterResponseDto.fromJson(json);

      expect(dto.id, 3);
      expect(dto.email, 'customer@example.com');
      expect(dto.accountType, 'customer');
      expect(dto.toJson(), json);
    },
  );
}
