import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

const String _localPalmMatcherBaseUrl = String.fromEnvironment(
  'AMENPAY_LOCAL_PALM_MATCHER_URL',
  defaultValue: 'http://127.0.0.1:8080',
);

const String _localPalmMatcherKey = String.fromEnvironment(
  'AMENPAY_LOCAL_PALM_MATCHER_KEY',
  defaultValue: '',
);

class PalmMatcherException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const PalmMatcherException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  @override
  String toString() => '$code: $message';
}

class PalmMatcherHealth {
  final bool sdkReady;
  final bool syncReady;
  final String syncMessage;

  const PalmMatcherHealth({
    required this.sdkReady,
    required this.syncReady,
    required this.syncMessage,
  });
}

class PalmMatcherEnrollResponse {
  final bool success;
  final bool matchedExisting;
  final String? userId;
  final String palmId;
  final String? voucher;
  final double? similarRgb;
  final double? similarNir;
  final int? palmType;
  final double? score;
  final String? mode;

  const PalmMatcherEnrollResponse({
    required this.success,
    required this.matchedExisting,
    required this.palmId,
    this.userId,
    this.voucher,
    this.similarRgb,
    this.similarNir,
    this.palmType,
    this.score,
    this.mode,
  });
}

class PalmMatcherRecognizeResponse {
  final bool success;
  final bool matched;
  final String? userId;
  final String? palmId;
  final String? voucher;
  final double? similarRgb;
  final double? similarNir;
  final String? mode;
  final String? message;

  const PalmMatcherRecognizeResponse({
    required this.success,
    required this.matched,
    this.userId,
    this.palmId,
    this.voucher,
    this.similarRgb,
    this.similarNir,
    this.mode,
    this.message,
  });
}

class PalmMatcherService {
  PalmMatcherService._();

  static final PalmMatcherService instance = PalmMatcherService._();

  Uri _uri(String path) => Uri.parse('$_localPalmMatcherBaseUrl$path');

  Map<String, String> get _headers {
    if (_localPalmMatcherKey.trim().isEmpty) {
      throw const PalmMatcherException(
        code: 'MATCHER_KEY_MISSING',
        message:
            'Local matcher key is not configured. Set AMENPAY_LOCAL_PALM_MATCHER_KEY.',
      );
    }
    return <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
      'X-Palm-Service-Key': _localPalmMatcherKey.trim(),
    };
  }

  Future<Map<String, dynamic>> _request({
    required String method,
    required Uri uri,
    Map<String, dynamic>? body,
  }) async {
    try {
      late http.Response res;
      if (method == 'GET') {
        res = await http.get(uri, headers: _headers).timeout(
              const Duration(seconds: 5),
            );
      } else {
        res = await http
            .post(
              uri,
              headers: _headers,
              body: jsonEncode(body ?? const <String, dynamic>{}),
            )
            .timeout(const Duration(seconds: 10));
      }

      Map<String, dynamic> payload = <String, dynamic>{};
      if (res.body.trim().isNotEmpty) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          payload = decoded;
        } else if (decoded is Map) {
          payload = Map<String, dynamic>.from(decoded);
        } else {
          payload = <String, dynamic>{'data': decoded};
        }
      }

      if (res.statusCode < 200 || res.statusCode >= 300) {
        final message = (payload['message'] ??
                payload['error'] ??
                payload['detail'] ??
                'Local matcher request failed.')
            .toString();
        throw PalmMatcherException(
          code: 'MATCHER_HTTP_${res.statusCode}',
          message: message,
          statusCode: res.statusCode,
        );
      }

      return payload;
    } on PalmMatcherException {
      rethrow;
    } on TimeoutException {
      throw const PalmMatcherException(
        code: 'MATCHER_UNAVAILABLE',
        message: 'Local palm matcher did not respond in time.',
      );
    } on SocketException {
      throw const PalmMatcherException(
        code: 'MATCHER_UNAVAILABLE',
        message: 'Local palm matcher is unavailable on 127.0.0.1:8080.',
      );
    } on HttpException catch (e) {
      throw PalmMatcherException(
        code: 'MATCHER_UNAVAILABLE',
        message: e.message,
      );
    } on FormatException {
      throw const PalmMatcherException(
        code: 'MATCHER_BAD_RESPONSE',
        message: 'Local palm matcher returned an invalid response.',
      );
    }
  }

  Future<PalmMatcherHealth> health() async {
    final payload = await _request(method: 'GET', uri: _uri('/health'));
    return PalmMatcherHealth(
      sdkReady: payload['sdk_ready'] == true,
      syncReady: payload['sync_ready'] == true,
      syncMessage: (payload['sync_message'] ?? '').toString(),
    );
  }

  Future<PalmMatcherHealth> waitUntilReady({
    Duration timeout = const Duration(seconds: 12),
    Duration interval = const Duration(milliseconds: 800),
  }) async {
    final deadline = DateTime.now().add(timeout);
    PalmMatcherHealth? latest;
    while (DateTime.now().isBefore(deadline)) {
      latest = await health();
      if (latest.sdkReady && latest.syncReady) {
        return latest;
      }
      await Future<void>.delayed(interval);
    }

    final message = latest == null
        ? 'Local palm matcher is unavailable.'
        : latest.syncMessage.trim().isNotEmpty
            ? latest.syncMessage.trim()
            : !latest.sdkReady
                ? 'Local palm matcher SDK is not ready yet.'
                : 'Local palm matcher startup sync is still in progress.';
    throw PalmMatcherException(
      code: 'MATCHER_NOT_READY',
      message: message,
    );
  }

  Future<PalmMatcherEnrollResponse> captureEnroll({
    required String userId,
    required String voucher,
  }) async {
    await waitUntilReady();
    final payload = await _request(
      method: 'POST',
      uri: _uri('/palm/capture-enroll'),
      body: <String, dynamic>{
        'user_id': userId,
        'voucher': voucher,
      },
    );
    final resultPalmId = (payload['palm_id'] ?? '').toString().trim();
    if (payload['success'] != true || resultPalmId.isEmpty) {
      throw PalmMatcherException(
        code: 'MATCHER_ENROLL_FAILED',
        message: (payload['message'] ?? 'Local palm enrollment failed.')
            .toString(),
      );
    }
    return PalmMatcherEnrollResponse(
      success: true,
      matchedExisting: payload['matched_existing'] == true,
      userId: payload['user_id']?.toString(),
      palmId: resultPalmId,
      voucher: payload['voucher']?.toString(),
      similarRgb: payload['similar_rgb'] is num
          ? (payload['similar_rgb'] as num).toDouble()
          : double.tryParse(payload['similar_rgb']?.toString() ?? ''),
      similarNir: payload['similar_nir'] is num
          ? (payload['similar_nir'] as num).toDouble()
          : double.tryParse(payload['similar_nir']?.toString() ?? ''),
      palmType: payload['palm_type'] is num
          ? (payload['palm_type'] as num).toInt()
          : int.tryParse(payload['palm_type']?.toString() ?? ''),
      score: payload['score'] is num
          ? (payload['score'] as num).toDouble()
          : double.tryParse(payload['score']?.toString() ?? ''),
      mode: payload['mode']?.toString(),
    );
  }

  Future<PalmMatcherRecognizeResponse> captureRecognize() async {
    await waitUntilReady();
    final payload = await _request(
      method: 'POST',
      uri: _uri('/palm/capture-recognize'),
      body: const <String, dynamic>{},
    );
    return PalmMatcherRecognizeResponse(
      success: payload['success'] == true,
      matched: payload['matched'] == true,
      userId: payload['user_id']?.toString(),
      palmId: payload['palm_id']?.toString(),
      voucher: payload['voucher']?.toString(),
      similarRgb: payload['similar_rgb'] is num
          ? (payload['similar_rgb'] as num).toDouble()
          : double.tryParse(payload['similar_rgb']?.toString() ?? ''),
      similarNir: payload['similar_nir'] is num
          ? (payload['similar_nir'] as num).toDouble()
          : double.tryParse(payload['similar_nir']?.toString() ?? ''),
      mode: payload['mode']?.toString(),
      message: payload['message']?.toString(),
    );
  }
}
