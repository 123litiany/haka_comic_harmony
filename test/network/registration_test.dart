import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/network/api_exception.dart';
import 'package:haka_comic/network/client.dart';
import 'package:haka_comic/network/http.dart';
import 'package:haka_comic/network/models.dart';
import 'package:haka_comic/network/utils.dart';
import 'package:haka_comic/utils/registration_error.dart';
import 'package:haka_comic/utils/shared_preferences_util.dart';
import 'package:shared_preferences/shared_preferences.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

final payload = RegisterPayload(
  birthday: '2000-01-01',
  email: 'localTestAccount',
  gender: 'm',
  name: 'localTestNickname',
  password: 'localTestPassword',
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late HttpOverrides? previousOverrides;

  setUp(() async {
    previousOverrides = HttpOverrides.current;
    // These tests only contact a loopback fake API, never the live service.
    HttpOverrides.global = null;
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.withData({});
    SharedPreferencesUtil.prefsWithCache =
        await SharedPreferencesWithCache.create(
          cacheOptions: const SharedPreferencesWithCacheOptions(),
        );
    await AppConf.initialize();
  });

  tearDown(() {
    Client.setBaseUrl(AppConf().api.host);
    HttpOverrides.global = previousOverrides;
  });

  test('each signed request has a fresh nonce matching its signature', () {
    final nonces = <String>{};
    for (var index = 0; index < 100; index++) {
      final headers = getHeaders('auth/register', Method.post);
      expect(headers['nonce'], matches(RegExp(r'^[a-f0-9]{32}$')));
      expect(nonces.add(headers['nonce']!), isTrue);
      expect(
        headers['signature'],
        getSignature(
          'auth/register',
          headers['time']!,
          headers['nonce']!,
          Method.post,
        ),
      );
    }
  });

  test(
    'registration sends the account and nickname as separate fields',
    () async {
      final server = await _serve((request) async {
        final body = jsonDecode(await utf8.decoder.bind(request).join());
        expect(body['email'], 'localTestAccount');
        expect(body['name'], 'localTestNickname');
        expect(body['password'], 'localTestPassword');
        _expectSignature(request, Method.post);
        await _respond(request, 200, {'code': 200, 'message': 'success'});
      });
      Client.setBaseUrl(server);
      await register(payload);
    },
  );

  test(
    'registration never retries after an uncertain server failure',
    () async {
      var attempts = 0;
      Client.setBaseUrl(
        await _serve((request) async {
          attempts++;
          await request.drain<void>();
          await _respond(request, 503, {'code': 503, 'message': 'unavailable'});
        }),
      );
      await expectLater(register(payload), throwsException);
      expect(attempts, 1);
    },
  );

  test(
    'a business failure inside HTTP 200 is not registration success',
    () async {
      Client.setBaseUrl(
        await _serve((request) async {
          await request.drain<void>();
          await _respond(request, 200, {
            'code': 400,
            'error': '1008',
            'message': 'email is already exist',
          });
        }),
      );
      await expectLater(
        register(payload),
        throwsA(
          isA<ApiException>().having((e) => e.code, 'error code', '1008'),
        ),
      );
    },
  );

  test('validation details survive HTTP error handling', () async {
    Client.setBaseUrl(
      await _serve((request) async {
        await request.drain<void>();
        await _respond(request, 400, {
          'code': 400,
          'error': '1002',
          'message': 'validation error',
          'detail': 'email is required',
        });
      }),
    );
    await expectLater(
      register(payload),
      throwsA(
        isA<ApiException>().having(
          registrationErrorMessage,
          'validation message',
          contains('email is required'),
        ),
      ),
    );
  });

  test('account and nickname conflicts identify the correct field', () {
    expect(
      registrationErrorMessage(
        const ApiException(message: 'email is already exist'),
      ),
      contains('登录账号已存在'),
    );
    expect(
      registrationErrorMessage(
        const ApiException(message: 'name is already exist'),
      ),
      startsWith('昵称已存在'),
    );
    expect(
      registrationErrorMessage(const ApiException(message: 'failure')),
      contains('未能完成注册'),
    );
  });

  test(
    'ordinary GET retries renew the nonce and keep the signed query',
    () async {
      final nonces = <String>{};
      var attempts = 0;
      Client.setBaseUrl(
        await _serve((request) async {
          attempts++;
          expect(request.uri.toString(), '/categories?page=2');
          _expectSignature(request, Method.get);
          expect(nonces.add(request.headers.value('nonce')!), isTrue);
          await _respond(request, attempts < 3 ? 503 : 200, {
            'code': attempts < 3 ? 503 : 200,
            'message': attempts < 3 ? 'unavailable' : 'success',
          });
        }),
      );
      await Client.get('categories', query: {'page': 2});
      expect(attempts, 3);
    },
  );

  test('download requests also use a fresh correctly signed nonce', () async {
    final nonces = <String>{};
    final server = await _serve((request) async {
      _expectSignature(request, Method.get);
      expect(nonces.add(request.headers.value('nonce')!), isTrue);
      await _respond(request, 200, {'code': 200, 'message': 'success'});
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      await DownloadIsolateClient.get(
        'comics/test/order/1/pages',
        '',
        server,
        queryParameters: {'page': 1},
      );
    }
    expect(nonces, hasLength(2));
  });

  test('a one-off host override keeps the selected API unchanged', () async {
    var selectedRequests = 0;
    var overrideRequests = 0;
    final selected = await _serve((request) async {
      selectedRequests++;
      _expectSignature(request, Method.get);
      await _respond(request, 200, {'code': 200, 'message': 'success'});
    });
    final override = await _serve((request) async {
      overrideRequests++;
      _expectSignature(request, Method.get);
      await _respond(request, 200, {'code': 200, 'message': 'success'});
    });
    Client.setBaseUrl(selected);
    await Client.get('categories', baseUrl: override);
    await Client.get('categories');
    expect(overrideRequests, 1);
    expect(selectedRequests, 1);
  });
}

Future<String> _serve(Future<void> Function(HttpRequest) handler) async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  server.listen((request) async {
    try {
      await handler(request);
    } catch (_) {
      request.response.statusCode = 500;
      await request.response.close();
      rethrow;
    }
  });
  addTearDown(() => server.close(force: true));
  return 'http://127.0.0.1:${server.port}/';
}

Future<void> _respond(
  HttpRequest request,
  int status,
  Map<String, Object> body,
) {
  request.response.statusCode = status;
  request.response.headers.contentType = ContentType.json;
  request.response.write(jsonEncode(body));
  return request.response.close();
}

void _expectSignature(HttpRequest request, Method method) {
  final nonce = request.headers.value('nonce')!;
  expect(nonce, matches(RegExp(r'^[a-f0-9]{32}$')));
  expect(
    request.headers.value('signature'),
    getSignature(
      request.uri.toString().substring(1),
      request.headers.value('time')!,
      nonce,
      method,
    ),
  );
}
