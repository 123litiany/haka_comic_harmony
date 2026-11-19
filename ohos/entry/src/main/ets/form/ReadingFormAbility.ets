import { Want } from '@kit.AbilityKit';
import { FormExtensionAbility, formBindingData } from '@kit.FormKit';

export default class ReadingFormAbility extends FormExtensionAbility {
  onAddForm(_want: Want): formBindingData.FormBindingData {
    return formBindingData.createFormBindingData({});
  }
}
