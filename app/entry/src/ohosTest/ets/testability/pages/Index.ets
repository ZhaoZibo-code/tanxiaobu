import { StatusPanel, ViewStatus } from '../../../../main/ets/common/design/StatusPanel';

@Entry
@Component
struct Index {
  @State private status: ViewStatus = ViewStatus.EMPTY;
  @State private title: string = '暂无记录';
  @State private message: string = '隔离测试状态，不代表正式业务数据。';
  @State private retryable: boolean = false;
  @State private retries: number = 0;

  build() {
    Column({ space: 20 }) {
      Text('M01 状态组件隔离测试')
        .fontSize(20)
      Text('仅存在于 entry_test，正式包不注册此页。')
      Row({ space: 12 }) {
        Button('加载')
          .id('test-state-loading')
          .onClick(() => {
            this.status = ViewStatus.LOADING;
            this.title = '正在读取';
            this.retryable = false;
          })
        Button('空状态')
          .id('test-state-empty')
          .onClick(() => {
            this.status = ViewStatus.EMPTY;
            this.title = '暂无记录';
            this.retryable = false;
          })
        Button('错误')
          .id('test-state-error')
          .onClick(() => {
            this.status = ViewStatus.ERROR;
            this.title = '测试读取失败';
            this.retryable = true;
          })
      }
      StatusPanel({
        status: this.status, title: this.title, message: this.message, retryable: this.retryable,
        retry: () => {
          this.retries += 1;
          this.status = ViewStatus.EMPTY;
          this.title = '暂无记录';
          this.retryable = false;
        }
      })
      Text(`重试次数：${this.retries}`)
        .id('test-retry-count')
    }
    .width('100%')
    .height('100%')
    .justifyContent(FlexAlign.Center)
    .padding(20)
  }
}
