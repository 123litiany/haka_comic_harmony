import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:crypto/crypto.dart';
import 'package:file_picker/file_picker.dart';
import 'package:haka_comic/utils/common.dart';
import 'package:haka_comic/utils/extension.dart';
import 'package:haka_comic/utils/native_folder_picker.dart';
import 'package:haka_comic/rust/api/compress.dart';
import 'package:haka_comic/views/download/background_downloader.dart';
import 'package:haka_comic/views/download/download_storage.dart';
import 'package:haka_comic/views/download/local_comic_files.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LocalComicImportException implements Exception {
  const LocalComicImportException(this.message);

  final String message;

  @override
  String toString() => message;
}

class PickedLocalComicSource {
  const PickedLocalComicSource({
    required this.folderName,
    required this.directoryPath,
    this.cleanupPath,
  });

  final String folderName;
  final String directoryPath;
  final String? cleanupPath;
}

class LocalComicImporter {
  const LocalComicImporter._();

  static const _pendingImportKey = 'pendingDownloadStorageImport';

  static Future<void> recoverPendingImport() async {
    final prefs = SharedPreferencesAsync();
    final encoded = await prefs.getString(_pendingImportKey);
    if (encoded == null || encoded.isEmpty) return;

    late final Object? decoded;
    try {
      decoded = jsonDecode(encoded);
    } catch (_) {
      await prefs.remove(_pendingImportKey);
      rethrow;
    }
    if (decoded is! Map) {
      await prefs.remove(_pendingImportKey);
      throw const FormatException('Invalid download import journal');
    }
    final rawStorage = decoded['storage'];
    final relativePath = decoded['relativePath'];
    final rawWorkPaths = decoded['workPaths'];
    if (rawStorage is! Map ||
        relativePath is! String ||
        rawWorkPaths is! List) {
      await prefs.remove(_pendingImportKey);
      throw const FormatException('Invalid download import journal');
    }

    final storage = DownloadStorage.fromDescriptor(
      Map<String, Object?>.from(rawStorage),
    );
    if (!storage.isAndroidSaf) {
      await prefs.remove(_pendingImportKey);
      throw const FormatException('Invalid download import storage');
    }

    var cleaned = true;
    try {
      await storage.deleteDirectory(relativePath);
    } catch (_) {
      cleaned = false;
    }

    final workRoot = p.canonicalize(
      p.join((await getApplicationCacheDirectory()).path, 'import_work'),
    );
    for (final workPath in rawWorkPaths.whereType<String>()) {
      final normalizedWorkPath = p.canonicalize(workPath);
      if (!p.isWithin(workRoot, normalizedWorkPath)) {
        cleaned = false;
        continue;
      }
      cleaned = await _deleteWorkDirectory(normalizedWorkPath) && cleaned;
    }

    if (!cleaned) {
      throw const FileSystemException('无法清理上次导入留下的临时文件');
    }
    await prefs.remove(_pendingImportKey);
  }

  static Future<PickedLocalComicSource?> pickSource() async {
    if (isOhos) {
      // API 26 reports folder capability but the phone picker cannot confirm
      // a directory on the tested image. Use the supported file workflow.
      return pickArchiveSource();
    }
    if (isAndroid || isIOS) {
      final snapshot = await NativeFolderPicker.pickDirectorySnapshot();
      if (snapshot == null) {
        return null;
      }

      return PickedLocalComicSource(
        folderName: snapshot.name,
        directoryPath: snapshot.localPath,
        cleanupPath: snapshot.localPath,
      );
    }

    final path = await FilePicker.getDirectoryPath();
    if (path == null) {
      return null;
    }

    return PickedLocalComicSource(
      folderName: p.basename(path),
      directoryPath: path,
    );
  }

  /// A file picker works on phones which cannot authorize a whole directory.
  /// Expand into a unique app-owned directory, never into an existing download.
  static Future<PickedLocalComicSource?> pickArchiveSource() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'cbz'],
      withData: false,
      dialogTitle: '选择漫画 ZIP / CBZ',
    );
    if (picked == null) return null;
    final file = picked.files.single;
    final path = file.path;
    if (path == null) throw const LocalComicImportException('无法读取所选压缩包');
    final temporary = await (await getTemporaryDirectory()).createTemp('haka-import-');
    try {
      await decompress(sourceZipPath: path, outputFolderPath: temporary.path);
      return PickedLocalComicSource(
        folderName: p.basenameWithoutExtension(file.name),
        directoryPath: temporary.path,
        cleanupPath: temporary.path,
      );
    } catch (_) {
      await temporary.delete(recursive: true);
      rethrow;
    }
  }

  static Future<void> cleanupSource(PickedLocalComicSource source) async {
    final cleanupPath = source.cleanupPath;
    if (cleanupPath == null) {
      return;
    }

    final directory = Directory(cleanupPath);
    if (await directory.exists()) {
      await directory.delete(recursive: true);
    }
  }

  static Future<ComicDownloadTask> importSource(
    PickedLocalComicSource source, {
    required Iterable<String> existingTitles,
  }) async {
    await recoverPendingImport();
    final sourceDir = Directory(source.directoryPath);
    if (!await sourceDir.exists()) {
      throw const LocalComicImportException('所选文件夹不存在');
    }

    final chapterPlans = await _buildChapterPlans(sourceDir);
    if (chapterPlans.isEmpty) {
      throw const LocalComicImportException('没有找到漫画图片');
    }

    final storage = await DownloadStorage.load();
    await storage.ensureReady();

    final title = await _resolveAvailableTitle(
      baseTitle: source.folderName,
      storage: storage,
      existingTitles: existingTitles,
    );

    final idSeed =
        '${source.directoryPath}|${DateTime.now().microsecondsSinceEpoch}';
    final digest = sha1.convert(utf8.encode(idSeed)).toString();
    final taskId = 'import:$digest';
    final legalTitle = title.legalized;
    final workRoot =
        storage.localRootPath ??
        p.join((await getApplicationCacheDirectory()).path, 'import_work');
    final targetDirPath = p.join(
      workRoot,
      storage.isAndroidSaf ? '${legalTitle}_$digest' : legalTitle,
    );
    final tempDirPath = p.join(workRoot, '.import_$digest');

    // 只在主 isolate 里做“规划”（扫描已经完成），封面/总数等元数据也在此确定；
    // 真正的重 I/O（逐张拷贝）放到独立 isolate，避免卡 UI。
    final chapters = <DownloadChapter>[];
    final copyChapters = <_ChapterCopyPlan>[];
    String? coverRelativePath;
    var totalImages = 0;

    for (
      var chapterIndex = 0;
      chapterIndex < chapterPlans.length;
      chapterIndex++
    ) {
      final plan = chapterPlans[chapterIndex];
      final order = chapterIndex + 1;
      final chapterTitle = _normalizeTitle(plan.title, fallback: '第$order章');
      final chapter = DownloadChapter(
        id: '$taskId:$order',
        title: chapterTitle,
        order: order,
      );
      final chapterFolderName = '${chapter.order}_${chapter.title.legalized}';

      final files = <_ImageCopyPlan>[];
      for (var imageIndex = 0; imageIndex < plan.images.length; imageIndex++) {
        final sourceImage = plan.images[imageIndex];
        final ext = p.extension(sourceImage.path).toLowerCase();
        final fileName =
            '${(imageIndex + 1).toString().padLeft(4, '0')}${ext.isEmpty ? '.jpg' : ext}';
        files.add(
          _ImageCopyPlan(sourcePath: sourceImage.path, fileName: fileName),
        );

        // 封面存相对 download 根目录的路径，展示时再拼接，规避沙盒绝对路径失效。
        coverRelativePath ??= p.join(legalTitle, chapterFolderName, fileName);
        totalImages += 1;
      }

      copyChapters.add(
        _ChapterCopyPlan(folderName: chapterFolderName, files: files),
      );
      // 章节图片不入库：本地漫画以文件系统为准，阅读时按目录读取。
      chapters.add(chapter);
    }

    if (storage.isAndroidSaf) {
      await _writePendingImport(
        storage: storage,
        relativePath: legalTitle,
        workPaths: [tempDirPath, targetDirPath],
      );
    }

    try {
      await Isolate.run(
        () => _performCopy(
          _CopyPlan(
            tempDirPath: tempDirPath,
            targetDirPath: targetDirPath,
            chapters: copyChapters,
          ),
        ),
      );

      if (storage.isAndroidSaf) {
        final targetDir = Directory(targetDirPath);
        final expected = await _localDirectoryStats(targetDir);
        await storage.copyLocalDirectoryInto(
          source: targetDir,
          destinationRelativePath: legalTitle,
        );
        final actual = await storage.directoryStats(legalTitle);
        if (actual.fileCount != expected.fileCount ||
            actual.totalBytes != expected.totalBytes) {
          throw const LocalComicImportException('导入后的文件校验失败');
        }
        var workCleaned = await _deleteWorkDirectory(tempDirPath);
        workCleaned = await _deleteWorkDirectory(targetDirPath) && workCleaned;
        if (!workCleaned) {
          throw const FileSystemException('无法清理导入临时文件');
        }
        await SharedPreferencesAsync().remove(_pendingImportKey);
      }
    } catch (error, stackTrace) {
      if (storage.isAndroidSaf) {
        var cleaned = true;
        try {
          await storage.deleteDirectory(legalTitle);
        } catch (_) {
          cleaned = false;
        }
        cleaned = await _deleteWorkDirectory(tempDirPath) && cleaned;
        cleaned = await _deleteWorkDirectory(targetDirPath) && cleaned;
        if (cleaned) {
          await SharedPreferencesAsync().remove(_pendingImportKey);
        }
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    return ComicDownloadTask(
        comic: DownloadComic(
          id: taskId,
          title: title,
          cover: coverRelativePath ?? '',
        ),
        chapters: chapters,
        source: DownloadTaskSource.import,
      )
      ..total = totalImages
      ..completed = totalImages
      ..status = DownloadTaskStatus.completed;
  }

  static Future<void> _writePendingImport({
    required DownloadStorage storage,
    required String relativePath,
    required List<String> workPaths,
  }) async {
    await SharedPreferencesAsync().setString(
      _pendingImportKey,
      jsonEncode({
        'storage': storage.toDescriptor(),
        'relativePath': relativePath,
        'workPaths': workPaths,
      }),
    );
  }

  static Future<NativeDirectoryStats> _localDirectoryStats(
    Directory directory,
  ) async {
    var fileCount = 0;
    var totalBytes = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File && !entity.path.endsWith('.part')) {
        fileCount += 1;
        totalBytes += await entity.length();
      }
    }
    return NativeDirectoryStats(fileCount: fileCount, totalBytes: totalBytes);
  }

  static Future<bool> _deleteWorkDirectory(String path) async {
    try {
      final directory = Directory(path);
      if (await directory.exists()) await directory.delete(recursive: true);
      return true;
    } catch (_) {
      return false;
    }
  }

  static Future<List<_ChapterImportPlan>> _buildChapterPlans(
    Directory sourceDir,
  ) async {
    final childDirs = await sourceDir
        .list(followLinks: false)
        .where((entity) => entity is Directory)
        .cast<Directory>()
        .toList();

    childDirs.sort(compareEntitiesByNaturalName);

    final chapterPlans = <_ChapterImportPlan>[];
    for (final childDir in childDirs) {
      final images = await listImageFiles(childDir);
      if (images.isEmpty) {
        continue;
      }

      chapterPlans.add(
        _ChapterImportPlan(title: p.basename(childDir.path), images: images),
      );
    }

    if (chapterPlans.isNotEmpty) {
      return chapterPlans;
    }

    final rootImages = await listImageFiles(sourceDir);
    if (rootImages.isEmpty) {
      return const [];
    }

    return [_ChapterImportPlan(title: '第1章', images: rootImages)];
  }

  static Future<String> _resolveAvailableTitle({
    required String baseTitle,
    required DownloadStorage storage,
    required Iterable<String> existingTitles,
  }) async {
    final normalizedBaseTitle = _normalizeTitle(baseTitle, fallback: '导入漫画');
    final usedLegalNames = existingTitles
        .map((title) => title.legalized.toLowerCase())
        .toSet();

    var candidate = normalizedBaseTitle;
    var suffix = 2;

    while (true) {
      final legalName = candidate.legalized;
      if (!usedLegalNames.contains(legalName.toLowerCase()) &&
          !await storage.directoryExists(legalName)) {
        return candidate;
      }

      candidate = '$normalizedBaseTitle ($suffix)';
      suffix += 1;
    }
  }

  static String _normalizeTitle(String value, {required String fallback}) {
    final normalized = value.trim();
    return normalized.isEmpty ? fallback : normalized;
  }
}

class _ChapterImportPlan {
  const _ChapterImportPlan({required this.title, required this.images});

  final String title;
  final List<File> images;
}

/// 在独立 isolate 中执行拷贝：先写入临时目录，全部成功后整目录 rename 到最终位置，
/// 保证“要么完整出现、要么完全不出现”。中途失败会清理临时目录；进程被杀导致的
/// 残留由 worker 启动时统一清理。
Future<void> _performCopy(_CopyPlan plan) async {
  final tempDir = Directory(plan.tempDirPath);
  try {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    await tempDir.create(recursive: true);

    for (final chapter in plan.chapters) {
      final chapterDir = Directory(p.join(tempDir.path, chapter.folderName));
      await chapterDir.create(recursive: true);
      for (final image in chapter.files) {
        await File(
          image.sourcePath,
        ).copy(p.join(chapterDir.path, image.fileName));
      }
    }

    if (await Directory(plan.targetDirPath).exists()) {
      throw const LocalComicImportException('目标漫画目录已存在');
    }

    await tempDir.rename(plan.targetDirPath);
  } catch (_) {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
    rethrow;
  }
}

class _CopyPlan {
  const _CopyPlan({
    required this.tempDirPath,
    required this.targetDirPath,
    required this.chapters,
  });

  final String tempDirPath;
  final String targetDirPath;
  final List<_ChapterCopyPlan> chapters;
}

class _ChapterCopyPlan {
  const _ChapterCopyPlan({required this.folderName, required this.files});

  final String folderName;
  final List<_ImageCopyPlan> files;
}

class _ImageCopyPlan {
  const _ImageCopyPlan({required this.sourcePath, required this.fileName});

  final String sourcePath;
  final String fileName;
}
