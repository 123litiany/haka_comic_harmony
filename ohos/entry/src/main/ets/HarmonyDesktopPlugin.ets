import { Want } from '@kit.AbilityKit';
import { FlutterPlugin, FlutterPluginBinding, MethodCall, MethodCallHandler, MethodChannel,
  MethodResult } from '@ohos/flutter_ohos';

export default class HarmonyDesktopPlugin implements FlutterPlugin, MethodCallHandler {
  private channel: MethodChannel | null = null;
  private pendingAction: string | null = null;

  getUniqueClassName(): string { return 'HarmonyDesktopPlugin'; }

  onAttachedToEngine(binding: FlutterPluginBinding): void {
    this.channel = new MethodChannel(binding.getBinaryMessenger(), 'haka_comic/ohos_desktop');
    this.channel.setMethodCallHandler(this);
  }

  onDetachedFromEngine(_binding: FlutterPluginBinding): void {
    this.channel?.setMethodCallHandler(null);
    this.channel = null;
  }

  onMethodCall(call: MethodCall, result: MethodResult): void {
    if (call.method !== 'takeAction') {
      result.notImplemented();
      return;
    }
    const action = this.pendingAction;
    this.pendingAction = null;
    result.success(action);
  }

  handleWant(want: Want): void {
    const action = this.readAction(want);
    if (action === 'search' || action === 'history' || action === 'downloads' ||
        action === 'favorites' || action === 'rank') {
      this.pendingAction = action;
      this.channel?.invokeMethod('actionAvailable', null);
    }
  }

  private readAction(want: Want): string | undefined {
    const parameters = want.parameters;
    if (!parameters) return undefined;
    const directAction = parameters.hakaAction;
    if (typeof directAction === 'string') return directAction as string;
    // FormLink serializes the card's params into a Want parameter.
    const cardParams = parameters.params;
    if (typeof cardParams !== 'string') return undefined;
    try {
      const decoded = JSON.parse(cardParams) as Record<string, Object> | null;
      const cardAction = decoded?.hakaAction;
      return typeof cardAction === 'string' ? cardAction as string : undefined;
    } catch (_) {
      return undefined;
    }
  }
}
