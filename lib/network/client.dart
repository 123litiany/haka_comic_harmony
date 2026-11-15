import 'dart:io';
import 'package:dio/dio.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/network/api_exception.dart';
import 'package:haka_comic/network/utils.dart';
import 'package:haka_comic/router/app_router.dart';

class Client {
  static const _maxRetries = 3;

  static CancelToken _cancelToken = CancelToken();

  static void setBaseUrl(String url) => _client.options.baseUrl = url;

  static final Dio _client =
      Dio(
          BaseOptions(
            baseUrl: AppConf().api.host,
            responseType: ResponseType.json,
            connectTimeout: const Duration(seconds: 10),
            validateStatus: (status) {
              return status == 200 || status == 400 || status == 401;
            },
          ),
        )
        ..interceptors.add(
          InterceptorsWrapper(
            onError: (DioException err, ErrorInterceptorHandler handler) async {
              bool shouldRetry = false;
              if (err.response != null) {
                final sc = err.response!.statusCode;
                if (sc != null && sc >= 500 && sc < 600) shouldRetry = true;
              } else {
                final t = err.type;
                shouldRetry =
                    t == DioExceptionType.connectionTimeout ||
                    t == DioExceptionType.sendTimeout ||
                    t == DioExceptionType.receiveTimeout ||
                    t == DioExceptionType.connectionError ||
                    err.error is HandshakeException;
              }

              final extra = err.requestOptions.extra;
              if (extra['retryOnFailure'] == false) {
                return handler.reject(err);
              }
              int retryCount = extra['retryCount'] ?? 0;
              if (shouldRetry && retryCount < _maxRetries - 1) {
                await Future.delayed(const Duration(seconds: 1));
                final reqOpt = err.requestOptions;
                reqOpt.extra['retryCount'] = retryCount + 1;
                final signedPath = reqOpt.extra['signedPath'] as String;
                final method = Method.values.firstWhere(
                  (value) => value.value == reqOpt.method,
                );
                reqOpt.headers.addAll(getHeaders(signedPath, method));
                try {
                  final ret = await _client.fetch(reqOpt);
                  return handler.resolve(ret);
                } catch (_) {
                  return handler.reject(err);
                }
              }
              return handler.reject(err);
            },
          ),
        );

  static Future<Map<String, dynamic>> _request(
    Method method,
    String path, {
    Map<String, dynamic>? payload,
    String? baseUrl,
    bool retryOnFailure = true,
  }) async {
    String queryString = '';
    if (method == Method.get) {
      queryString = Uri(
        queryParameters: (payload ?? {}).map(
          (key, value) => MapEntry(key, value.toString()),
        ),
      ).query;
    }
    final signedPath = method == Method.get && queryString.isNotEmpty
        ? '$path?$queryString'
        : path;
    final options = Options(
      headers: getHeaders(signedPath, method),
      extra: {'signedPath': signedPath, 'retryOnFailure': retryOnFailure},
    );
    final requestPath = baseUrl == null
        ? path
        : Uri.parse(baseUrl).resolve(path).toString();
    try {
      Response response;
      switch (method) {
        case Method.get:
          response = await _client.get(
            requestPath,
            options: options,
            queryParameters: payload,
            cancelToken: _cancelToken,
          );
          break;
        case Method.post:
          response = await _client.post(
            requestPath,
            options: options,
            data: payload,
            cancelToken: _cancelToken,
          );
          break;
        case Method.put:
          response = await _client.put(
            requestPath,
            options: options,
            data: payload,
            cancelToken: _cancelToken,
          );
          break;
        case Method.delete:
          response = await _client.delete(
            requestPath,
            options: options,
            data: payload,
            cancelToken: _cancelToken,
          );
          break;
      }
      if (response.data == null) {
        throw Exception("Empty data");
      }
      switch (response.statusCode) {
        case 200:
          return response.data;
        case 400:
          throw ApiException.fromResponse(response.statusCode, response.data);
        case 401:
          _cancelToken.cancel();
          _cancelToken = CancelToken();
          logout();
          throw '登录失效';
        default:
          throw Exception("Invalid Status Code ${response.statusCode}");
      }
    } on DioException catch (e) {
      String message;
      if (e.type == DioExceptionType.connectionTimeout) {
        message = "连接超时";
      } else if (e.type != DioExceptionType.unknown) {
        message = e.message ?? '未知错误';
      } else {
        message = e.toString();
      }
      throw Exception(message);
    } catch (e) {
      rethrow;
    }
  }

  static Future<Map<String, dynamic>> get(
    String path, {
    Map<String, dynamic>? query,
    String? baseUrl,
  }) {
    return _request(Method.get, path, payload: query, baseUrl: baseUrl);
  }

  static Future<Map<String, dynamic>> post(
    String path, {
    Map<String, dynamic>? data,
    String? baseUrl,
    bool retryOnFailure = true,
  }) {
    return _request(
      Method.post,
      path,
      payload: data,
      baseUrl: baseUrl,
      retryOnFailure: retryOnFailure,
    );
  }

  static Future<Map<String, dynamic>> put(
    String path, {
    Map<String, dynamic>? data,
    String? baseUrl,
  }) {
    return _request(Method.put, path, payload: data, baseUrl: baseUrl);
  }

  static Future<Map<String, dynamic>> delete(
    String path, {
    Map<String, dynamic>? data,
    String? baseUrl,
  }) {
    return _request(Method.delete, path, payload: data, baseUrl: baseUrl);
  }
}
