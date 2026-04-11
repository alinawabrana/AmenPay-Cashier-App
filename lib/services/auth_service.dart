import 'dart:developer' as developer;
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static final Uri _signupUri = Uri.parse('https://amenpay.org/api/signup');
  static final Uri _loginUri = Uri.parse('https://amenpay.org/api/login');
  static final Uri _forgotPasswordUri = Uri.parse(
    'https://amenpay.org/api/forgot-password',
  );
  static final Uri _resetPasswordUri = Uri.parse(
    'https://amenpay.org/api/reset-password',
  );
  static final Uri _registerDeviceUri = Uri.parse(
    'https://amenpay.org/api/devices/register',
  );
  static final Uri _validateDeviceUri = Uri.parse(
    'https://amenpay.org/api/pos/devices/validate',
  );

  static const String _tokenKey = 'auth_token';
  static const String _userIdKey = 'auth_user_id';
  static const MethodChannel _posDeviceMethods = MethodChannel(
    'posDevice/methods',
  );

  static Map<String, String> _jsonHeaders({String? token}) {
    return <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.trim().isNotEmpty)
        'Authorization': 'Bearer ${token.trim()}',
    };
  }

  static void _logHttp({
    required String label,
    required Uri uri,
    required Map<String, String> headers,
    String? requestBody,
    int? statusCode,
    String? responseBody,
  }) {
    final safeHeaders = Map<String, String>.from(headers);
    final auth = safeHeaders['Authorization'];
    if (auth != null && auth.isNotEmpty) {
      safeHeaders['Authorization'] = 'Bearer ***';
    }
    developer.log(
      jsonEncode(<String, dynamic>{
        'label': label,
        'url': uri.toString(),
        'headers': safeHeaders,
        'request_body': requestBody ?? '',
        'status_code': statusCode,
        'response_body': responseBody ?? '',
      }),
      name: 'AmenPayAuth',
    );
  }

  static Future<String?> getDeviceId() async {
    final res = await _posDeviceMethods.invokeMethod<dynamic>('getDeviceId');
    final id = res?.toString().trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  static Future<Map<String, dynamic>> signup({
    required String fullname,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String securityAnswer1,
    required String securityAnswer2,
  }) async {
    final payload = <String, dynamic>{
      'fullname': fullname.trim(),
      'email': email.trim(),
      'phone': phone.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
      'security_answer_1': securityAnswer1.trim(),
      'security_answer_2': securityAnswer2.trim(),
    };
    final requestBody = jsonEncode(payload);
    final res = await http.post(
      _signupUri,
      headers: _jsonHeaders(),
      body: requestBody,
    );
    _logHttp(
      label: 'signup',
      uri: _signupUri,
      headers: _jsonHeaders(),
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractErrorMessage(body) ?? 'Signup failed.');
    }

    return body;
  }

  static int? extractUserIdFromSignup(Map<String, dynamic> signupResponse) {
    int? parseId(dynamic idRaw) {
      if (idRaw is int) return idRaw;
      return int.tryParse(idRaw?.toString() ?? '');
    }

    final topLevelUserId = parseId(
      signupResponse['user_id'] ??
          signupResponse['userId'] ??
          signupResponse['id'],
    );
    if (topLevelUserId != null) return topLevelUserId;

    final user = signupResponse['user'];
    if (user is Map) {
      final nestedUserId = parseId(
        user['id'] ?? user['user_id'] ?? user['userId'],
      );
      if (nestedUserId != null) return nestedUserId;
    }

    final data = signupResponse['data'];
    if (data is Map) {
      final dataUserId = parseId(
        data['user_id'] ?? data['userId'] ?? data['id'],
      );
      if (dataUserId != null) return dataUserId;
      final dataUser = data['user'];
      if (dataUser is Map) {
        final nested = parseId(
          dataUser['id'] ?? dataUser['user_id'] ?? dataUser['userId'],
        );
        if (nested != null) return nested;
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> registerDevice({
    required String deviceId,
    required int merchantId,
  }) async {
    final payload = <String, dynamic>{
      'device_id': deviceId,
      'merchant_id': merchantId,
    };
    final requestBody = jsonEncode(payload);
    final res = await http.post(
      _registerDeviceUri,
      headers: _jsonHeaders(),
      body: requestBody,
    );
    _logHttp(
      label: 'register_device',
      uri: _registerDeviceUri,
      headers: _jsonHeaders(),
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(body) ?? 'Device registration failed.',
      );
    }
    return body;
  }

  static Future<String> login({
    required String email,
    required String password,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'password': password,
    };
    final requestBody = jsonEncode(payload);
    final res = await http.post(
      _loginUri,
      headers: _jsonHeaders(),
      body: requestBody,
    );
    _logHttp(
      label: 'login',
      uri: _loginUri,
      headers: _jsonHeaders(),
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractErrorMessage(body) ?? 'Login failed.');
    }

    final token = _extractToken(body);
    if (token == null || token.isEmpty) {
      throw Exception('Login response missing auth token.');
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
    final userId = _extractUserId(body);
    if (userId != null) {
      await prefs.setInt(_userIdKey, userId);
    }

    return token;
  }

  static Future<Map<String, dynamic>> verifySecurityQuestions({
    required String email,
    required String securityAnswer1,
    required String securityAnswer2,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'security_answer_1': securityAnswer1.trim(),
      'security_answer_2': securityAnswer2.trim(),
    };
    final requestBody = jsonEncode(payload);
    final res = await http.post(
      _forgotPasswordUri,
      headers: _jsonHeaders(),
      body: requestBody,
    );
    _logHttp(
      label: 'forgot_password',
      uri: _forgotPasswordUri,
      headers: _jsonHeaders(),
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(
        _extractErrorMessage(body) ?? 'Security verification failed.',
      );
    }
    return body;
  }

  static String? extractResetToken(Map<String, dynamic> response) {
    final direct = response['reset_token'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final data = response['data'];
    if (data is Map) {
      final nested = data['reset_token'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }

    return null;
  }

  static String? extractResetEmail(Map<String, dynamic> response) {
    final direct = response['email'];
    if (direct is String && direct.trim().isNotEmpty) {
      return direct.trim();
    }

    final data = response['data'];
    if (data is Map) {
      final nested = data['email'];
      if (nested is String && nested.trim().isNotEmpty) {
        return nested.trim();
      }
    }

    return null;
  }

  static Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String token,
    required String password,
    required String passwordConfirmation,
  }) async {
    final payload = <String, dynamic>{
      'email': email.trim(),
      'token': token.trim(),
      'password': password,
      'password_confirmation': passwordConfirmation,
    };
    final requestBody = jsonEncode(payload);
    final res = await http.post(
      _resetPasswordUri,
      headers: _jsonHeaders(),
      body: requestBody,
    );
    _logHttp(
      label: 'reset_password',
      uri: _resetPasswordUri,
      headers: _jsonHeaders(),
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception(_extractErrorMessage(body) ?? 'Password reset failed.');
    }
    return body;
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey);
    return token != null && token.trim().isNotEmpty;
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString(_tokenKey)?.trim();
    if (token == null || token.isEmpty) return null;
    return token;
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_userIdKey);
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_userIdKey);
  }

  static Future<DeviceValidationResult> validateCurrentDevice() async {
    final token = await getToken();
    if (token == null || token.isEmpty) {
      return const DeviceValidationResult(
        validated: false,
        message: 'Missing auth token.',
      );
    }

    final deviceId = await getDeviceId();
    if (deviceId == null || deviceId.isEmpty) {
      return const DeviceValidationResult(
        validated: false,
        message: 'Device ID unavailable.',
      );
    }

    final requestBody = jsonEncode(<String, dynamic>{'device_id': deviceId});
    final headers = _jsonHeaders(token: token);
    final res = await http.post(
      _validateDeviceUri,
      headers: headers,
      body: requestBody,
    );
    _logHttp(
      label: 'validate_device',
      uri: _validateDeviceUri,
      headers: headers,
      requestBody: requestBody,
      statusCode: res.statusCode,
      responseBody: res.body,
    );

    final body = _decodeBody(res.body);
    if (res.statusCode < 200 || res.statusCode >= 300) {
      return DeviceValidationResult(
        validated: false,
        message: _extractErrorMessage(body) ?? 'Device validation failed.',
      );
    }

    final validated = _extractValidated(body);
    return DeviceValidationResult(
      validated: validated,
      message: validated
          ? 'Device validated.'
          : (_extractErrorMessage(body) ?? 'This device is not validated.'),
    );
  }

  static Map<String, dynamic> _decodeBody(String body) {
    try {
      final dynamic decoded = jsonDecode(body);
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return Map<String, dynamic>.from(decoded);
      return <String, dynamic>{'data': decoded};
    } catch (_) {
      return <String, dynamic>{'raw': body};
    }
  }

  static String? _extractToken(Map<String, dynamic> json) {
    final direct = json['token'] ?? json['access_token'] ?? json['auth_token'];
    if (direct != null && direct.toString().trim().isNotEmpty) {
      return direct.toString().trim();
    }

    final data = json['data'];
    if (data is Map) {
      final nested =
          data['token'] ?? data['access_token'] ?? data['auth_token'];
      if (nested != null && nested.toString().trim().isNotEmpty) {
        return nested.toString().trim();
      }
    }
    return null;
  }

  static int? _extractUserId(Map<String, dynamic> json) {
    final user = json['user'];
    if (user is Map) {
      final id = user['id'];
      if (id is int) return id;
      return int.tryParse(id?.toString() ?? '');
    }

    final data = json['data'];
    if (data is Map) {
      final dataUser = data['user'];
      if (dataUser is Map) {
        final id = dataUser['id'];
        if (id is int) return id;
        return int.tryParse(id?.toString() ?? '');
      }
    }
    return null;
  }

  static bool _extractValidated(Map<String, dynamic> json) {
    bool? asBool(dynamic v) {
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) {
        final s = v.trim().toLowerCase();
        if (s == 'true' || s == 'validated' || s == 'active' || s == 'ok') {
          return true;
        }
        if (s == 'false' || s == 'invalid' || s == 'inactive') return false;
      }
      return null;
    }

    final candidates = <dynamic>[
      json['validated'],
      json['is_valid'],
      json['isValidated'],
      json['device_validated'],
      json['status'],
      if (json['data'] is Map) (json['data'] as Map)['validated'],
      if (json['data'] is Map) (json['data'] as Map)['is_valid'],
      if (json['data'] is Map) (json['data'] as Map)['status'],
    ];

    for (final c in candidates) {
      final b = asBool(c);
      if (b != null) return b;
    }

    return false;
  }

  static String? _extractErrorMessage(Map<String, dynamic> json) {
    final keys = <String>['message', 'error', 'detail'];
    for (final key in keys) {
      final value = json[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }

    final errors = json['errors'];
    if (errors is Map) {
      for (final entry in errors.entries) {
        final v = entry.value;
        if (v is List && v.isNotEmpty) {
          final first = v.first?.toString();
          if (first != null && first.trim().isNotEmpty) return first.trim();
        } else if (v is String && v.trim().isNotEmpty) {
          return v.trim();
        }
      }
    }

    final raw = json['raw']?.toString();
    if (raw != null && raw.trim().isNotEmpty) return raw.trim();
    return null;
  }
}

class DeviceValidationResult {
  final bool validated;
  final String message;

  const DeviceValidationResult({
    required this.validated,
    required this.message,
  });
}
