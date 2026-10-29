import { AppComposition } from '../../common/composition/AppComposition';
import { Suggestion, SuggestionFeedback } from '../../common/contracts/Content';
import { AppServices } from '../../common/contracts/Services';
import { toAppError } from '../../common/errors/AppError';
import { Unsubscribe } from '../../common/contracts/Common';
import { softSpring, V } from '../ui/VisualKit';

@Component
export struct AdvicePanel {
  onRecord: () => void = () => {};
  @State private suggestions: Suggestion[] = [];
  @State private loading: boolean = true;
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private appeared: boolean = false;
  private services: AppServices = AppComposition.getServices();
  private active: boolean = false;
  private sequence: number = 0;
  private unsubscribe: Unsubscribe | null = null;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    this.unsubscribe = this.services.changes.subscribe(() => { this.load(); });
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 70);
    this.load();
  }
  aboutToDisappear(): void {
    this.active = false;
    this.sequence += 1;
    if (this.entranceTimer !== -1) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
    if (this.unsubscribe !== null) { this.unsubscribe(); this.unsubscribe = null; }
  }
  private async load(): Promise<void> {
    const sequence = ++this.sequence;
    this.loading = true; this.error = '';
    try {
      const data = await this.services.advice.listSuggestions(this.services.clock.today());
      if (this.active && sequence === this.sequence) { this.suggestions = data; this.appeared = true; }
    } catch (error) { if (this.active && sequence === this.sequence) { this.error = toAppError(error as Object).message; } }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }
  private async respond(item: Suggestion, accept: boolean): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.error = '';
    try {
      await this.services.advice.recordFeedback(item.id, accept ? SuggestionFeedback.ACCEPTED : SuggestionFeedback.DISMISSED);
      if (this.active && accept) { this.onRecord(); }
    } catch (error) { if (this.active) { this.error = toAppError(error as Object).message; } }
    this.busy = false;
  }

  @Builder
  private suggestionCard(item: Suggestion, index: number) {
    Column({ space: 11 }) {
      Row() {
        Row({ space: 7 }) {
          Text(index + 1 < 10 ? `0${index + 1}` : `${index + 1}`)
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
            .width(24)
            .height(24)
            .textAlign(TextAlign.Center)
            .backgroundColor(V.lime)
            .borderRadius(12)
          Text('行动灵感')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(0.7)
            .fontColor(V.moss)
        }
        Blank()
        Text('来自近七天记录')
          .fontSize(8)
          .fontColor(V.sage)
      }
      .width('100%')

      Text(item.title)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.ink)
        .lineHeight(24)
        .width('100%')

      Text(item.reason)
        .fontSize(11)
        .fontColor(V.text)
        .lineHeight(18)
        .width('100%')

      Row({ space: 7 }) {
        Text('依据')
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.amber)
          .padding({ left: 7, right: 7, top: 3, bottom: 3 })
          .backgroundColor('#FBF1D8')
          .borderRadius(8)
        Text(item.evidenceSummary)
          .fontSize(9)
          .fontColor(V.sage)
          .lineHeight(14)
          .layoutWeight(1)
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Row({ space: 9 }) {
        Button('暂不考虑', { type: ButtonType.Normal })
          .fontSize(11)
          .fontColor(V.text)
          .backgroundColor('#EDF1E1')
          .height(38)
          .borderRadius(19)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { this.respond(item, false); })
        Button({ type: ButtonType.Normal }) {
          Row({ space: 4 }) {
            Text('浏览记录方式')
              .fontSize(11)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.forest)
            Text('›')
              .fontSize(15)
              .fontColor(V.forest)
          }
          .height(38)
          .justifyContent(FlexAlign.Center)
        }
        .layoutWeight(1)
        .height(38)
        .backgroundColor(V.lime)
        .borderRadius(19)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .enabled(!this.busy)
        .onClick(() => { this.respond(item, true); })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(22)
    .shadow({ radius: 14, color: '#14173B2A', offsetX: 0, offsetY: 5 })
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 14 })
    .animation({ duration: 440, delay: 70 + index * 60, curve: softSpring() })
  }

  build() {
    Column({ space: 14 }) {
      Column({ space: 7 }) {
        Text('行动灵感')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(V.moss)
          .width('100%')
        Text('从你的记录里，\n找到下一个顺手的选择。')
          .fontSize(19)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
          .lineHeight(27)
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(18)
      .backgroundColor('#F3EFD9')
      .borderRadius(22)

      Row() {
        Text('本地建议')
          .fontSize(10)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.4)
          .fontColor(V.moss)
        Blank()
        Text('离线可用')
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')

      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(20).height(20).color(V.pine)
          Text('正在整理建议…').fontSize(11).fontColor(V.text)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(V.paper)
        .borderRadius(20)
      } else if (this.error.length > 0) {
        Column({ space: 8 }) {
          Text(this.error).fontSize(11).fontColor(V.error).width('100%')
          Button('重试', { type: ButtonType.Normal })
            .fontSize(11).fontColor(V.pine).backgroundColor(V.mint).height(36).borderRadius(18)
            .onClick(() => { this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FCF1EC')
        .borderRadius(18)
      } else if (this.suggestions.length === 0) {
        Column({ space: 8 }) {
          Text('今天的建议已看完')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('明天再来看看，或先去记录一项今天的行动。')
            .fontSize(10)
            .fontColor(V.muted)
            .lineHeight(16)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(V.paper)
        .borderRadius(20)
      } else {
        ForEach(this.suggestions, (item: Suggestion, index: number) => {
          this.suggestionCard(item, index)
        }, (item: Suggestion) => item.id)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
