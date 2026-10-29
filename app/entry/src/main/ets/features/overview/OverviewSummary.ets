import { AppComposition } from '../../common/composition/AppComposition';
import { StatisticsPeriod, Unsubscribe } from '../../common/contracts/Common';
import { AppServices } from '../../common/contracts/Services';
import { StatisticsResult } from '../../common/contracts/Statistics';
import { formatReduction } from '../../common/utils/Display';
import { AnimatedReduction, V } from '../ui/VisualKit';

@Component
export struct OverviewSummary {
  onStatistics: () => void = () => {};
  onRecord: () => void = () => {};
  @State private result: StatisticsResult | null = null;
  @State private loading: boolean = true;
  @State private failed: boolean = false;
  private services: AppServices = AppComposition.getServices();
  private active: boolean = false;
  private sequence: number = 0;
  private unsubscribe: Unsubscribe | null = null;

  aboutToAppear(): void {
    this.active = true;
    this.unsubscribe = this.services.changes.subscribe(() => { this.load(); });
    this.load();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.sequence += 1;
    if (this.unsubscribe !== null) { this.unsubscribe(); this.unsubscribe = null; }
  }

  private async load(): Promise<void> {
    const sequence = ++this.sequence;
    this.loading = true;
    this.failed = false;
    try {
      const data = await this.services.statistics.query({ period: StatisticsPeriod.WEEK,
        anchorDate: this.services.clock.today(), category: null });
      if (this.active && sequence === this.sequence) { this.result = data; }
    } catch (_) {
      if (this.active && sequence === this.sequence) { this.result = null; this.failed = true; }
    }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }

  private grams(): number {
    return this.result === null ? 0 : (this.result as StatisticsResult).totalReductionGrams;
  }

  /** Category grams come from the same single query — no extra round trips. */
  private gramsFor(key: string): number {
    if (this.result === null) {
      return 0;
    }
    const items = (this.result as StatisticsResult).categories;
    for (let i = 0; i < items.length; i++) {
      if (items[i].key === key && items[i].reductionGrams > 0) {
        return items[i].reductionGrams;
      }
    }
    return 0;
  }

  private categoryTotal(): number {
    return this.gramsFor('travel') + this.gramsFor('energy_water') +
      this.gramsFor('recycling') + this.gramsFor('food');
  }

  private shortAmount(grams: number): string {
    if (grams >= 1000) {
      return `${(grams / 1000).toFixed(2)} kg`;
    }
    return `${Math.round(grams)} g`;
  }

  private dailyAverage(): string {
    const grams = Math.round(this.grams() / 7);
    if (Math.abs(grams) >= 1000) {
      return `${(grams / 1000).toFixed(2)} kg`;
    }
    return `${grams} g`;
  }

  @Builder
  private metric(value: string, label: string) {
    Column({ space: 3 }) {
      Text(value)
        .fontSize(17)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.cream)
      Text(label)
        .fontSize(9)
        .fontColor('#A9C4AC')
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private categoryRow(label: string, grams: number, total: number, color: string) {
    Row({ space: 9 }) {
      Column()
        .width(6)
        .height(6)
        .borderRadius(3)
        .backgroundColor(color)
      Text(label)
        .fontSize(11)
        .fontColor('#CBDDCB')
        .width(30)
      Row() {
        if (total > 0 && grams > 0) {
          Column()
            .height(5)
            .borderRadius(3)
            .backgroundColor(color)
            .width(`${Math.max(5, Math.round((grams / total) * 100))}%`)
        }
      }
      .layoutWeight(1)
      .height(5)
      .borderRadius(3)
      .backgroundColor('#1AFFFFFF')
      Text(this.shortAmount(grams))
        .fontSize(10)
        .fontColor('#C7DAC8')
        .width(54)
        .textAlign(TextAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  build() {
    Stack() {
      Circle()
        .width(260)
        .height(260)
        .fill('#00000000')
        .stroke('#D9F26E')
        .strokeWidth(1)
        .opacity(0.18)
        .position({ x: 210, y: -130 })
      Circle()
        .width(180)
        .height(180)
        .fill('#D9F26E')
        .opacity(0.06)
        .position({ x: 255, y: 30 })
      Circle()
        .width(120)
        .height(120)
        .fill('#FFFFFF')
        .opacity(0.04)
        .position({ x: -40, y: 170 })

      Column({ space: 14 }) {
        Row() {
          Row({ space: 7 }) {
            Circle().width(6).height(6).fill(V.lime)
            Text('本周减排')
              .fontSize(12)
              .fontWeight(FontWeight.Medium)
              .fontColor('#CBDDCB')
          }
          Blank()
          Text('近 7 天 · 本地账本')
            .fontSize(9)
            .letterSpacing(0.4)
            .fontColor('#9EB9A2')
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor('#10FFFFFF')
            .borderRadius(10)
        }
        .width('100%')

        if (this.loading) {
          Text('正在整理本周账页…')
            .fontSize(20)
            .fontColor(V.cream)
            .width('100%')
        } else if (this.failed || this.result === null) {
          Row({ space: 12 }) {
            Text('暂时读不到本周数据')
              .fontSize(18)
              .fontColor(V.cream)
              .layoutWeight(1)
            Button('重试', { type: ButtonType.Normal })
              .fontSize(12)
              .fontColor(V.forest)
              .backgroundColor(V.lime)
              .height(34)
              .borderRadius(17)
              .onClick(() => { this.load(); })
          }
          .width('100%')
        } else {
          Column({ space: 4 }) {
            AnimatedReduction({
              grams: this.grams(),
              valueSize: 52,
              unitSize: 15,
              color: '#FCFAEE',
              accent: '#BBD6B8',
              idValue: 'overview-week-total'
            })
            Text('已保存记录的估算净值')
              .fontSize(10)
              .fontColor('#9EB9A2')
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')

          Row() {
            this.metric(`${(this.result as StatisticsResult).recordCount}`, '次行动')
            Column().width(1).height(26).backgroundColor('#1AFFFFFF').margin({ left: 18, right: 18 })
            this.metric(this.dailyAverage(), '近 7 日日均')
            Blank()
            Text('参考估算')
              .fontSize(9)
              .fontColor('#9EB9A2')
          }
          .width('100%')
          .alignItems(VerticalAlign.Center)

          if (this.categoryTotal() > 0) {
            Column({ space: 7 }) {
              Row() {
                Text('本周构成')
                  .fontSize(9)
                  .fontWeight(FontWeight.Bold)
                  .letterSpacing(1)
                  .fontColor('#8FA893')
                Blank()
                Text('查看统计 ›')
                  .fontSize(9)
                  .fontColor('#C7DAC8')
                  .onClick(() => { this.onStatistics(); })
              }
              .width('100%')
              .alignItems(VerticalAlign.Center)
              this.categoryRow('出行', this.gramsFor('travel'), this.categoryTotal(), '#7FB4E8')
              this.categoryRow('节能', this.gramsFor('energy_water'), this.categoryTotal(), '#E8B961')
              this.categoryRow('光盘', this.gramsFor('food'), this.categoryTotal(), '#E58E6B')
              this.categoryRow('回收', this.gramsFor('recycling'), this.categoryTotal(), '#6FCBA8')
            }
            .width('100%')
            .margin({ top: 2 })
          }
        }

        Row({ space: 10 }) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 8 }) {
              Text('＋')
                .fontSize(19)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.forest)
              Text('记录今天的行动')
                .fontSize(14)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.forest)
            }
            .width('100%')
            .height(48)
            .justifyContent(FlexAlign.Center)
          }
          .id('overview-record')
          .width('100%')
          .height(48)
          .backgroundColor(V.lime)
          .borderRadius(24)
          .clickEffect({ level: ClickEffectLevel.MIDDLE })
          .shadow({ radius: 18, color: '#44D9F26E', offsetX: 0, offsetY: 6 })
          .onClick(() => { this.onRecord(); })
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 22, right: 22, top: 20, bottom: 20 })
    }
    .width('100%')
    .borderRadius(28)
    .clip(true)
    .linearGradient({
      angle: 132,
      colors: [['#0C3527', 0.0], ['#134433', 0.5], ['#245E45', 1.0]]
    })
    .shadow({ radius: 28, color: '#4D0E3526', offsetX: 0, offsetY: 14 })
  }
}
