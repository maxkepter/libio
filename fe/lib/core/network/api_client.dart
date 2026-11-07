import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import 'api_exception.dart';

class ApiSseEvent {
  final String data;
  final String? event;
  final String? id;

  const ApiSseEvent({required this.data, this.event, this.id});
}

class ApiClient {
  final http.Client _client;
  final String baseUrl;
  Future<String?> Function()? getAccessToken;

  ApiClient({http.Client? client, String? baseUrl, this.getAccessToken})
    : _client = client ?? http.Client(),
      baseUrl = baseUrl ?? ApiConstants.baseUrl;

  Map<String, String> _defaultHeaders([String? token]) => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
    if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
  };

  Uri _uri(String path, [Map<String, dynamic>? query]) {
    final cleanBase = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;
    final cleanPath = path.startsWith('/') ? path : '/$path';
    final uri = Uri.parse('$cleanBase$cleanPath');
    return (query == null || query.isEmpty)
        ? uri
        : uri.replace(
            queryParameters: {
              ...uri.queryParameters,
              ...query.map((k, v) => MapEntry(k, v?.toString() ?? '')),
            },
          );
  }

  Future<dynamic> post(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    String? token;
    if (requiresAuth && getAccessToken != null) {
      token = await getAccessToken!();
    }

    try {
      print('Base URL: $baseUrl');
      final response = await _client
          .post(
            _uri(path),
            headers: _defaultHeaders(token),
            body: body != null ? jsonEncode(body) : null,
          )
          .timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Không thể kết nối đến máy chủ. Kiểm tra mạng.');
    } on TimeoutException {
      throw const ApiException('Hết thời gian kết nối đến máy chủ.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi không xác định: $e');
    }
  }

  Stream<ApiSseEvent> getSse(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = false,
  }) async* {
    final token = requiresAuth && getAccessToken != null ? await getAccessToken!() : null;
    final request = http.Request('GET', _uri(path, query))
      ..headers.addAll({
        'Accept': 'text/event-stream',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
      });

    final response = await _client.send(request);
    if (response.statusCode >= 400) {
      throw ApiException.fromStatus(response.statusCode, null);
    }

    String? event, id;
    final buffer = StringBuffer();

    yield* response.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .expand((line) {
          if (line.isEmpty) {
            if (buffer.isEmpty) return const <ApiSseEvent>[];
            final e = ApiSseEvent(data: buffer.toString(), event: event, id: id);
            buffer.clear();
            event = id = null;
            return [e];
          }
          if (line.startsWith('data:')) {
            if (buffer.isNotEmpty) buffer.write('\n');
            buffer.write(line.substring(5).trimLeft());
          } else if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('id:')) {
            id = line.substring(3).trim();
          }
          return const <ApiSseEvent>[];
        });
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? query,
    bool requiresAuth = false,
  }) async {
    String? token;
    if (requiresAuth && getAccessToken != null) {
      token = await getAccessToken!();
    }

    try {
      final response = await _client
          .get(_uri(path, query), headers: _defaultHeaders(token))
          .timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Không thể kết nối đến máy chủ. Kiểm tra mạng.');
    } on TimeoutException {
      throw const ApiException('Hết thời gian kết nối đến máy chủ.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi: $e');
    }
  }

  Future<dynamic> _sendWithBody(
    String method,
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) async {
    String? token;
    if (requiresAuth && getAccessToken != null) {
      token = await getAccessToken!();
    }

    Future<http.Response> call() {
      final uri = _uri(path);
      final headers = _defaultHeaders(token);
      final encoded = body != null ? jsonEncode(body) : null;
      switch (method) {
        case 'PATCH':
          return _client.patch(uri, headers: headers, body: encoded);
        case 'PUT':
          return _client.put(uri, headers: headers, body: encoded);
        case 'DELETE':
          return _client.delete(uri, headers: headers, body: encoded);
        default:
          return _client.post(uri, headers: headers, body: encoded);
      }
    }

    try {
      final response = await call().timeout(ApiConstants.timeout);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Không thể kết nối đến máy chủ. Kiểm tra mạng.');
    } on TimeoutException {
      throw const ApiException('Hết thời gian kết nối đến máy chủ.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi không xác định: $e');
    }
  }

  Future<dynamic> put(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) => _sendWithBody('PUT', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> patch(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) => _sendWithBody('PATCH', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> delete(
    String path, {
    Map<String, dynamic>? body,
    bool requiresAuth = false,
  }) => _sendWithBody('DELETE', path, body: body, requiresAuth: requiresAuth);

  Future<dynamic> postMultipart(
    String path, {
    Map<String, String>? fields,
    required List<http.MultipartFile> files,
    bool requiresAuth = false,
  }) async {
    String? token;
    if (requiresAuth && getAccessToken != null) {
      token = await getAccessToken!();
    }

    try {
      final request = http.MultipartRequest('POST', _uri(path));
      if (token != null && token.isNotEmpty) {
        request.headers['Authorization'] = 'Bearer $token';
      }
      request.headers['Accept'] = 'application/json';
      if (fields != null) request.fields.addAll(fields);
      request.files.addAll(files);

      final streamedResponse = await _client
          .send(request)
          .timeout(ApiConstants.timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(response);
    } on SocketException {
      throw const ApiException('Không thể kết nối đến máy chủ. Kiểm tra mạng.');
    } on TimeoutException {
      throw const ApiException('Hết thời gian kết nối đến máy chủ.');
    } on ApiException {
      rethrow;
    } catch (e) {
      throw ApiException('Đã xảy ra lỗi không xác định: $e');
    }
  }

  dynamic _handleResponse(http.Response response) {
    dynamic decoded;
    try {
      if (response.body.isNotEmpty) {
        decoded = jsonDecode(response.body);
      }
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    String? serverMsg;
    if (decoded is Map<String, dynamic>) {
      final m = decoded['message'];
      if (m is String) {
        serverMsg = m;
      } else if (m is List && m.isNotEmpty) {
        serverMsg = m.first.toString();
      }
    }
    throw ApiException.fromStatus(response.statusCode, serverMsg, raw: decoded);
  }

  void close() => _client.close();
}
