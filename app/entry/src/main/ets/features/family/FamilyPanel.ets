import curves from '@ohos.curves';
import { V } from '../ui/VisualKit';

@Component
export struct FamilyPanel {
  @State private selectedMember: number = 0;
  @State private relayJoined: boolean = false;
  @State private appeared: boolean = false;
  private entranceTimer: number = -1;
  private readonly entranceCurve: curves.ICurve = curves.springMotion(0.55, 0.72);
  private names: string[] = ['全部', '小满', '妈妈', '爸爸'];

  aboutToAppear(): void {
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 30);
  }

  aboutToDisappear(): void {
    if (this.entranceTimer !== -1) { clearTimeout(this.entranceTimer); }
  }

  @Builder
  private memberChip(name: string, index: number) {
    Button(name, { type: ButtonType.Normal })
      .fontSize(12)
      .fontWeight(this.selectedMember === index ? FontWeight.Bold : FontWeight.Normal)
      .fontColor(this.selectedMember === index ? V.forest : V.pine)
      .backgroundColor(this.selectedMember === index ? V.lime : '#EAF0DF')
      .height(34)
      .borderRadius(17)
      .padding({ left: 15, right: 15 })
      .clickEffect({ level: ClickEffectLevel.MIDDLE })
      .onClick(() => { animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.selectedMember = index; }); })
  }

  @Builder
  private activity(avatar: string, name: string, action: string, amount: string, tint: string) {
    Row({ space: 12 }) {
      Text(avatar)
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.pine)
        .width(40)
        .height(40)
        .textAlign(TextAlign.Center)
        .backgroundColor(tint)
        .borderRadius(20)
      Column({ space: 4 }) {
        Text(name).fontSize(13).fontWeight(FontWeight.Medium).fontColor(V.ink)
        Text(action).fontSize(10).fontColor(V.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
      Text(amount).fontSize(13).fontWeight(FontWeight.Medium).fontColor(V.pine)
    }
    .width('100%')
    .padding({ top: 9, bottom: 9 })
  }

  build() {
    Column({ space: 14 }) {
      Stack() {
        Circle()
          .width(190)
          .height(190)
          .fill('#00000000')
          .stroke('#D9F26E')
          .strokeWidth(1)
          .opacity(0.2)
          .position({ x: 230, y: -90 })
        Circle()
          .width(100)
          .height(100)
          .fill(V.lime)
          .opacity(0.1)
          .position({ x: 280, y: 40 })
        Column({ space: 10 }) {
          Row() {
            Text('FAMILY  /  绿色账本')
              .fontSize(9)
              .fontWeight(FontWeight.Bold)
              .letterSpacing(1.1)
              .fontColor('#C4D9C3')
            Blank()
            Text('体验预览')
              .fontSize(8)
              .fontColor(V.forest)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(V.limeSoft)
              .borderRadius(9)
          }
          .width('100%')
          Text('一家人的小行动，\n一起积累成大改变。')
            .fontSize(23)
            .fontWeight(FontWeight.Bold)
            .fontColor('#F7FAF2')
            .lineHeight(32)
            .width('100%')
          Text('把绿色生活，过成共同的习惯。')
            .fontSize(11)
            .fontColor('#CADBCB')
            .width('100%')
          Row({ space: 7 }) {
            Text('✦').fontSize(15).fontColor(V.lime)
            Text('家庭接力 · 从今天开始')
              .fontSize(10)
              .fontColor('#E9F1E5')
          }
          .margin({ top: 4 })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .borderRadius(26)
      .clip(true)
      .linearGradient({
        angle: 130,
        colors: [['#0D382A', 0.0], ['#174C39', 0.6], ['#2C664B', 1.0]]
      })
      .shadow({ radius: 22, color: '#4D0E3526', offsetX: 0, offsetY: 10 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 18 })
      .scale({ x: this.appeared ? 1 : 0.97, y: this.appeared ? 1 : 0.97 })
      .animation({ duration: 550, curve: this.entranceCurve })

      Column({ space: 12 }) {
        Row() {
          Column({ space: 3 }) {
            Text('家庭贡献')
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.ink)
            Text('每一份努力，都值得被看见')
              .fontSize(9)
              .fontColor(V.muted)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Text('示例数据')
            .fontSize(8)
            .fontColor('#A06D32')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FBF1D8')
            .borderRadius(10)
        }
        .width('100%')
        Row() {
          Column({ space: 3 }) {
            Text('家庭累计减排')
              .fontSize(9)
              .fontColor(V.muted)
            Row({ space: 4 }) {
              Text('26.23')
                .fontSize(30)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.ink)
              Text('kg CO₂')
                .fontSize(11)
                .fontColor(V.muted)
            }
            .alignItems(VerticalAlign.Bottom)
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)
          Column({ space: 3 }) {
            Text('参与成员')
              .fontSize(9)
              .fontColor(V.muted)
            Text('3 人')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.ink)
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
        .padding({ top: 6, bottom: 2 })
        Text('以上为界面示例，不代表真实家庭数据。')
          .fontSize(9)
          .fontColor(V.sage)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .backgroundColor(V.paper)
      .border({ width: 1, color: '#E9EEDF' })
      .borderRadius(22)
      .shadow({ radius: 14, color: '#14173B2A', offsetX: 0, offsetY: 5 })
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 20 })
      .scale({ x: this.appeared ? 1 : 0.97, y: this.appeared ? 1 : 0.97 })
      .animation({ duration: 550, delay: 80, curve: this.entranceCurve })

      Column({ space: 11 }) {
        Row() {
          Text('绿色任务接力')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
            .layoutWeight(1)
          Text('示例任务')
            .fontSize(8)
            .fontColor('#A06D32')
            .padding({ left: 8, right: 8, top: 4, bottom: 4 })
            .backgroundColor('#FBF1D8')
            .borderRadius(10)
        }
        .width('100%')
        Text('一周节电小约定')
          .fontSize(14)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.ink)
        Text('和家人一起，留意随手关灯的小事。')
          .fontSize(10)
          .fontColor(V.muted)
          .lineHeight(16)
        Row() {
          Text('接力进度')
            .fontSize(9)
            .fontColor(V.muted)
            .layoutWeight(1)
          Text(this.relayJoined ? '3 / 3 人（预览）' : '2 / 3 人（示例）')
            .fontSize(9)
            .fontColor(V.pine)
        }
        .width('100%')
        Progress({ value: this.relayJoined ? 3 : 2, total: 3, type: ProgressType.Linear })
          .color('#7E9F53')
          .backgroundColor('#E9EFE0')
          .height(6)
          .width('100%')
        Button(this.relayJoined ? '已参与体验 · 点击撤回' : '体验参与接力', { type: ButtonType.Normal })
          .id('family-relay-preview')
          .clickEffect({ level: ClickEffectLevel.MIDDLE })
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.relayJoined ? V.pine : V.forest)
          .backgroundColor(this.relayJoined ? '#EAF0DF' : V.lime)
          .width('100%')
          .height(42)
          .borderRadius(21)
          .onClick(() => {
            animateTo({ duration: 280, curve: this.entranceCurve }, () => { this.relayJoined = !this.relayJoined; });
          })
        Text('仅演示交互，不会创建或同步真实任务。')
          .fontSize(9)
          .fontColor(V.sage)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .backgroundColor(V.paper)
      .border({ width: 1, color: '#E9EEDF' })
      .borderRadius(22)
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 20 })
      .scale({ x: this.appeared ? 1 : 0.97, y: this.appeared ? 1 : 0.97 })
      .animation({ duration: 550, delay: 160, curve: this.entranceCurve })

      Column({ space: 11 }) {
        Text('家庭动态')
          .fontSize(16)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Scroll() {
          Row({ space: 7 }) {
            ForEach(this.names, (name: string, index: number) => { this.memberChip(name, index); }, (name: string) => name)
          }
        }
        .scrollable(ScrollDirection.Horizontal)
        .scrollBar(BarState.Off)
        .width('100%')
        if (this.selectedMember === 0 || this.selectedMember === 1) {
          this.activity('满', '小满', '节约用电 · 今天', '−0.53 kg', '#E5EEDF')
        }
        if (this.selectedMember === 0 || this.selectedMember === 2) {
          this.activity('妈', '妈妈', '减少食物浪费 · 昨天', '−0.70 kg', '#F5EBDD')
        }
        if (this.selectedMember === 0 || this.selectedMember === 3) {
          this.activity('爸', '爸爸', '闲置手机再利用 · 本周', '−25.00 kg', '#E5EDF0')
        }
        Text('示例动态仅用于展示界面。')
          .fontSize(9)
          .fontColor(V.sage)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .backgroundColor(V.paper)
      .border({ width: 1, color: '#E9EEDF' })
      .borderRadius(22)
      .opacity(this.appeared ? 1 : 0)
      .translate({ y: this.appeared ? 0 : 20 })
      .scale({ x: this.appeared ? 1 : 0.97, y: this.appeared ? 1 : 0.97 })
      .animation({ duration: 550, delay: 240, curve: this.entranceCurve })

      Text('家庭成员连接、数据汇总和多设备同步尚在规划中。')
        .fontSize(9)
        .fontColor(V.sage)
        .lineHeight(16)
        .width('100%')
    }
    .width('100%')
    .alignItems(HorizontalAlign.Start)
  }
}
