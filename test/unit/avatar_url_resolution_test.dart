import 'package:flutter_test/flutter_test.dart';
import 'package:url_defender/services/api_client.dart';

void main() {
  test('rewrites a legacy managed avatar to the active API origin', () {
    final resolved = ApiClient.resolveAssetUrl(
      'http://localhost:8001/uploads/avatars/user-photo.jpg',
    );

    expect(
      resolved,
      '${ApiClient.baseUrl.replaceFirst('/api/v1', '')}/uploads/avatars/user-photo.jpg',
    );
  });

  test('leaves external avatars unchanged', () {
    const external = 'https://images.example.com/profile.jpg';
    expect(ApiClient.resolveAssetUrl(external), external);
  });
}
