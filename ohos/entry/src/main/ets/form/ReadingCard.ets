@Entry
@Component
struct ReadingCard {
  @Builder
  action(label: Resource, icon: Resource, target: string, stacked: boolean = true) {
    FormLink({
      action: 'router',
      abilityName: 'EntryAbility',
      params: { hakaAction: target }
    }) {
      Flex({
        direction: stacked ? FlexDirection.Column : FlexDirection.Row,
        justifyContent: stacked ? FlexAlign.Center : FlexAlign.Start,
        alignItems: ItemAlign.Center
      }) {
        Image(icon).width(16).height(16).accessibilityLevel('no');
        Text(label)
          .margin(stacked ? { top: 1 } : { left: 6 })
          .fontSize(stacked ? 12 : 13)
          .minFontSize(10)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .fontWeight(FontWeight.Medium)
          .fontColor($r('app.color.card_ink'));
      }
      .width('100%')
      .height('100%')
      .padding({ left: stacked ? 2 : 8, right: stacked ? 2 : 8 })
      .borderRadius(10)
      .backgroundColor($r('app.color.card_action'));
    }
    .height('100%')
    .layoutWeight(1);
  }

  build() {
    Column({ space: 4 }) {
      Row({ space: 6 }) {
        Image($r('app.media.icon')).width(17).height(17).borderRadius(5).accessibilityLevel('no');
        Text('HaKa').fontSize(14).fontWeight(FontWeight.Bold).fontColor($r('app.color.card_ink'));
      }
      .width('100%')
      .padding({ left: 4, bottom: 2 });

      Row() {
        this.action($r('app.string.shortcut_search'), $r('app.media.shortcut_search'), 'search', false);
      }.width('100%').layoutWeight(1);
      Row({ space: 4 }) {
        this.action($r('app.string.shortcut_favorites'), $r('app.media.shortcut_favorites'), 'favorites');
        this.action($r('app.string.shortcut_rank'), $r('app.media.shortcut_rank'), 'rank');
      }.width('100%').layoutWeight(1.35);
      Row({ space: 4 }) {
        this.action($r('app.string.shortcut_history'), $r('app.media.shortcut_history'), 'history');
        this.action($r('app.string.shortcut_downloads'), $r('app.media.shortcut_downloads'), 'downloads');
      }.width('100%').layoutWeight(1.35);
    }
    .width('100%')
    .height('100%')
    .padding(9)
    .backgroundColor($r('app.color.card_surface'));
  }
}
