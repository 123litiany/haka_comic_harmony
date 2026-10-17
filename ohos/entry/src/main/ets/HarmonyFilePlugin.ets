// HarmonyOS port by 123litiany, 2026-10-16. GPL-3.0; see LICENSE.
import { AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding,
  MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { fileIo as fs, picker } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';

export default class HarmonyFilePlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private busy: boolean = false;

  getUniqueClassName(): string { return 'HarmonyFilePlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'haka_comic/ohos_files');
    this.channel.setMethodCallHandler(this);
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void { this.context = null; }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    this.context = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'supportsFolderSelection') {
      result.success(canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection'));
      return;
    }
    if (call.method === 'pickFolderSnapshot') {
      if (!canIUse('SystemCapability.FileManagement.UserFileService.FolderSelection')) {
        result.error('folder_selection_unavailable', 'This device does not support folder authorization', null);
        return;
      }
      const context = this.context;
      if (context === null) { result.error('no_ability', 'No foreground ability', null); return; }
      if (this.busy) { result.error('already_active', 'A file dialog is already open', null); return; }
      this.busy = true;
      this.pickFolderSnapshot(context).then((snapshot: Map<string, Object> | null) => {
        result.success(snapshot);
      }).catch((error: BusinessError) => {
        result.error('folder_import_failed', error.message ?? 'Unable to read selected folder', null);
      }).finally(() => { this.busy = false; });
      return;
    }
    if (call.method !== 'saveFilePath') { result.notImplemented(); return; }
    const context = this.context;
    if (context === null) { result.error('no_ability', 'No foreground ability', null); return; }
    if (this.busy) { result.error('already_active', 'A save dialog is already open', null); return; }
    const args: Map<string, Object> = call.args;
    const source = args.get('sourcePath');
    const name = args.get('fileName');
    if (typeof source !== 'string' || typeof name !== 'string' || name.length === 0 ||
      name.includes('/') || name.includes('\\') || name === '.' || name === '..') {
      result.error('invalid_argument', 'A source path and plain filename are required', null);
      return;
    }
    this.busy = true;
    this.saveFile(context, source, name).then((uri: string | null) => {
      result.success(uri);
    }).catch((error: BusinessError) => {
      result.error('save_failed', error.message ?? 'Unable to save file', null);
    }).finally(() => { this.busy = false; });
  }

  private async pickFolderSnapshot(context: common.UIAbilityContext): Promise<Map<string, Object> | null> {
    const options = new picker.DocumentSelectOptions();
    options.selectMode = picker.DocumentSelectMode.FOLDER;
    const uris = await new picker.DocumentViewPicker(context).select(options);
    if (uris.length === 0) return null;
    const folder = await fs.open(uris[0], fs.OpenMode.READ_ONLY);
    let temporary: string | null = null;
    try {
      temporary = await fs.mkdtemp(`${context.cacheDir}/haka-folder-XXXXXX`);
      const files: Map<string, Object>[] = [];
      await this.copyFolder(folder.path, temporary, '', files, 0);
      const snapshot = new Map<string, Object>();
      snapshot.set('name', folder.name);
      snapshot.set('localPath', temporary);
      snapshot.set('files', files);
      return snapshot;
    } catch (error) {
      if (temporary !== null) await fs.rmdir(temporary);
      throw new Error((error as BusinessError).message ?? 'Unable to copy selected folder');
    } finally {
      await fs.close(folder);
    }
  }

  private async copyFolder(source: string, destination: string, relative: string,
    files: Map<string, Object>[], depth: number): Promise<void> {
    if (depth > 64) throw new Error('Folder nesting exceeds the import limit');
    const names = await fs.listFile(source);
    for (const name of names) {
      if (name === '.' || name === '..' || name.includes('/') || name.includes('\\')) {
        throw new Error('Invalid folder entry');
      }
      const sourcePath = `${source}/${name}`;
      const localPath = `${destination}/${name}`;
      const relativePath = relative.length === 0 ? name : `${relative}/${name}`;
      const stat = await fs.lstat(sourcePath);
      if (stat.isSymbolicLink()) continue;
      if (stat.isDirectory()) {
        await fs.mkdir(localPath);
        await this.copyFolder(sourcePath, localPath, relativePath, files, depth + 1);
      } else if (stat.isFile()) {
        await fs.copyFile(sourcePath, localPath);
        const entry = new Map<string, Object>();
        entry.set('name', name);
        entry.set('relativePath', relativePath);
        entry.set('localPath', localPath);
        entry.set('size', stat.size);
        files.push(entry);
      }
    }
  }

  private async saveFile(context: common.UIAbilityContext, sourcePath: string,
    fileName: string): Promise<string | null> {
    let source: fs.File | null = null;
    let destination: fs.File | null = null;
    try {
      // Open first so a missing export never produces an empty destination.
      source = await fs.open(sourcePath, fs.OpenMode.READ_ONLY);
      const documentPicker = new picker.DocumentViewPicker(context);
      const options = new picker.DocumentSaveOptions();
      options.newFileNames = [fileName];
      const uris = await documentPicker.save(options);
      if (uris.length === 0) return null;
      destination = await fs.open(uris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE | fs.OpenMode.TRUNC);
      // Native file-descriptor copying avoids loading an entire comic into Dart/IPC memory.
      await fs.copyFile(source.fd, destination.fd);
      await fs.fsync(destination.fd);
      return uris[0];
    } finally {
      try {
        if (destination !== null) await fs.close(destination);
      } finally {
        if (source !== null) await fs.close(source);
      }
    }
  }
}
