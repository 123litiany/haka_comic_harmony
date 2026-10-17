/*
 * Copyright (C) 2024 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import {
  Any,
  AbilityPluginBinding,
  BinaryMessenger,
  EventChannel,
  EventSink,
  FlutterPlugin,
  FlutterPluginBinding,
  MethodCall,
  MethodCallHandler,
  MethodChannel,
  MethodResult,
  StreamHandler,
} from '@ohos/flutter_ohos';
import { UIAbility } from '@kit.AbilityKit';
import { FilePickerDelegate } from './FilePickerDelegate';
import { FileUtils } from './FileUtils';
import fs from '@ohos.file.fs';
import deviceInfo from '@ohos.deviceInfo';
import { BusinessError } from '@kit.BasicServicesKit';

/** FilePickerPlugin **/
const CHANNEL: string = 'miguelruivo.flutter.plugins.filepicker';
const TAG: string = 'FilePicker'
const EVENT_CHANNEL: string = 'miguelruivo.flutter.plugins.filepickerevent'

export default class FilePickerPlugin implements FlutterPlugin, MethodCallHandler, StreamHandler {
  private channel: MethodChannel | null = null;
  private eventChannel: EventChannel | null = null;
  private abilityBinding: AbilityPluginBinding | null = null;
  private pluginBinding: FlutterPluginBinding | null = null;
  private ability: UIAbility | null = null;
  private fileType: string | null = null;
  private isMultipleSelection: boolean = false;
  private withData: boolean = false;
  private delegate: FilePickerDelegate | null = null;
  private allowedExtensions: string[] = [];

  constructor() {
  }

  getUniqueClassName(): string {
    return 'FilePickerPlugin'
  }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.abilityBinding = null
    this.pluginBinding = binding
  }

  /**
   * 统一释放 Ability 与 MethodChannel 相关资源。
   * 供 onDetachedFromEngine / onDetachedFromAbility 共用，确保任何 detach 路径
   * 都清空全部状态（含 fileType/isMultipleSelection/withData/allowedExtensions），
   * 避免 Ability 因配置变更（如屏幕旋转）重建后残留旧状态。
   */
  private releaseAbilityAndChannelResources(): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
    // 注销事件通道，解除 Flutter 端事件订阅；StreamHandler.onCancel 会清空 delegate 的 eventSink
    this.eventChannel?.setStreamHandler(null);
    this.eventChannel = null;
    // dispose 会 resolve 进行中的 pendingResult、解除事件订阅并清空数据缓存，避免引用泄漏
    this.delegate?.dispose();
    this.delegate = null;
    this.abilityBinding = null;
    this.ability = null;
    this.fileType = null;
    this.isMultipleSelection = false;
    this.withData = false;
    this.allowedExtensions = [];
  }

  onDetachedFromEngine(binding: FlutterPluginBinding): void {
    this.releaseAbilityAndChannelResources();
    this.pluginBinding = null;
  }

  onDetachedFromAbility(binding: AbilityPluginBinding): void {
    this.releaseAbilityAndChannelResources();
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.abilityBinding = binding;
    const messenger = this.pluginBinding?.getBinaryMessenger();
    if (messenger != null) {
      this.setup(messenger, binding.getAbility(), binding);
    }
  }

  /** Flutter 端订阅 EVENT_CHANNEL 时触发，将事件回调交给 delegate 转发 */
  onListen(args: Any, events: EventSink): void {
    this.delegate?.setEventHandler(events);
  }

  /** Flutter 端取消订阅时触发，解除事件回调避免 delegate 持有过期 sink */
  onCancel(args: Any): void {
    this.delegate?.removeEventHandler();
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    try {
      this.handleMethodCall(call, result);
    } catch (error) {
      const e = error as BusinessError;
      console.error('FilePickerPlugin.onMethodCall failed: ' + e.message);
      result.error('runtime_error', 'Unexpected error while handling method call: ' + e.message, null);
    }
  }

  private handleMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method === 'sdkApiVersion') {
      // 版本查询不依赖 Ability 上下文，放在最前面；供 Dart 侧做特性检测
      // （如 DocumentSelectMode.FOLDER 在手机端需 API 26 及以上）
      result.success(deviceInfo.sdkApiVersion);
      return;
    }
    const clearAbility = this.ability;
    if (clearAbility == null || clearAbility.context == null) {
      result.error('no_activity', 'file picker plugin requires a foreground ability', null);
      return;
    }
    const args: Map<string, Object> = call.args;
    this.fileType = call.method;
    if (call.method === 'clear') {
      // 并发守卫：文件选取/保存操作进行中时拒绝 clear，避免清空正在使用的 bytesList
      // 或删除正在被 openFileStream 复制使用的缓存文件
      if (this.delegate?.hasPendingResult()) {
        result.error('already_active', 'Cannot clear while file picker is active', null);
        return;
      }
      this.delegate?.clearBytesList(); // 清除选中文件
      const cachePath: string = clearAbility.context.cacheDir + '/file_picker'; // 自定义缓存路径
      fs.access(cachePath).then((res: boolean) => {
        if (res) {
          result.success(FileUtils.clearCache(clearAbility));
        } else {
          result.success(true);
        }
      }).catch((err: BusinessError) => {
        console.error('Failed to clear cache: ' + err.message);
        result.error('clear_cache_failed', 'Failed to clear cache: ' + err.message, null);
      })
      return;
    }
    if (call.method === 'save') {
      // args.get() 返回 Object，需校验实际类型后再强转，避免类型不匹配导致运行时错误
      const rawFileName = args.get('fileName');
      if (rawFileName != null && typeof rawFileName !== 'string') {
        result.error('invalid_argument', 'fileName must be a string', null);
        return;
      }
      const fileName: string | null = rawFileName as string | null;
      const rawType = args.get('fileType');
      if (rawType != null && typeof rawType !== 'string') {
        result.error('invalid_argument', 'fileType must be a string', null);
        return;
      }
      const type: string | null = rawType as string | null;
      const rawInitialDirectory = args.get('initialDirectory');
      if (rawInitialDirectory != null && typeof rawInitialDirectory !== 'string') {
        result.error('invalid_argument', 'initialDirectory must be a string', null);
        return;
      }
      const initialDirectory: string | null = rawInitialDirectory as string | null;
      // args.get() 返回 Object，需校验实际类型后再强转，避免类型不匹配导致运行时错误
      const rawAllowedExtensions: Object | undefined = args.get('allowedExtensions');
      if (rawAllowedExtensions != null && !(rawAllowedExtensions instanceof Array)) {
        result.error('invalid_argument', 'allowedExtensions must be an Array', null);
        return;
      }
      const allowedExtensions: string[] | null = rawAllowedExtensions as string[] | null;
      const rawBytes: Object | undefined = args.get('bytes');
      if (rawBytes != null && !(rawBytes instanceof Uint8Array)) {
        result.error('invalid_argument', 'bytes must be a Uint8Array', null);
        return;
      }
      const bytes: Uint8Array | null = rawBytes as Uint8Array | null;
      if (fileName == null || bytes == null) {
        result.error('invalid_argument', 'fileName and bytes are required when saving a file', null);
        return;
      }
      // 使用本次调用传入的 allowedExtensions，而非前一次 pickFiles 缓存的 this.allowedExtensions
      const allowedExtensionsList: string[] = [];
      if (allowedExtensions != null && allowedExtensions.length != 0) {
        allowedExtensions.forEach((item) => {
          // fileSuffixChoices 要求带点后缀（如 ".pdf"），Dart 侧传入的是不带点的裸后缀
          allowedExtensionsList.push(item.startsWith('.') ? item : `.${item}`);
        })
      }
      this.delegate?.saveFile([fileName], type, initialDirectory, allowedExtensionsList, result, bytes)
      return;
    }
    if (this.fileType == null) {
      result.notImplemented();
      return;
    }
    const multipleSelection = args.get('allowMultipleSelection');
    if (multipleSelection != null && typeof multipleSelection !== 'boolean') {
      result.error('invalid_argument', 'allowMultipleSelection must be a boolean', null);
      return;
    }
    this.isMultipleSelection = multipleSelection != null ? multipleSelection as boolean : false;
    // args.get() 返回 Object，需校验实际类型后再强转，避免类型不匹配导致运行时错误
    const rawAllowedExtensions: Object | undefined = args.get('allowedExtensions');
    if (rawAllowedExtensions != null && !(rawAllowedExtensions instanceof Array)) {
      result.error('invalid_argument', 'allowedExtensions must be an Array', null);
      return;
    }
    const allowedExtensions: string[] | null = rawAllowedExtensions as string[] | null;
    const withData = args.get('withData');
    if (withData != null && typeof withData !== 'boolean') {
      result.error('invalid_argument', 'withData must be a boolean', null);
      return;
    }
    this.withData = withData != null ? withData as boolean : false;
    // 先清空再填充，避免历史数据累积；try-finally 确保任何路径下都重置
    this.allowedExtensions = [];
    if (allowedExtensions != null && allowedExtensions.length != 0) {
      allowedExtensions.forEach((item) => {
        this.allowedExtensions.push(`.${item}`);
      })
    }
    try {
      if (this.delegate) {
        this.delegate.startFileExplorer(this.fileType, this.isMultipleSelection, this.withData,
          this.allowedExtensions, result);
      }
    } finally {
      this.allowedExtensions = [];
    }
  }

  setup(messenger: BinaryMessenger, ability: UIAbility, activityBinding: AbilityPluginBinding) {
    // 先释放旧实例，防止 setup 被重复调用（如 Ability 因配置变更重建后再次附加）时旧资源泄漏
    if (this.delegate != null) {
      this.delegate.dispose();
      this.delegate = null;
    }
    if (this.channel != null) {
      this.channel.setMethodCallHandler(null);
      this.channel = null;
    }
    if (this.eventChannel != null) {
      this.eventChannel.setStreamHandler(null);
      this.eventChannel = null;
    }
    this.ability = ability;
    this.delegate = new FilePickerDelegate(ability);
    this.channel = new MethodChannel(messenger, CHANNEL);
    this.channel.setMethodCallHandler(this);
    // 注册事件通道，使 Flutter 端 onFileLoading 回调能接收文件选取状态
    this.eventChannel = new EventChannel(messenger, EVENT_CHANNEL);
    this.eventChannel.setStreamHandler(this);
  }
}
