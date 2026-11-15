import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/network/http.dart';
import 'package:haka_comic/network/models.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/log.dart';
import 'package:haka_comic/utils/request/request.dart';
import 'package:haka_comic/utils/registration_error.dart';
import 'package:haka_comic/widgets/button.dart';
import 'package:haka_comic/widgets/toast.dart';

class Register extends StatefulWidget {
  final Future<void> Function(RegisterPayload) registerRequest;

  const Register({super.key, this.registerRequest = register});

  @override
  State<Register> createState() => _RegisterState();
}

class _RegisterState extends State<Register> with RequestMixin {
  final _nicknameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  String _genderValue = 'm';
  final targetYear = DateTime.now().year - 18;

  late final _handler = widget.registerRequest.useRequest(
    manual: true,
    onSuccess: (data, params) {
      if (!mounted) return;
      Log.i('Register success', '');
      Toast.show(message: '注册成功');
      context.pop(params.email);
    },
    onError: (e, _) {
      if (!mounted) return;
      Log.e('Register error', error: e);
      showSnackBar(registrationErrorMessage(e));
    },
  );

  void submit() {
    if (_handler.state.loading) return;
    final nickname = _nicknameController.text.trim();
    final username = _usernameController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;
    final gender = _genderValue;
    final birthday = DateTime(targetYear, 1, 1);

    if (nickname.isEmpty ||
        username.isEmpty ||
        password.isEmpty ||
        confirmPassword.isEmpty ||
        gender.isEmpty) {
      Toast.show(message: '请填写完整信息');
      return;
    }

    if (nickname.length < 2) {
      Toast.show(message: '昵称长度至少2个字符');
      return;
    }

    if (nickname.length > 50) {
      Toast.show(message: '昵称长度不能超过50个字符');
      return;
    }

    if (!RegExp(r'^[a-zA-Z0-9]+$').hasMatch(username)) {
      Toast.show(message: '用户名只能包含字母和数字');
      return;
    }

    if (password.length < 8) {
      Toast.show(message: '密码长度至少8个字符');
      return;
    }

    if (password != confirmPassword) {
      Toast.show(message: '两次密码不一致');
      return;
    }

    _handler.run(
      RegisterPayload(
        name: nickname,
        password: password,
        email: username,
        gender: gender,
        birthday: '${birthday.year}-01-01',
      ),
    );
  }

  @override
  List<RequestHandler> registerHandler() => [_handler];

  @override
  void dispose() {
    _nicknameController.dispose();
    _usernameController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void onGenderChange(String? value) {
    setState(() {
      _genderValue = value!;
    });
  }

  void _generateName(TextEditingController controller) {
    final random = Random.secure();
    controller.text = List.generate(
      16,
      (_) => String.fromCharCode(97 + random.nextInt(26)),
    ).join();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('注册')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              TextField(
                decoration: InputDecoration(
                  labelText: '昵称',
                  helperText: '展示名称，需要与其他用户不同',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '生成随机昵称',
                    onPressed: _handler.state.loading
                        ? null
                        : () => _generateName(_nicknameController),
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ),
                controller: _nicknameController,
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: InputDecoration(
                  labelText: '登录账号',
                  helperText: '用于登录，只能包含字母和数字',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    tooltip: '生成随机登录账号',
                    onPressed: _handler.state.loading
                        ? null
                        : () => _generateName(_usernameController),
                    icon: const Icon(Icons.casino_outlined),
                  ),
                ),
                controller: _usernameController,
                autocorrect: false,
                enableSuggestions: false,
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  labelText: '密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                controller: _passwordController,
              ),
              const SizedBox(height: 20),
              TextField(
                decoration: const InputDecoration(
                  labelText: '确认密码',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                controller: _confirmPasswordController,
              ),
              const SizedBox(height: 20),
              RadioGroup(
                groupValue: _genderValue,
                onChanged: onGenderChange,
                child: Row(
                  children: [
                    Text('性别：', style: context.textTheme.titleMedium),
                    const SizedBox(width: 8),
                    const Radio(value: 'm'),
                    const Text('男'),
                    const SizedBox(width: 8),
                    const Radio(value: 'f'),
                    const Text('女'),
                    const SizedBox(width: 8),
                    const Radio(value: 'bot'),
                    const Text('机器人'),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Button.filled(
                onPressed: submit,
                isLoading: _handler.state.loading,
                child: const Text('注册'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
