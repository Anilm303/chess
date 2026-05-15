import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../config/backend_config.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _accessToken;
  String? _refreshToken;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
  String? get refreshToken => _refreshToken;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isAuthenticated => _accessToken != null && _currentUser != null;

  AuthService() {
    _initializeAsync();
  }

  // Initialize asynchronously without blocking build
  void _initializeAsync() {
    _loadStoredToken();
  }

  // Load token from secure storage
  Future<void> _loadStoredToken() async {
    try {
      if (BackendConfig.needsUserConfiguredBaseUrl) {
        notifyListeners();
        return;
      }

      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');
      _refreshToken = prefs.getString('refresh_token');

      if (_accessToken != null) {
        try {
          // Validate token with backend
          final response = await ApiService.validateToken(_accessToken!);
          if (response.success && response.user != null) {
            _currentUser = response.user;
          } else {
            // Try refresh token before clearing the session.
            final refreshed = await _refreshIfPossible();
            if (!refreshed) {
              await _clearToken();
            }
          }
        } catch (e) {
          if (kDebugMode)
            print('Backend unavailable during token validation: $e');
          await _refreshIfPossible();
        }
      }
      notifyListeners();
    } catch (e) {
      if (kDebugMode) print('Error loading stored token: $e');
    }
  }

  // Clear token without notifying (for internal use)
  Future<void> _clearToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    } catch (e) {
      if (kDebugMode) print('Error clearing token: $e');
    }
    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
  }

  // Save token to secure storage
  Future<void> _saveToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('access_token', token);
    } catch (e) {
      if (kDebugMode) print('Error saving token: $e');
    }
  }

  Future<void> _saveRefreshToken(String token) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('refresh_token', token);
    } catch (e) {
      if (kDebugMode) print('Error saving refresh token: $e');
    }
  }

  Future<bool> _refreshIfPossible() async {
    if (_refreshToken == null || _refreshToken!.isEmpty) {
      return false;
    }

    try {
      final response = await ApiService.refreshAccessToken(_refreshToken!);
      if (response.success && response.accessToken != null) {
        _accessToken = response.accessToken;
        if (response.user != null) {
          _currentUser = response.user;
        }
        await _saveToken(_accessToken!);
        if (response.refreshToken != null) {
          _refreshToken = response.refreshToken;
          await _saveRefreshToken(_refreshToken!);
        }
        return true;
      }
    } catch (e) {
      if (kDebugMode) print('Refresh failed: $e');
    }

    return false;
  }

  // Register new user
  Future<bool> register({
    required String username,
    required String email,
    required String firstName,
    required String lastName,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.register(
        username: username,
        email: email,
        firstName: firstName,
        lastName: lastName,
        password: password,
      );

      if (response.success &&
          response.accessToken != null &&
          response.user != null) {
        _accessToken = response.accessToken;
        _refreshToken = response.refreshToken;
        _currentUser = response.user;
        await _saveToken(_accessToken!);
        if (_refreshToken != null) {
          await _saveRefreshToken(_refreshToken!);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Registration failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiService.login(
        username: username,
        password: password,
      );

      if (response.success &&
          response.accessToken != null &&
          response.user != null) {
        _accessToken = response.accessToken;
        _refreshToken = response.refreshToken;
        _currentUser = response.user;
        await _saveToken(_accessToken!);
        if (_refreshToken != null) {
          await _saveRefreshToken(_refreshToken!);
        }
        _isLoading = false;
        notifyListeners();
        return true;
      } else {
        _error = response.message;
        _isLoading = false;
        notifyListeners();
        return false;
      }
    } catch (e) {
      _error = 'Login failed: $e';
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // Logout user
  Future<void> logout() async {
    try {
      // Call backend logout endpoint if token exists
      if (_accessToken != null) {
        try {
          await ApiService.logout(_accessToken!, refreshToken: _refreshToken);
        } catch (e) {
          if (kDebugMode) print('Error calling logout endpoint: $e');
          // Continue even if logout endpoint fails
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
      await prefs.remove('refresh_token');
    } catch (e) {
      if (kDebugMode) print('Error clearing token: $e');
    }

    _currentUser = null;
    _accessToken = null;
    _refreshToken = null;
    _error = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
