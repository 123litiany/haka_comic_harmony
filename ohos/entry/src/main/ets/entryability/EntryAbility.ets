
import { FlutterAbility, FlutterEngine } from '@ohos/flutter_ohos';
import { GeneratedPluginRegistrant } from '../plugins/GeneratedPluginRegistrant';
import HarmonyFilePlugin from '../HarmonyFilePlugin';
import HarmonyReaderPlugin from '../HarmonyReaderPlugin';

export default class EntryAbility extends FlutterAbility {
  private readerPlugin: HarmonyReaderPlugin = new HarmonyReaderPlugin();
  configureFlutterEngine(flutterEngine: FlutterEngine) {
    super.configureFlutterEngine(flutterEngine)
    GeneratedPluginRegistrant.registerWith(flutterEngine)
    flutterEngine.getPlugins()?.add(new HarmonyFilePlugin())
    flutterEngine.getPlugins()?.add(this.readerPlugin)
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
