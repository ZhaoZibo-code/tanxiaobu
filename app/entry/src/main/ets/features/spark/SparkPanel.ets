import { AppComposition } from '../../common/composition/AppComposition';
import { Unsubscribe } from '../../common/contracts/Common';
import { RecordPage } from '../../common/contracts/Records';
import { AppServices } from '../../common/contracts/Services';
import { toAppError } from '../../common/errors/AppError';
import { addDays, startOfWeek } from '../../common/utils/Dates';
import { V } from '../ui/VisualKit';

/** One cell of the check-in calendar. */
interface SparkCell {
  date: string;
  lit: boolean;
  future: boolean;
  today: boolean;
}

/** How far back the streak / calendar scans. Bounds the query and keeps the walk cheap. */
const WINDOW_DAYS: number = 120;
/** Calendar shows five weeks including the current one. */
const CALENDAR_WEEKS: number = 5;
const MILESTONES: number[] = [3, 7, 14, 30, 100];
const WEEK_LABELS: string[] = ['一', '二', '三', '四', '五', '六', '日'];
const CELL_SIZE: number = 30;
const CELL_GAP: number = 6;

/**
 * 行动火种 v2: one flame, the running streak, a five-week check-in calendar and
 * milestone badges. Still driven only by saved records — a day lights up when at
 * least one positive-reduction record exists, so the streak can never be faked by
 * tapping a check-in button.
 */
@Component
export struct SparkPanel {
  onRecord: () => void = () => {};
  @State private weeks: SparkCell[][] = [];
  @State private streak: number = 0;
  @State private best: number = 0;
  @State private litTotal: number = 0;
  @State private todayLit: boolean = false;
  @State private expanded: boolean = false;
  @State private loading: boolean = true;
  @State private error: string = '';
  private services: AppServices = AppComposition.getServices();
  private unsubscribe: Unsubscribe | null = null;
  private active: boolean = false;
  private sequence: number = 0;

  aboutToAppear(): void {
    this.active = true;
    this.unsubscribe = this.services.changes.subscribe(() => { this.load(); });
    this.load();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.sequence += 1;
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  private async load(): Promise<void> {
    const sequence = ++this.sequence;
    this.loading = true;
    this.error = '';
    try {
      const today = this.services.clock.today();
      const start = addDays(today, -(WINDOW_DAYS - 1));
      const end = addDays(today, 1);
      const litDates: string[] = [];
      let offset = 0;
      let total = 0;
      do {
        const page: RecordPage = await this.services.records.list({
          startDateInclusive: start, endDateExclusive: end, category: null, keyword: null,
          offset: offset, limit: 100
        });
        for (const record of page.items) {
          if (record.reductionGrams > 0 && litDates.indexOf(record.businessDate) < 0) {
            litDates.push(record.businessDate);
          }
        }
        total = page.total;
        if (page.items.length === 0 && offset < total) {
          throw new Error('记录列表读取不完整，请重试。');
        }
        offset += page.items.length;
      } while (offset < total);

      const streak = this.streakFrom(today, litDates);
      const best = this.bestFrom(start, today, litDates);
      const gridStart = addDays(startOfWeek(today), -(CALENDAR_WEEKS - 1) * 7);
      const weeks: SparkCell[][] = [];
      for (let w = 0; w < CALENDAR_WEEKS; w++) {
        const row: SparkCell[] = [];
        for (let d = 0; d < 7; d++) {
          const date = addDays(gridStart, w * 7 + d);
          row.push({
            date: date,
            lit: litDates.indexOf(date) >= 0,
            future: date > today,
            today: date === today
          });
        }
        weeks.push(row);
      }
      if (this.active && sequence === this.sequence) {
        this.weeks = weeks;
        this.streak = streak;
        this.best = best;
        this.litTotal = litDates.length;
        this.todayLit = litDates.indexOf(today) >= 0;
      }
    } catch (error) {
      if (this.active && sequence === this.sequence) {
        this.error = toAppError(error as Object).message;
      }
    }
    if (this.active && sequence === this.sequence) {
      this.loading = false;
    }
  }

  /** Today counts if lit; otherwise the streak is still alive until the day ends. */
  private streakFrom(today: string, litDates: string[]): number {
    let cursor = litDates.indexOf(today) >= 0 ? today : addDays(today, -1);
    let count = 0;
    while (litDates.indexOf(cursor) >= 0) {
      count += 1;
      cursor = addDays(cursor, -1);
    }
    return count;
  }

  private bestFrom(start: string, today: string, litDates: string[]): number {
    let best = 0;
    let run = 0;
    let cursor = start;
    while (cursor <= today) {
      if (litDates.indexOf(cursor) >= 0) {
        run += 1;
        if (run > best) {
          best = run;
        }
      } else {
        run = 0;
      }
      cursor = addDays(cursor, 1);
    }
    return best;
  }

  private statusText(): string {
    if (this.todayLit) {
      return this.streak === 1 ? '第 1 天，从今天开始' : `连续 ${this.streak} 天，今天已点亮`;
    }
    if (this.streak > 0) {
      return `连续 ${this.streak} 天，今天还没记录`;
    }
    return '今天记录一次，火花就会点亮';
  }

  /** The streak is still alive while today has not ended, so never claim it broke. */
  private heroLabel(): string {
    if (this.todayLit) {
      return '连续点亮';
    }
    return this.streak > 0 ? '连续天数' : '尚未开始';
  }

  @Builder
  private hero() {
    Row({ space: 14 }) {
      Stack() {
        Column()
          .width(78)
          .height(78)
          .borderRadius(39)
          .linearGradient({ angle: 160, colors: [['#FDF1D4', 0.0], ['#FAE0AE', 1.0]] })
          .shadow({ radius: 20, color: '#2EE8A94A', offsetX: 0, offsetY: 7 })
        Image($r('app.media.spark_flame'))
          .width(32)
          .height(40)
      }
      .width(78)
      .height(78)

      Column({ space: 3 }) {
        Row({ space: 5 }) {
          Text(`${this.streak}`)
            .fontSize(38)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.streak > 0 ? V.ink : V.sage)
            .letterSpacing(-1.5)
          Text('天')
            .fontSize(13)
            .fontColor(V.muted)
            .margin({ top: 13 })
        }
        .alignItems(VerticalAlign.Top)

        Text(this.heroLabel())
          .fontSize(11)
          .fontColor(V.muted)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Column({ space: 2 }) {
        Text('最长')
          .fontSize(9)
          .fontColor(V.sage)
        Text(`${this.best} 天`)
          .fontSize(13)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
      }
      .alignItems(HorizontalAlign.End)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private statusRow() {
    Row({ space: 10 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(this.todayLit ? '#E9A23B' : V.line)
      Text(this.statusText())
        .fontSize(11)
        .fontColor(this.todayLit ? V.text : V.muted)
        .layoutWeight(1)
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
      if (!this.todayLit) {
        Text('去记录 ›')
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
          .onClick(() => { this.onRecord(); })
      }
      Text(this.expanded ? '收起' : '打卡日历')
        .fontSize(11)
        .fontColor(V.moss)
        .padding({ left: 9, right: 9, top: 5, bottom: 5 })
        .backgroundColor('#F1F4E9')
        .borderRadius(11)
        .onClick(() => { this.expanded = !this.expanded; })
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
  }

  @Builder
  private calendarGrid() {
    Column({ space: CELL_GAP }) {
      Row({ space: CELL_GAP }) {
        ForEach(WEEK_LABELS, (label: string) => {
          Text(label)
            .fontSize(9)
            .fontColor(V.sage)
            .width(CELL_SIZE)
            .textAlign(TextAlign.Center)
        }, (label: string) => label)
      }

      ForEach(this.weeks, (week: SparkCell[]) => {
        Row({ space: CELL_GAP }) {
          ForEach(week, (cell: SparkCell) => {
            Column()
              .width(CELL_SIZE)
              .height(CELL_SIZE)
              .borderRadius(9)
              .backgroundColor(cell.future ? '#F7F3E5' : (cell.lit ? '#E9A23B' : '#EDE8D8'))
              .border({
                width: cell.today ? 1.5 : 0,
                color: cell.today ? V.forest : '#00000000'
              })
              .opacity(cell.future ? 0.5 : 1)
          }, (cell: SparkCell) => cell.date)
        }
      }, (week: SparkCell[]) => week[0].date)
    }
    .width(CELL_SIZE * 7 + CELL_GAP * 6)
  }

  @Builder
  private milestoneChip(days: number, unlocked: boolean) {
    Row({ space: 5 }) {
      Circle()
        .width(6)
        .height(6)
        .fill(unlocked ? V.forest : '#00000000')
        .stroke(unlocked ? V.forest : V.sage)
        .strokeWidth(1)
      Text(`${days}`)
        .fontSize(12)
        .fontWeight(FontWeight.Bold)
        .fontColor(unlocked ? V.forest : V.sage)
      Text('天')
        .fontSize(9)
        .fontColor(unlocked ? V.moss : V.sage)
    }
    .layoutWeight(1)
    .justifyContent(FlexAlign.Center)
    .padding({ top: 6, bottom: 6 })
    .backgroundColor(unlocked ? V.limeSoft : '#00000000')
    .border({ width: 1, color: unlocked ? '#DCE8B4' : V.line })
    .borderRadius(11)
  }

  @Builder
  private expandedBlock() {
    Column({ space: 12 }) {
      Row() {
        Blank()
        this.calendarGrid()
        Blank()
      }
      .width('100%')

      Row() {
        Text('里程碑')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontColor(V.moss)
        Blank()
        Text(`近 ${WINDOW_DAYS} 天点亮 ${this.litTotal} 天`)
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')

      Row({ space: 6 }) {
        ForEach(MILESTONES, (days: number) => {
          this.milestoneChip(days, this.streak >= days)
        }, (days: number) => `${days}`)
      }
      .width('100%')
    }
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(18).height(18).color(V.pine)
          Text('正在读取行动火种…')
            .fontSize(12)
            .fontColor(V.text)
        }
        .width('100%')
      } else if (this.error.length > 0) {
        Column({ space: 8 }) {
          Text(this.error)
            .fontSize(12)
            .fontColor(V.error)
            .width('100%')
          Text('重新读取')
            .fontSize(12)
            .fontColor(V.pine)
            .padding({ left: 12, right: 12, top: 6, bottom: 6 })
            .backgroundColor(V.mint)
            .borderRadius(14)
            .onClick(() => { this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      } else {
        this.hero()
        this.statusRow()
        if (this.expanded) {
          this.expandedBlock()
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 18, right: 18, top: 18, bottom: 16 })
    .backgroundColor('#FDFBF2')
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(26)
    .shadow({ radius: 18, color: '#12173B2A', offsetX: 0, offsetY: 7 })
  }
}
