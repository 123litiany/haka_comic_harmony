// HarmonyOS port, 2026-10-16. Tests the v11/native channel boundary.
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
// The native-only OHOS package intentionally uses file_picker 11's channel.
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_method_channel.dart';
// ignore: implementation_imports
import 'package:file_picker/src/platform/file_picker_platform_interface.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('miguelruivo.flutter.plugins.filepicker');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  late FilePickerPlatform previous;

  setUp(() {
    previous = FilePickerPlatform.instance;
    FilePickerPlatform.instance = MethodChannelFilePicker();
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    FilePickerPlatform.instance = previous;
  });

  test(
    'document save sends the current name and bytes without a prior pick',
    () async {
      final bytes = Uint8List.fromList([0x50, 0x4b, 3, 4]);
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'save');
        expect(call.arguments['fileName'], '漫画.zip');
        expect(call.arguments['bytes'], bytes);
        expect(call.arguments['allowedExtensions'], ['zip']);
        return 'file://docs/storage/Users/currentUser/Documents/comic.zip';
      });
      expect(
        await FilePicker.saveFile(
          fileName: '漫画.zip',
          type: FileType.custom,
          allowedExtensions: ['zip'],
          bytes: bytes,
        ),
        startsWith('file://docs/'),
      );
    },
  );

  test(
    'canceling the save returns null; native failure remains an error',
    () async {
      messenger.setMockMethodCallHandler(channel, (_) async => null);
      expect(
        await FilePicker.saveFile(fileName: 'comic.zip', bytes: Uint8List(0)),
        isNull,
      );
      messenger.setMockMethodCallHandler(channel, (_) async {
        throw PlatformException(code: 'save_failed', message: 'No space');
      });
      await expectLater(
        FilePicker.saveFile(fileName: 'comic.zip', bytes: Uint8List(0)),
        throwsA(isA<PlatformException>()),
      );
    },
  );

  test(
    'image selection consumes the native sandbox copy and metadata',
    () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'image');
        return [
          {
            'path': '/data/storage/el2/base/cache/file_picker/avatar.png',
            'name': 'avatar.png',
            'size': 42,
            'bytes': null,
            'identifier': 'file://media/Photo/1',
          },
        ];
      });
      final result = await FilePicker.pickFiles(type: FileType.image);
      expect(result!.files.single.path, startsWith('/data/storage/'));
      expect(result.files.single.size, 42);
    },
  );
}
