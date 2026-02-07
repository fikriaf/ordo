import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter/foundation.dart';

class AuthService extends ChangeNotifier {
  static const String baseUrl = 'https://ordo-production.up.railway.app/api/v1';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();
  
  String? _token;
  Map<String, dynamic>? _user;

  bool get isAuthenticated => _token != null;
  Map<String, dynamic>? get user => _user;
  String? get token => _token;

  /// Initialize - load saved token and user data
  Future<void> initialize() async {
    print('🔵 AuthService: Initializing...');
    _token = await _storage.read(key: 'auth_token');
    print('🔵 AuthService: Token loaded: ${_token != null ? "YES" : "NO"}');
    
    // Load saved user data
    if (_token != null) {
      final userJson = await _storage.read(key: 'user_data');
      if (userJson != null) {
        try {
          _user = jsonDecode(userJson);
          print('🔵 AuthService: User data loaded: ${_user?['email']}');
        } catch (e) {
          print('🔴 AuthService: Failed to parse user data: $e');
          _user = null;
        }
      }
    }
    
    notifyListeners();
    print('🔵 AuthService: Initialized. isAuthenticated=$isAuthenticated, user=${_user?['email']}');
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      print('🔵 Attempting register to: $baseUrl/auth/register');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
          'username': username,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Connection timeout - server tidak merespon dalam 60 detik');
        },
      );

      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode == 201) {
        final responseData = jsonDecode(response.body);
        print('🔵 Register response data: $responseData');
        
        // Check if response is successful
        if (responseData['success'] == false) {
          return {'success': false, 'error': responseData['error'] ?? 'Registration failed'};
        }
        
        // Extract data
        final data = responseData['data'];
        if (data == null) {
          return {'success': false, 'error': 'No data in response'};
        }
        
        _token = data['token'];
        _user = data['user'];
        
        // Save token and user data
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(key: 'user_data', value: jsonEncode(_user));
        
        print('🔵 Register success! Token and user data saved.');
        notifyListeners();
        
        return {'success': true, 'user': _user};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['message'] ?? 'Registration failed'};
      }
    } catch (e) {
      print('🔴 Register error: $e');
      print('🔴 Error type: ${e.runtimeType}');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Login
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    try {
      print('🔵 Attempting login to: $baseUrl/auth/login');
      
      final response = await http.post(
        Uri.parse('$baseUrl/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'password': password,
        }),
      ).timeout(
        const Duration(seconds: 60),
        onTimeout: () {
          throw Exception('Connection timeout - server tidak merespon dalam 60 detik');
        },
      );

      print('🔵 Response status: ${response.statusCode}');
      print('🔵 Response body: ${response.body}');

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('🔵 Login response data: $responseData');
        
        // Check if response is successful
        if (responseData['success'] == false) {
          return {'success': false, 'error': responseData['error'] ?? 'Login failed'};
        }
        
        // Extract data
        final data = responseData['data'];
        if (data == null) {
          return {'success': false, 'error': 'No data in response'};
        }
        
        _token = data['token'];
        _user = data['user'];
        
        // Save token and user data
        await _storage.write(key: 'auth_token', value: _token);
        await _storage.write(key: 'user_data', value: jsonEncode(_user));
        
        print('🔵 Login success! Token and user data saved.');
        notifyListeners();
        
        return {'success': true, 'user': _user};
      } else {
        final error = jsonDecode(response.body);
        return {'success': false, 'error': error['error'] ?? error['message'] ?? 'Login failed'};
      }
    } catch (e) {
      print('🔴 Login error: $e');
      print('🔴 Error type: ${e.runtimeType}');
      return {'success': false, 'error': 'Network error: $e'};
    }
  }

  /// Logout
  Future<void> logout() async {
    _token = null;
    _user = null;
    await _storage.delete(key: 'auth_token');
    await _storage.delete(key: 'user_data');
    notifyListeners();
    print('🔵 Logout complete. Token and user data deleted.');
  }

  /// Load user profile
  Future<void> _loadUserProfile() async {
    if (_token == null) return;

    try {
      print('🔵 Loading user profile...');
      final response = await http.get(
        Uri.parse('$baseUrl/auth/profile'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_token',
        },
      );

      if (response.statusCode == 200) {
        _user = jsonDecode(response.body);
        print('🔵 User profile loaded: ${_user?['email']}');
      } else {
        print('🔴 Token invalid, logging out...');
        // Token invalid, logout
        await logout();
      }
    } catch (e) {
      print('🔴 Failed to load user profile: $e');
    }
  }

  /// Get auth headers
  Map<String, String> getAuthHeaders() {
    return {
      'Content-Type': 'application/json',
      if (_token != null) 'Authorization': 'Bearer $_token',
    };
  }
}
