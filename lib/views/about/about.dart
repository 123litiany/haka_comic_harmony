import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:haka_comic/config/app_config.dart';
import 'package:haka_comic/config/setup_config.dart';
import 'package:haka_comic/network/http.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/utils/log.dart';
import 'package:haka_comic/utils/request/request.dart';
import 'package:haka_comic/widgets/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class About extends StatefulWidget {
  const About({super.key});

  @override
  State<About> createState() => _AboutState();
}

class _AboutState extends State<About> with RequestMixin {
  String version = '';
  bool _checkUpdate = AppConf().checkUpdate;

  late final _handler = checkIsUpdated.useRequest(
    manual: true,
    onSuccess: (shouldCheckUpdate) {
      if (shouldCheckUpdate) {
        showUpdateDialog();
      } else {
        Toast.show(message: '当前已是最新版本');
      }
    },
    onError: (error) {
      Log.e('fetch release error', error: error);
      Toast.show(message: '获取版本信息失败');
    },
  );

  @override
  List<RequestHandler> registerHandler() => [_handler];

  Future<void> _launchURL(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri)) {
      Toast.show(message: '无法打开链接');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('关于')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: BoxConstraints.tight(const Size(120, 120)),
            child: Center(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(25),
                child: Image.asset(
                  'assets/images/foreground.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Version ${SetupConf.appVersion}',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 15),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40.0),
            child: Text(
              isOhos
                  ? 'HaKa 是一个开源免费的第三方哔咔漫画客户端'
                  : 'HaKa Comic是一个开源免费的第三方哔咔漫画客户端',
              textAlign: TextAlign.center,
              style: context.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(height: 20),
          SwitchListTile(
            title: const Text('启动时检查更新'),
            subtitle: isOhos ? const Text('鸿蒙测试版暂未开放在线更新') : null,
            value: !isOhos && _checkUpdate,
            onChanged: isOhos ? null : (value) {
              setState(() {
                _checkUpdate = value;
                AppConf().checkUpdate = value;
              });
            },
          ),
          ListTile(
            title: const Text('检查更新'),
            trailing: _handler.state.loading
                ? CircularProgressIndicator(
                    constraints: BoxConstraints.tight(const Size(16, 16)),
                    strokeWidth: 2,
                  )
                : const Icon(Icons.arrow_forward_ios),
            onTap: () {
              if (isOhos) {
                _launchURL('https://github.com/123litiany/haka_comic_harmony/releases');
              } else {
                _handler.run();
              }
            },
          ),
          if (isOhos)
            ListTile(
              title: const Text('鸿蒙版源码与安装说明'),
              trailing: const Icon(Icons.launch),
              onTap: () => _launchURL('https://github.com/123litiany/haka_comic_harmony'),
            ),
          ListTile(
            title: Text(isOhos ? '上游开源项目' : 'Github'),
            trailing: const Icon(Icons.launch),
            onTap: () => _launchURL('https://github.com/raoxwup/haka_comic'),
          ),
        ],
      ),
    );
  }
}

void showUpdateDialog() {
  showDialog(
    context: navigatorKey.currentContext!,
    builder: (context) => AlertDialog(
      title: const Text('更新'),
      content: const Text('有新版本可用，是否前往下载?'),
      actions: [
        TextButton(child: const Text('取消'), onPressed: () => context.pop()),
        TextButton(
          child: const Text('前往'),
          onPressed: () => launchUrl(
            Uri.parse('https://github.com/raoxwup/haka_comic/releases'),
          ),
        ),
      ],
    ),
  );
}
