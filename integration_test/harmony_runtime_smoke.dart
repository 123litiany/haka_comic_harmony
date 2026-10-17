// HarmonyOS port, 2026-10-16. Offline native-runtime checks, not a release entrypoint.
import 'dart:io';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:haka_comic/rust/api/compress.dart';
import 'package:haka_comic/rust/api/simple.dart';
import 'package:haka_comic/views/download/local_comic_files.dart';
import 'package:haka_comic/startup_prepare.dart';
import 'package:haka_comic/utils/ohos_file_saver.dart';
import 'package:haka_comic/utils/ohos_folder_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqlite_async/sqlite_async.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final results = <String>[];
  Directory? work;
  SqliteDatabase? database;
  try {
    await StartupPrepare.prepare();
    results.add('Application startup: PASS');
    work = await (await getTemporaryDirectory()).createTemp('haka-ohos-smoke-');
    final prefs = await SharedPreferences.getInstance();
    final key =
        'harmony_runtime_smoke_${DateTime.now().microsecondsSinceEpoch}';
    try {
      await prefs.setString(key, '鸿蒙读写验证');
      await prefs.reload();
      if (prefs.getString(key) != '鸿蒙读写验证') {
        throw StateError('Preferences round-trip failed');
      }
    } finally {
      await prefs.remove(key);
    }
    results.add('Preferences write/reload: PASS');

    final dbPath = p.join(work.path, 'check.sqlite');
    database = SqliteDatabase(path: dbPath);
    await database.execute('CREATE TABLE check_data (value TEXT NOT NULL)');
    await database.execute('INSERT INTO check_data VALUES (?)', ['本地数据库']);
    await database.close();
    database = SqliteDatabase(path: dbPath);
    final rows = await database.getAll('SELECT value FROM check_data');
    if (rows.single['value'] != '本地数据库') {
      throw StateError('SQLite persistence check failed');
    }
    await database.close();
    database = null;
    results.add('SQLite async write/reopen/read: PASS');

    final source = await Directory(p.join(work.path, 'source')).create();
    await File(
      p.join(source.path, 'sample.txt'),
    ).writeAsString('HaKa 鸿蒙 ZIP 验证');
    final archive = p.join(work.path, 'check.zip');
    await compress(
      sourceFolderPath: source.path,
      outputZipPath: archive,
      compressionMethod: CompressionMethod.stored,
    );
    final extracted = await Directory(p.join(work.path, 'extracted')).create();
    await decompress(sourceZipPath: archive, outputFolderPath: extracted.path);
    final files = await extracted
        .list(recursive: true)
        .where((item) => item is File)
        .toList();
    if (files.length != 1 ||
        await (files.single as File).readAsString() != 'HaKa 鸿蒙 ZIP 验证') {
      throw StateError('Rust ZIP round-trip failed');
    }
    results.add('Rust ZIP compress/decompress: PASS');
    final pages = await Directory(p.join(work.path, 'pages')).create();
    for (final number in [10, 2, 1]) {
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawRect(
        const ui.Rect.fromLTWH(0, 0, 120, 180),
        ui.Paint()..color = ui.Color.fromARGB(255, number * 20, 80, 140),
      );
      final picture = recorder.endRecording();
      final sample = await picture.toImage(120, 180);
      try {
        final bytes = await sample.toByteData(format: ui.ImageByteFormat.png);
        if (bytes == null) throw StateError('Test image encoding failed');
        await File(p.join(pages.path, 'page$number.png'))
            .writeAsBytes(bytes.buffer.asUint8List());
      } finally {
        sample.dispose();
        picture.dispose();
      }
    }
    final sorted = await listImageFiles(pages);
    if (sorted.map((file) => p.basename(file.path)).join(',') !=
        'page1.png,page2.png,page10.png') {
      throw StateError('Local page ordering failed');
    }
    final codec = await ui.instantiateImageCodec(await sorted.first.readAsBytes());
    try {
      final frame = await codec.getNextFrame();
      try {
        if (frame.image.width != 120 || frame.image.height != 180) {
          throw StateError('Image decoding dimensions differ');
        }
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
    }
    results.add('Local page ordering / image decoding: PASS');
    final pdf = File(p.join(work.path, 'sample.pdf'));
    await exportPdf(sourceFolderPath: pages.path, outputPdfPath: pdf.path);
    final pdfText = latin1.decode(await pdf.readAsBytes());
    if (!pdfText.startsWith('%PDF-') || !pdfText.contains('%%EOF') ||
        !RegExp(r'/Count\s+3\b').hasMatch(pdfText)) {
      throw StateError('PDF header, trailer or page count is invalid');
    }
    results.add('Rust PDF export (3 generated pages): PASS');
    debugPrint('HAKA_OHOS_SMOKE PASS');
  } catch (error, stack) {
    results.add('FAIL: $error');
    debugPrint('HAKA_OHOS_SMOKE FAIL: $error\n$stack');
  } finally {
    await database?.close();
    if (work != null) await work.delete(recursive: true);
  }
  runApp(
    MaterialApp(
      home: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(results.join('\n\n')),
                const SizedBox(height: 24),
                const _SaveProbe(),
                const _FolderProbe(),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _FolderProbe extends StatefulWidget {
  const _FolderProbe();
  @override
  State<_FolderProbe> createState() => _FolderProbeState();
}

class _FolderProbeState extends State<_FolderProbe> {
  bool busy = false;
  String status = 'Folder snapshot: not tested';

  Future<void> pick() async {
    setState(() => busy = true);
    String? temporary;
    try {
      if (!await OhosFolderPicker.isSupported()) {
        status = 'Folder authorization: unavailable on this device; ZIP import required';
        return;
      }
      final snapshot = await OhosFolderPicker.pickSnapshot();
      if (snapshot == null) {
        status = 'Folder snapshot: CANCELED';
      } else {
        temporary = snapshot.localPath;
        var matches = 0;
        for (final item in snapshot.files) {
          if (item.size < 4096 && item.name.contains('haka-save')) {
            final content = await File(item.localPath).readAsString();
            if (content == 'HaKa HarmonyOS native file-copy test\n鸿蒙文件保存验证\n') matches++;
          }
        }
        if (matches == 0) throw StateError('Select the folder containing the saved test text');
        status = 'Folder snapshot / saved content comparison: PASS';
      }
    } catch (error) {
      status = 'Folder snapshot: FAIL $error';
    } finally {
      if (temporary != null) await Directory(temporary).delete(recursive: true);
      debugPrint('HAKA_OHOS_FOLDER $status');
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    ElevatedButton(onPressed: busy ? null : pick, child: const Text('验证测试文件夹')),
    SelectableText(status),
  ]);
}

class _SaveProbe extends StatefulWidget {
  const _SaveProbe();
  @override
  State<_SaveProbe> createState() => _SaveProbeState();
}

class _SaveProbeState extends State<_SaveProbe> {
  bool busy = false;
  String status = 'System document save: not tested';

  Future<void> saveComic() async {
    setState(() => busy = true);
    Directory? work;
    try {
      work = await (await getTemporaryDirectory()).createTemp('haka-comic-probe-');
      final pages = await Directory(p.join(work.path, 'pages')).create();
      for (var page = 1; page <= 3; page++) {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 600, 900),
            ui.Paint()..color = ui.Color.fromARGB(255, page * 70, 70, 180));
        final builder = ui.ParagraphBuilder(ui.ParagraphStyle(fontSize: 64))
          ..addText('HaKa OHOS\nTest page $page / 3');
        final paragraph = builder.build()..layout(const ui.ParagraphConstraints(width: 550));
        canvas.drawParagraph(paragraph, const ui.Offset(25, 100));
        final picture = recorder.endRecording();
        final image = await picture.toImage(600, 900);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        await File(p.join(pages.path, '$page.png')).writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
        picture.dispose();
        paragraph.dispose();
      }
      final archive = p.join(work.path, 'HaKa-Test-Comic.zip');
      await compress(sourceFolderPath: pages.path, outputZipPath: archive,
          compressionMethod: CompressionMethod.stored);
      final uri = await OhosFileSaver.save(sourcePath: archive, fileName: 'HaKa-Test-Comic.zip');
      status = uri == null ? 'Test comic save: CANCELED' : 'Test comic save: PASS';
    } catch (error) {
      status = 'Test comic save: FAIL $error';
    } finally {
      if (work != null) await work.delete(recursive: true);
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> save() async {
    setState(() => busy = true);
    Directory? temporary;
    try {
      temporary = await (await getTemporaryDirectory()).createTemp(
        'haka-save-probe-',
      );
      final file = File(p.join(temporary.path, 'haka-save-test.txt'));
      await file.writeAsString(
        'HaKa HarmonyOS native file-copy test\n鸿蒙文件保存验证\n',
      );
      final uri = await OhosFileSaver.save(
        sourcePath: file.path,
        fileName: 'haka-save-test.txt',
      );
      status = uri == null
          ? 'System document save: CANCELED'
          : 'System document save: PASS\n$uri';
      debugPrint('HAKA_OHOS_SAVE $status');
    } catch (error) {
      status = 'System document save: FAIL $error';
      debugPrint('HAKA_OHOS_SAVE $status');
    } finally {
      if (temporary != null) await temporary.delete(recursive: true);
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      ElevatedButton(
        onPressed: busy ? null : save,
        child: const Text('保存测试文件'),
      ),
      ElevatedButton(onPressed: busy ? null : saveComic, child: const Text('保存测试漫画ZIP')),
      SelectableText(status),
    ],
  );
}
