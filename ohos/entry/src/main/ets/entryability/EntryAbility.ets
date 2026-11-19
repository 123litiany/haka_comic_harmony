
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { AbilityConstant, Want } from '@kit.AbilityKit';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import HarmonyDesktopPlugin from '../HarmonyDesktopPlugin';
import HarmonyFilePlugin from '../HarmonyFilePlugin';
import HarmonyReaderPlugin from '../HarmonyReaderPlugin';

export default class EntryAbility extends FlutterAbility {
  private readerPlugin: HarmonyReaderPlugin = new HarmonyReaderPlugin();
  private desktopPlugin: HarmonyDesktopPlugin = new HarmonyDesktopPlugin();

  onCreate(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    this.desktopPlugin.handleWant(want);
    super.onCreate(want, launchParam);
  }

  onNewWant(want: Want, launchParam: AbilityConstant.LaunchParam): void {
    super.onNewWant(want, launchParam);
    this.desktopPlugin.handleWant(want);
  }

  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new HarmonyFilePlugin())
    flutterEngine.getPlugins()?.add(this.readerPlugin)
    flutterEngine.getPlugins()?.add(this.desktopPlugin)
  }

  onForeground(): void {
    super.onForeground();
    this.readerPlugin.onForeground();
  }

  onBackground(): void {
    this.readerPlugin.onBackground();
    super.onBackground();
  }
}
