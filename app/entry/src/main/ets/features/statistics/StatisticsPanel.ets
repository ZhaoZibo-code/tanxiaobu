import { AppComposition } from '../../common/composition/AppComposition';
import { Category, StatisticsPeriod, Unsubscribe } from '../../common/contracts/Common';
import { AppServices } from '../../common/contracts/Services';
import { StatisticsItem, StatisticsQuery, StatisticsResult } from '../../common/contracts/Statistics';
import { toAppError } from '../../common/errors/AppError';
import { addDays, dateRange } from '../../common/utils/Dates';
import { formatReduction } from '../../common/utils/Display';
import { PositivePieChart, TrendLineChart } from './StatisticsCharts';
import { AnimatedReduction, softSpring, V } from '../ui/VisualKit';

interface PeriodChoice { title: string; value: StatisticsPeriod; }
interface CategoryChoice { title: string; value: Category | null; }

const PERIODS: PeriodChoice[] = [
  { title: '日', value: StatisticsPeriod.DAY }, { title: '周', value: StatisticsPeriod.WEEK },
  { title: '月', value: StatisticsPeriod.MONTH }, { title: '年', value: StatisticsPeriod.YEAR }
];
const CATEGORIES: CategoryChoice[] = [
  { title: '全部', value: null }, { title: '节水节电', value: Category.ENERGY_WATER },
  { title: '出行', value: Category.TRAVEL }, { title: '光盘行动', value: Category.FOOD },
  { title: '回收', value: Category.RECYCLING }
];

@Component
export struct StatisticsPanel {
  @State private period: StatisticsPeriod = StatisticsPeriod.WEEK;
  @State private category: Category | null = null;
  @State private anchor: string = '';
  @State private result: StatisticsResult | null = null;
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private appeared: boolean = false;
  private services: AppServices = AppComposition.getServices();
  private unsubscribe: Unsubscribe | null = null;
  private active: boolean = false;
  private sequence: number = 0;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    this.anchor = this.services.clock.today();
    this.unsubscribe = this.services.changes.subscribe(() => { this.load(); });
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 80);
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
    const query: StatisticsQuery = { period: this.period, anchorDate: this.anchor, category: this.category };
    this.loading = true;
    this.error = '';
    try {
      const result = await this.services.statistics.query(query);
      if (this.active && sequence === this.sequence) { this.result = result; }
    } catch (error) {
      if (this.active && sequence === this.sequence) {
        this.result = null;
        this.error = toAppError(error as Object).message;
      }
    }
    if (this.active && sequence === this.sequence) {
      this.loading = false;
      this.appeared = true;
    }
  }

  private step(direction: number): void {
    const range = dateRange(this.period, this.anchor);
    this.anchor = direction < 0 ? addDays(range.startDateInclusive, -1) : range.endDateExclusive;
    this.load();
  }

  private resetToday(): void {
    this.anchor = this.services.clock.today();
    this.load();
  }

  private maxBucket(items: StatisticsItem[]): number {
    let maximum = 0;
    items.forEach((item: StatisticsItem) => { maximum = Math.max(maximum, Math.abs(item.reductionGrams)); });
    return maximum;
  }

  private barHeight(value: number, max: number, span: number): number {
    return max === 0 || value === 0 ? 0 : Math.max(3, span * Math.abs(value) / max);
  }

  private positiveTotal(items: StatisticsItem[]): number {
    let total = 0;
    items.forEach((item: StatisticsItem) => { total += item.positiveReductionGrams; });
    return total;
  }

  private activeCategories(): number {
    let count = 0;
    (this.result as StatisticsResult).categories.forEach((item: StatisticsItem) => {
      if (item.recordCount > 0) { count += 1; }
    });
    return count;
  }

  private compactReduction(grams: number): string {
    if (Math.abs(grams) >= 1000) {
      return `${(grams / 1000).toFixed(1)} kg`;
    }
    return `${grams} g`;
  }

  private categoryColor(key: string): string {
    switch (key) {
      case Category.ENERGY_WATER: return '#2E6A4F';
      case Category.TRAVEL: return '#D6A345';
      case Category.FOOD: return '#C47255';
      default: return '#78958A';
    }
  }

  @Builder
  private periodRail() {
    Row({ space: 4 }) {
      ForEach(PERIODS, (choice: PeriodChoice) => {
        Button(choice.title, { type: ButtonType.Normal })
          .id(`statistics-period-${choice.value}`)
          .fontSize(12)
          .fontWeight(this.period === choice.value ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.period === choice.value ? V.forest : V.text)
          .backgroundColor(this.period === choice.value ? V.lime : '#00000000')
          .height(36)
          .borderRadius(18)
          .layoutWeight(1)
          .clickEffect({ level: ClickEffectLevel.LIGHT })
          .onClick(() => {
            animateTo({ duration: 360, curve: softSpring() }, () => { this.period = choice.value; });
            this.load();
          })
      }, (choice: PeriodChoice) => choice.value)
    }
    .width('100%')
    .padding(4)
    .backgroundColor('#E9EEE0')
    .borderRadius(22)
  }

  @Builder
  private dateRail() {
    Row({ space: 8 }) {
      Button('‹', { type: ButtonType.Normal })
        .id('statistics-previous')
        .fontSize(20)
        .fontColor(V.pine)
        .backgroundColor('#FDFBF2')
        .border({ width: 1, color: '#E9EEDF' })
        .width(38)
        .height(38)
        .borderRadius(19)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .onClick(() => { this.step(-1); })
      Column({ space: 2 }) {
        Text('统计区间')
          .fontSize(8)
          .letterSpacing(0.8)
          .fontColor(V.muted)
        Text(this.result !== null && !this.loading ?
          `${(this.result as StatisticsResult).startDateInclusive}  —  ${addDays((this.result as StatisticsResult).endDateExclusive, -1)}` :
          '正在读取…')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.ink)
          .maxLines(1)
      }
      .alignItems(HorizontalAlign.Center)
      .layoutWeight(1)
      Button(this.anchor === this.services.clock.today() ? '今天' : '回到今天', { type: ButtonType.Normal })
        .fontSize(9)
        .fontColor(V.pine)
        .backgroundColor('#EAF0DF')
        .height(26)
        .borderRadius(13)
        .padding({ left: 9, right: 9 })
        .onClick(() => { this.resetToday(); })
      Button('›', { type: ButtonType.Normal })
        .id('statistics-next')
        .fontSize(20)
        .fontColor(V.pine)
        .backgroundColor('#FDFBF2')
        .border({ width: 1, color: '#E9EEDF' })
        .width(38)
        .height(38)
        .borderRadius(19)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .onClick(() => { this.step(1); })
    }
    .width('100%')
    .padding({ left: 8, right: 6, top: 6, bottom: 6 })
    .backgroundColor('#FDFBF2')
    .borderRadius(22)
    .shadow({ radius: 14, color: '#14173B2A', offsetX: 0, offsetY: 6 })
  }

  @Builder
  private categoryRail() {
    Scroll() {
      Row({ space: 7 }) {
        ForEach(CATEGORIES, (choice: CategoryChoice) => {
          Button(choice.title, { type: ButtonType.Normal })
            .fontSize(11)
            .fontWeight(this.category === choice.value ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.category === choice.value ? V.cream : V.text)
            .backgroundColor(this.category === choice.value ? V.pine : '#ECF0E2')
            .height(32)
            .borderRadius(16)
            .padding({ left: 13, right: 13 })
            .clickEffect({ level: ClickEffectLevel.LIGHT })
            .onClick(() => {
              animateTo({ duration: 260, curve: Curve.EaseOut }, () => { this.category = choice.value; });
              this.load();
            })
        }, (choice: CategoryChoice) => choice.title)
      }
    }
    .scrollable(ScrollDirection.Horizontal)
    .scrollBar(BarState.Off)
    .width('100%')
  }

  @Builder
  private summaryHero() {
    Stack() {
      Circle()
        .width(220)
        .height(220)
        .fill('#00000000')
        .stroke('#D9F26E')
        .strokeWidth(1)
        .opacity(0.16)
        .position({ x: 230, y: -100 })
      Circle()
        .width(130)
        .height(130)
        .fill(V.lime)
        .opacity(0.06)
        .position({ x: 260, y: 50 })
      Column({ space: 10 }) {
        Row() {
          Row({ space: 6 }) {
            Circle().width(6).height(6).fill(V.lime)
            Text('净减排')
              .fontSize(11)
              .fontColor('#CBDDCB')
          }
          Blank()
          Text(`${(this.result as StatisticsResult).recordCount} 次行动`)
            .fontSize(9)
            .fontColor('#D8E6D5')
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor('#1AFFFFFF')
            .borderRadius(10)
        }
        .width('100%')

        AnimatedReduction({
          grams: (this.result as StatisticsResult).totalReductionGrams,
          valueSize: 42,
          unitSize: 12,
          color: '#FCFAEE',
          accent: '#B9D3B9',
          idValue: 'statistics-total'
        })

        Row({ space: 14 }) {
          Column({ space: 2 }) {
            Text('正向减排')
              .fontSize(8)
              .fontColor('#9EB9A2')
            Text(formatReduction(this.positiveTotal((this.result as StatisticsResult).categories)))
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(V.cream)
          }
          .alignItems(HorizontalAlign.Start)
          Column().width(1).height(22).backgroundColor('#1AFFFFFF')
          Column({ space: 2 }) {
            Text('汇总口径')
              .fontSize(8)
              .fontColor('#9EB9A2')
            Text('已保存记录 · 参考估算')
              .fontSize(10)
              .fontColor('#C6D9C2')
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(20)
    }
    .width('100%')
    .borderRadius(26)
    .clip(true)
    .linearGradient({
      angle: 135,
      colors: [['#0C3527', 0.0], ['#154836', 0.55], ['#286147', 1.0]]
    })
    .shadow({ radius: 24, color: '#4D0E3526', offsetX: 0, offsetY: 12 })
  }

  @Builder
  private barChart() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 2 }) {
          Text('减排变化')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('净值 · 克')
            .fontSize(9)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Row({ space: 10 }) {
          Row({ space: 4 }) {
            Circle().width(6).height(6).fill(V.pine)
            Text('正向').fontSize(8).fontColor(V.muted)
          }
          Row({ space: 4 }) {
            Circle().width(6).height(6).fill(V.coral)
            Text('增加').fontSize(8).fontColor(V.muted)
          }
        }
      }
      .width('100%')

      Stack() {
        Column({ space: 30 }) {
          Column().width('100%').height(1).backgroundColor('#EDF1E4')
          Column().width('100%').height(1).backgroundColor('#EDF1E4')
        }
        .width('100%')
        .height(62)
        .justifyContent(FlexAlign.SpaceBetween)

        Column()
          .width('100%')
          .height(1)
          .backgroundColor('#D7E2D3')
          .position({ x: 0, y: 63 })

        Row({ space: 3 }) {
          ForEach((this.result as StatisticsResult).buckets, (item: StatisticsItem, index: number) => {
            Column() {
              Column() {
                Blank()
                Column()
                  .width('62%')
                  .height(this.appeared && item.reductionGrams > 0 ?
                    this.barHeight(item.reductionGrams, this.maxBucket((this.result as StatisticsResult).buckets), 58) : 0)
                  .borderRadius(4)
                  .linearGradient({ angle: 180, colors: [['#D9F26E', 0.0], ['#4F8A65', 1.0]] })
                  .animation({ duration: 520, delay: 80 + Math.min(index, 12) * 25, curve: softSpring() })
              }
              .height(63)
              .width('100%')
              .justifyContent(FlexAlign.End)
              Column() {
                Column()
                  .width('62%')
                  .height(this.appeared && item.reductionGrams < 0 ?
                    this.barHeight(item.reductionGrams, this.maxBucket((this.result as StatisticsResult).buckets), 18) : 0)
                  .borderRadius(4)
                  .backgroundColor(V.coral)
                  .animation({ duration: 520, delay: 80 + Math.min(index, 12) * 25, curve: softSpring() })
                Blank()
              }
              .height(24)
              .width('100%')
            }
            .layoutWeight(1)
            .height(87)
          }, (item: StatisticsItem) => item.key)
        }
        .width('100%')
        .height(87)
      }
      .width('100%')
      .height(87)

      Row() {
        Text((this.result as StatisticsResult).buckets[0].label)
          .fontSize(9)
          .fontColor(V.muted)
        Blank()
        Text((this.result as StatisticsResult).buckets[(this.result as StatisticsResult).buckets.length - 1].label)
          .fontSize(9)
          .fontColor(V.muted)
      }
      .width('100%')
      Text('无记录日期显示为空，橙色表示净值增加。')
        .fontSize(9)
        .fontColor(V.sage)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private trendCard() {
    Column({ space: 10 }) {
      Row() {
        Column({ space: 2 }) {
          Text('趋势线')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('净值 · 克')
            .fontSize(9)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('无记录按零')
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')
      TrendLineChart({ items: (this.result as StatisticsResult).buckets })
      Row() {
        Text((this.result as StatisticsResult).buckets[0].label)
          .fontSize(9)
          .fontColor(V.muted)
        Blank()
        Text((this.result as StatisticsResult).buckets[(this.result as StatisticsResult).buckets.length - 1].label)
          .fontSize(9)
          .fontColor(V.muted)
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ top: 4, bottom: 4 })
  }

  @Builder
  private compositionCard() {
    Column({ space: 14 }) {
      Row() {
        Column({ space: 2 }) {
          Text('行动构成')
            .fontSize(16)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('按正向减排量计算占比')
            .fontSize(9)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`${this.activeCategories()} 类有记录`)
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')

      if (this.positiveTotal((this.result as StatisticsResult).categories) > 0) {
        Row({ space: 18 }) {
          Stack() {
            PositivePieChart({ items: (this.result as StatisticsResult).categories })
            Column({ space: 1 }) {
              Text('正向总量')
                .fontSize(8)
                .fontColor(V.muted)
              Text(this.compactReduction(this.positiveTotal((this.result as StatisticsResult).categories)))
                .fontSize(15)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.ink)
            }
          }
          .width(132)
          .height(132)

          Column({ space: 9 }) {
            ForEach((this.result as StatisticsResult).categories, (item: StatisticsItem) => {
              if (item.recordCount > 0) {
                Row({ space: 8 }) {
                  Circle().width(7).height(7).fill(this.categoryColor(item.key))
                  Text(item.label)
                    .fontSize(10)
                    .fontColor(V.text)
                    .layoutWeight(1)
                  Text(`${Math.round(this.positiveTotal((this.result as StatisticsResult).categories) === 0 ? 0 :
                    item.positiveReductionGrams * 100 / this.positiveTotal((this.result as StatisticsResult).categories))}%`)
                    .fontSize(11)
                    .fontWeight(FontWeight.Bold)
                    .fontColor(V.ink)
                }
                .width('100%')
              }
            }, (item: StatisticsItem) => item.key)
          }
          .layoutWeight(1)
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
      } else {
        Text('本期没有正向减排量')
          .fontSize(11)
          .fontColor(V.muted)
          .width('100%')
      }

      ForEach((this.result as StatisticsResult).categories, (item: StatisticsItem) => {
        if (item.recordCount > 0) {
          Column({ space: 6 }) {
            Row() {
              Text(item.label)
                .fontSize(11)
                .fontColor(V.ink)
              Blank()
              Text(`净值 ${formatReduction(item.reductionGrams)}`)
                .fontSize(10)
                .fontColor(V.muted)
            }
            .width('100%')
            Row() {
              Column()
                .height(5)
                .width(`${this.positiveTotal((this.result as StatisticsResult).categories) === 0 ? 0 :
                  item.positiveReductionGrams * 100 / this.positiveTotal((this.result as StatisticsResult).categories)}%`)
                .backgroundColor(this.categoryColor(item.key))
                .borderRadius(3)
                .animation({ duration: 520, curve: softSpring() })
            }
            .width('100%')
            .height(5)
            .backgroundColor('#E9EFE2')
            .borderRadius(3)
          }
          .width('100%')
        }
      }, (item: StatisticsItem) => item.key)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(18)
    .backgroundColor('#FDFBF2')
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(24)
    .shadow({ radius: 16, color: '#14173B2A', offsetX: 0, offsetY: 6 })
  }

  @Builder
  private emptyCard() {
    Column({ space: 10 }) {
      Stack() {
        Circle().width(64).height(64).fill(V.limeSoft)
        Text('0')
          .fontSize(24)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
      }
      .width(64)
      .height(64)
      Text('这段时间还没有记录')
        .fontSize(15)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.ink)
      Text('保存一项低碳行动后，这里会显示真实变化。')
        .fontSize(10)
        .fontColor(V.muted)
        .lineHeight(16)
        .textAlign(TextAlign.Center)
    }
    .alignItems(HorizontalAlign.Center)
    .width('100%')
    .padding(24)
    .backgroundColor('#FDFBF2')
    .borderRadius(24)
  }

  @Builder
  private resultContent() {
    Column({ space: 14 }) {
      this.summaryHero()
      if ((this.result as StatisticsResult).recordCount === 0) {
        this.emptyCard()
      } else {
        this.barChart()
        this.trendCard()
        this.compositionCard()
      }
    }
    .width('100%')
  }

  build() {
    Column({ space: 12 }) {
      this.periodRail()
      this.dateRail()
      this.categoryRail()
      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(20).height(20).color(V.pine)
          Text('正在整理本地记录…')
            .fontSize(11)
            .fontColor(V.text)
        }
        .width('100%')
        .padding(18)
        .backgroundColor('#FDFBF2')
        .borderRadius(20)
      } else if (this.error.length > 0) {
        Column({ space: 8 }) {
          Text(this.error)
            .fontSize(11)
            .fontColor(V.error)
            .width('100%')
          Button('重新读取', { type: ButtonType.Normal })
            .fontSize(11)
            .fontColor(V.pine)
            .backgroundColor(V.mint)
            .height(36)
            .borderRadius(18)
            .onClick(() => { this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FCF1EC')
        .borderRadius(18)
      } else if (this.result !== null) {
        this.resultContent()
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
