import 'package:haka_comic/network/api_exception.dart';

String registrationErrorMessage(Object error) {
  final message = error is ApiException ? error.message : error.toString();
  switch (message.trim().toLowerCase()) {
    case 'email is already exist':
      return '服务器提示登录账号已存在，请修改「登录账号」或使用已有账号登录。若随机账号仍被拒绝，请稍后再试。';
    case 'name is already exist':
      return '昵称已存在，请修改上方的「昵称」，可点骰子生成。若随机昵称仍被拒绝，请稍后再试。';
    case 'validation error':
      final detail = error is ApiException ? error.detail : null;
      return detail == null ? '注册信息校验失败，请检查填写内容。' : '注册信息校验失败：$detail';
    case 'failure':
      return '服务器未能完成注册，请稍后再试。';
    default:
      return error.toString().replaceFirst(RegExp(r'^Exception: '), '');
  }
}
