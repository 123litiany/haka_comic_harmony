import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:haka_comic/config/app_config.dart';

const apiKey = 'C69BAF41DA5ABD1FFEDC6D2FEA56B';
const secretKey =
    "~d}\$Q7\$eIni=V)9\\RK/P.RM4;9[7|@/CA}b~OW!3?EV`:<>M7pddUBL5n|0/*Cn";

// Generate a fresh request identifier and sign that exact value. Never reuse a
// global constant across requests or installations.
String generateNonce() {
  final random = Random.secure();
  return List.generate(
    16,
    (_) => random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

/// 图片质量
enum ImageQuality {
  low('低'),
  medium('中'),
  high('高'),
  original('原画');

  final String displayName;

  const ImageQuality(this.displayName);

  static ImageQuality fromName(String? name) {
    return ImageQuality.values.firstWhere(
      (quality) => quality.name == name,
      orElse: () => original,
    );
  }
}

enum Api {
  picacomic('https://picaapi.picacomic.com/'),
  go2778('https://picaapi.go2778.com/');

  final String host;

  const Api(this.host);

  static Api fromName(String? name) {
    return Api.values.firstWhere(
      (api) => api.name == name,
      orElse: () => go2778,
    );
  }
}

Map<String, String> defaultHeaders = {
  "accept": "application/vnd.picacomic.com.v1+json",
  "User-Agent": "okhttp/3.8.1",
  "Content-Type": "application/json; charset=UTF-8",
  "api-key": apiKey,
  "app-build-version": "45",
  "app-platform": "android",
  "app-uuid": "defaultUuid",
  "app-version": "2.2.1.3.3.4",
  "app-channel": '1',
};

enum Method {
  get('GET'),
  post('POST'),
  delete('DELETE'),
  put('PUT');

  final String value;

  const Method(this.value);
}

String getSignature(String url, String timestamp, String nonce, Method method) {
  final key = (url + timestamp + nonce + method.value + apiKey).toLowerCase();
  var hmac = Hmac(sha256, utf8.encode(secretKey));
  var digest = hmac.convert(utf8.encode(key));
  return digest.toString();
}

String getTimestamp() {
  return (DateTime.now().millisecondsSinceEpoch ~/ 1000).toString();
}

Map<String, String> getHeaders(String url, Method method) {
  final timestamp = getTimestamp();
  final nonce = generateNonce();
  final signature = getSignature(url, timestamp, nonce, method);
  final conf = AppConf();
  return {
    ...defaultHeaders,
    "nonce": nonce,
    "time": timestamp,
    "signature": signature,
    "authorization": conf.token,
    "image-quality": conf.imageQuality.name,
  };
}
