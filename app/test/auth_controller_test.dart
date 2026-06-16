import 'package:alisholibrary/src/core/api_service.dart';
import 'package:alisholibrary/src/core/auth_controller.dart';
import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeApiService extends ApiService {
  FakeApiService({required this.postResponses}) : super(Dio());

  final Map<String, Map<String, dynamic>> postResponses;
  final List<String> postedPaths = <String>[];

  @override
  Future<Map<String, dynamic>> post(
    String path, {
    String? token,
    Map<String, dynamic>? data,
  }) async {
    postedPaths.add(path);
    return postResponses[path] ?? <String, dynamic>{};
  }
}

Future<void> settleController() {
  return Future<void>.delayed(const Duration(milliseconds: 20));
}

void main() {
  const storage = FlutterSecureStorage();

  setUp(() {
    FlutterSecureStorage.setMockInitialValues(<String, String>{});
  });

  test('restores an authenticated session from secure storage', () async {
    FlutterSecureStorage.setMockInitialValues(<String, String>{
      'access_token': 'stored-access',
      'refresh_token': 'stored-refresh',
      'user_payload': '{"role":"ADMIN","fullName":"Admin User"}',
    });

    final controller = AuthController(
      storage,
      FakeApiService(postResponses: const <String, Map<String, dynamic>>{}),
    );

    await settleController();

    expect(controller.state.isLoading, isFalse);
    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.accessToken, 'stored-access');
    expect(controller.state.role, 'ADMIN');
  });

  test('login persists tokens and user payload', () async {
    final api = FakeApiService(
      postResponses: <String, Map<String, dynamic>>{
        '/auth/login': <String, dynamic>{
          'user': <String, dynamic>{
            'role': 'CUSTOMER',
            'fullName': 'Customer User',
            'phone': '07722222222',
          },
          'tokens': <String, dynamic>{
            'accessToken': 'login-access',
            'refreshToken': 'login-refresh',
          },
        },
      },
    );
    final controller = AuthController(storage, api);

    await settleController();
    await controller.login('07722222222', 'Customer@12345');

    expect(controller.state.isAuthenticated, isTrue);
    expect(controller.state.role, 'CUSTOMER');
    expect(await storage.read(key: 'access_token'), 'login-access');
    expect(await storage.read(key: 'refresh_token'), 'login-refresh');
  });

  test('logout clears secure storage and resets auth state', () async {
    final api = FakeApiService(
      postResponses: <String, Map<String, dynamic>>{
        '/auth/login': <String, dynamic>{
          'user': <String, dynamic>{
            'role': 'DELIVERY',
            'fullName': 'Delivery User',
            'phone': '07711111111',
          },
          'tokens': <String, dynamic>{
            'accessToken': 'delivery-access',
            'refreshToken': 'delivery-refresh',
          },
        },
        '/auth/logout': <String, dynamic>{'success': true},
      },
    );
    final controller = AuthController(storage, api);

    await settleController();
    await controller.login('07711111111', 'Delivery@12345');
    await controller.logout();

    expect(controller.state.isAuthenticated, isFalse);
    expect(controller.state.isLoading, isFalse);
    expect(await storage.read(key: 'access_token'), isNull);
    expect(api.postedPaths, contains('/auth/logout'));
  });
}
