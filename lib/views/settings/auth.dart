import 'package:flutter/material.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/device_authentication.dart';
import 'package:haka_comic/widgets/toast.dart';

class Auth extends StatefulWidget {
  const Auth({super.key});

  @override
  State<Auth> createState() => _AuthState();
}

class _AuthState extends State<Auth> {
  bool _needAuth = AppConf().needAuth;
  bool _verifying = false;

  Future<void> _change(bool value) async {
    if (_verifying) return;
    if (value) {
      setState(() => _verifying = true);
      final verified = await authenticateDeviceAccess();
      if (!mounted) return;
      setState(() => _verifying = false);
      if (!verified) {
        Toast.show(message: '身份验证未完成，未开启应用锁');
        return;
      }
    }
    setState(() => _needAuth = value);
    AppConf().needAuth = value;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: const Text('身份验证'),
      leading: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: context.colorScheme.primary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: const Icon(Icons.security_outlined, size: 22, weight: 700),
      ),
      subtitle: const Text('开启后需要验证才能访问应用'),
      trailing: Switch(
        value: _needAuth,
        onChanged: _verifying ? null : _change,
      ),
    );
  }
}
