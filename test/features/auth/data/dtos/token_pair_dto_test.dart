import 'package:flutter_test/flutter_test.dart';
import 'package:social_commerce_app/features/auth/data/dtos/token_pair_dto.dart';

void main() {
  test('fromJson/toJson round-trip matches login/refresh response shape', () {
    final json = {
      'access': 'access-token-value',
      'refresh': 'refresh-token-value',
    };

    final dto = TokenPairDto.fromJson(json);

    expect(dto.access, 'access-token-value');
    expect(dto.refresh, 'refresh-token-value');
    expect(dto.toJson(), json);
  });
}
