import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import 'api_service.dart';

class AuthService extends ChangeNotifier {
  User? _currentUser;
  String? _accessToken;
  bool _isLoading = false;
  String? _error;

  // Getters
  User? get currentUser => _currentUser;
  String? get accessToken => _accessToken;
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
      final prefs = await SharedPreferences.getInstance();
      _accessToken = prefs.getString('access_token');

      if (_accessToken != null) {
        try {
          // Validate token with backend
          final response = await ApiService.validateToken(_accessToken!);
          if (response.success && response.user != null) {
            _currentUser = response.user;
          } else {
            // Token is invalid, clear it
            await _clearToken();
          }
        } catch (e) {
          // Backend not available, but token exists - keep it
          // Will validate when user tries to make a request
          if (kDebugMode)
            print('Backend unavailable during token validation: $e');
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
    } catch (e) {
      if (kDebugMode) print('Error clearing token: $e');
    }
    _currentUser = null;
    _accessToken = null;
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
        _currentUser = response.user;
        await _saveToken(_accessToken!);
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
        _currentUser = response.user;
        await _saveToken(_accessToken!);
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
          await ApiService.logout(_accessToken!);
        } catch (e) {
          if (kDebugMode) print('Error calling logout endpoint: $e');
          // Continue even if logout endpoint fails
        }
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('access_token');
    } catch (e) {
      if (kDebugMode) print('Error clearing token: $e');
    }

    _currentUser = null;
    _accessToken = null;
    _error = null;
    notifyListeners();
  }

  // Clear error message
  void clearError() {
    _error = null;
    notifyListeners();
  }
}
