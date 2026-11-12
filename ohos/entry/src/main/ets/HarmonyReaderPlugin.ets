// HarmonyOS reader integration. GPL-3.0; see LICENSE.
import { AbilityPluginBinding, FlutterPlugin, FlutterPluginBinding,
  MethodCall, MethodCallHandler, MethodChannel, MethodResult } from '@ohos/flutter_ohos';
import { common } from '@kit.AbilityKit';
import { inputConsumer, KeyCode, KeyEvent } from '@kit.InputKit';
import window from '@ohos.window';
import { BusinessError } from '@kit.BasicServicesKit';

export default class HarmonyReaderPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private context: common.UIAbilityContext | null = null;
  private foreground: boolean = true;
  private active: boolean = false;
  private volumeKeys: boolean = false;
  private keepScreenOn: boolean = true;
  private brightness: number = -1;
  private upSubscribed: boolean = false;
  private downSubscribed: boolean = false;
  private originalBrightness: number | null = null;
  private originalKeepScreenOn: boolean | null = null;
  private pending: Promise<void> = Promise.resolve();

  private onVolumeUp = (_event: KeyEvent): void => { this.sendKey('up'); };
  private onVolumeDown = (_event: KeyEvent): void => { this.sendKey('down'); };

  getUniqueClassName(): string { return 'HarmonyReaderPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'haka_comic/ohos_reader');
    this.channel.setMethodCallHandler(this);
  }

  onAttachedToAbility(binding: AbilityPluginBinding): void {
    this.context = binding.getAbility().context;
  }

  onDetachedFromAbility(): void {
    this.active = false;
    this.releaseKeys();
    // Capture context before detachment to restore the original window settings.
    this.enqueue().catch((error: BusinessError) => this.report(error));
    this.context = null;
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.active = false;
    this.releaseKeys();
    this.enqueue().catch((error: BusinessError) => this.report(error));
    this.context = null;
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onForeground(): void {
    this.foreground = true;
    this.enqueue().catch((error: BusinessError) => this.report(error));
  }

  onBackground(): void {
    this.foreground = false;
    this.releaseKeys();
    this.enqueue().catch((error: BusinessError) => this.report(error));
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'configure') { result.notImplemented(); return; }
    const args: Map<string, Object> = call.args;
    const active = args.get('active');
    const volumeKeys = args.get('volumeKeys');
    const keepScreenOn = args.get('keepScreenOn');
    const brightness = args.get('brightness');
    if (typeof active !== 'boolean' || typeof volumeKeys !== 'boolean' ||
      typeof keepScreenOn !== 'boolean' || typeof brightness !== 'number' ||
      !Number.isFinite(brightness) || (brightness !== -1 && (brightness < 0.05 || brightness > 1))) {
      result.error('invalid_argument', 'Invalid reader preferences', null);
      return;
    }
    this.active = active;
    this.volumeKeys = volumeKeys;
    this.keepScreenOn = keepScreenOn;
    this.brightness = brightness;
    if (!active || !volumeKeys) this.releaseKeys();
    this.enqueue().then(() => {
      result.success(this.upSubscribed && this.downSubscribed);
    }).catch((error: BusinessError) => {
      this.releaseKeys();
      result.error('reader_controls_failed', error.message ?? 'Unable to configure reader', null);
    });
  }

  private enqueue(): Promise<void> {
    const context = this.context;
    const update = this.pending.then(async (): Promise<void> => {
      if (context === null) return;
      const mainWindow = await window.getLastWindow(context);
      const active = this.active && this.foreground;
      if (active) {
        if (this.originalBrightness === null) {
          const properties = mainWindow.getWindowProperties();
          this.originalBrightness = properties.brightness;
          this.originalKeepScreenOn = properties.isKeepScreenOn;
        }
        await mainWindow.setWindowKeepScreenOn(this.keepScreenOn);
        await mainWindow.setWindowBrightness(this.brightness);
      } else if (this.originalBrightness !== null && this.originalKeepScreenOn !== null) {
        await mainWindow.setWindowKeepScreenOn(this.originalKeepScreenOn);
        await mainWindow.setWindowBrightness(this.originalBrightness);
        this.originalBrightness = null;
        this.originalKeepScreenOn = null;
      }
      if (this.active && this.foreground && this.volumeKeys) this.subscribeKeys();
      else this.releaseKeys();
    });
    this.pending = update.catch((error: BusinessError) => this.report(error));
    return update;
  }

  private subscribeKeys(): void {
    if (this.upSubscribed && this.downSubscribed) return;
    if (!canIUse('SystemCapability.MultimodalInput.Input.InputConsumer')) return;
    try {
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_UP, action: 1, isRepeat: false
      }, this.onVolumeUp);
      this.upSubscribed = true;
      inputConsumer.on('keyPressed', {
        key: KeyCode.KEYCODE_VOLUME_DOWN, action: 1, isRepeat: false
      }, this.onVolumeDown);
      this.downSubscribed = true;
    } catch (error) {
      this.releaseKeys();
      this.report(error as BusinessError);
    }
  }

  private releaseKeys(): void {
    if (this.upSubscribed) {
      try { inputConsumer.off('keyPressed', this.onVolumeUp); this.upSubscribed = false; }
      catch (error) { this.report(error as BusinessError); }
    }
    if (this.downSubscribed) {
      try { inputConsumer.off('keyPressed', this.onVolumeDown); this.downSubscribed = false; }
      catch (error) { this.report(error as BusinessError); }
    }
  }

  private sendKey(direction: string): void {
    if (this.active && this.foreground && this.volumeKeys) {
      this.channel?.invokeMethod('volumeKey', direction);
    }
  }

  private report(error: BusinessError): void {
    console.error(`HarmonyReader: ${error.code}: ${error.message}`);
  }
}
