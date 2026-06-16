import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api_service.dart';

class AuthState {
  const AuthState({
    this.isLoading = true,
    this.isAuthenticated = false,
    this.accessToken,
    this.refreshToken,
    this.user,
  });

  final bool isLoading;
  final bool isAuthenticated;
  final String? accessToken;
  final String? refreshToken;
  final Map<String, dynamic>? user;

  String? get role => user?['role'] as String?;

  AuthState copyWith({
    bool? isLoading,
    bool? isAuthenticated,
    String? accessToken,
    String? refreshToken,
    Map<String, dynamic>? user,
  }) {
    return AuthState(
      isLoading: isLoading ?? this.isLoading,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      user: user ?? this.user,
    );
  }
}

final secureStorageProvider = Provider<FlutterSecureStorage>((ref) {
  return const FlutterSecureStorage();
});

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(secureStorageProvider),
    ref.read(apiServiceProvider),
  );
});

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._storage, this._apiService) : super(const AuthState()) {
    _restoreSession();
  }

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userKey = 'user_payload';

  final FlutterSecureStorage _storage;
  final ApiService _apiService;

  Future<void> _restoreSession() async {
    try {
      final accessToken = await _storage.read(key: _accessTokenKey);
      final refreshToken = await _storage.read(key: _refreshTokenKey);
      final userJson = await _storage.read(key: _userKey);

      if (accessToken == null || refreshToken == null || userJson == null) {
        state = const AuthState(isLoading: false);
        return;
      }

      state = AuthState(
        isLoading: false,
        isAuthenticated: true,
        accessToken: accessToken,
        refreshToken: refreshToken,
        user: jsonDecode(userJson) as Map<String, dynamic>,
      );
    } catch (_) {
      await _storage.deleteAll();
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> login(String phone, String password) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.post(
        '/auth/login',
        data: {'phone': phone, 'password': password},
      );
      await _persist(response);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> register(Map<String, dynamic> payload) async {
    state = state.copyWith(isLoading: true);
    try {
      final response = await _apiService.post('/auth/register', data: payload);
      await _persist(response);
    } catch (_) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> logout() async {
    final accessToken = state.accessToken;
    try {
      if (accessToken != null) {
        await _apiService.post('/auth/logout', token: accessToken);
      }
    } catch (_) {
      // Ignore remote logout failures and clear the local session regardless.
    } finally {
      await _storage.deleteAll();
      state = const AuthState(isLoading: false);
    }
  }

  Future<void> _persist(Map<String, dynamic> response) async {
    final user = response['user'] as Map<String, dynamic>;
    final tokens = response['tokens'] as Map<String, dynamic>;

    await _storage.write(
      key: _accessTokenKey,
      value: tokens['accessToken'] as String,
    );
    await _storage.write(
      key: _refreshTokenKey,
      value: tokens['refreshToken'] as String,
    );
    await _storage.write(key: _userKey, value: jsonEncode(user));

    state = AuthState(
      isLoading: false,
      isAuthenticated: true,
      accessToken: tokens['accessToken'] as String,
      refreshToken: tokens['refreshToken'] as String,
      user: user,
    );
  }
}
