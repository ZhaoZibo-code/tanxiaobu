import { AppColors, AppRadius, AppSpace, AppType } from './Theme';

export enum ViewStatus {
  LOADING = 'loading',
  EMPTY = 'empty',
  ERROR = 'error',
  UNAVAILABLE = 'unavailable',
  CONNECTED = 'connected'
}

@Component
export struct StatusPanel {
  @Prop status: ViewStatus = ViewStatus.LOADING;
  @Prop title: string = '';
  @Prop message: string = '';
  @Prop retryable: boolean = false;
  retry: () => void = () => {};

  build() {
    Column({ space: AppSpace.sm }) {
      if (this.status === ViewStatus.LOADING) {
        LoadingProgress()
          .width(28)
          .height(28)
          .color(AppColors.primary)
      }
      Text(this.title)
        .id('shell-status-title')
        .fontSize(AppType.section)
        .fontWeight(FontWeight.Medium)
        .fontColor(this.status === ViewStatus.ERROR ? AppColors.error : AppColors.ink)
        .width('100%')
      Text(this.message)
        .id('shell-status-message')
        .fontSize(AppType.body)
        .fontColor(AppColors.secondary)
        .lineHeight(25)
        .width('100%')
      if (this.retryable) {
        Button('重新加载', { type: ButtonType.Normal })
          .id('shell-retry')
          .fontSize(AppType.body)
          .fontColor(AppColors.primary)
          .backgroundColor(AppColors.soft)
          .borderRadius(AppRadius.control)
          .height(44)
          .onClick(() => this.retry())
      }
    }
    .alignItems(HorizontalAlign.Start)
    .padding(AppSpace.md)
    .width('100%')
    .backgroundColor(AppColors.surface)
    .borderRadius(AppRadius.panel)
    .border({ width: 1, color: AppColors.line })
  }
}
