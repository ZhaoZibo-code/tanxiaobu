import picker from '@ohos.file.picker';
import common from '@ohos.app.ability.common';
import { AppComposition } from '../../common/composition/AppComposition';
import { QuantityUnit, StatisticsPeriod } from '../../common/contracts/Common';
import { CalculationInput } from '../../common/contracts/Calculation';
import { BehaviorRecord, RecordPage } from '../../common/contracts/Records';
import { AppServices } from '../../common/contracts/Services';
import { ErrorCode, toAppError } from '../../common/errors/AppError';
import { addDays, dateRange } from '../../common/utils/Dates';
import { V } from '../ui/VisualKit';

interface ExportPeriod { label: string; value: StatisticsPeriod; }
const EXPORT_PERIODS: ExportPeriod[] = [
  { label: '日', value: StatisticsPeriod.DAY }, { label: '周', value: StatisticsPeriod.WEEK },
  { label: '月', value: StatisticsPeriod.MONTH }, { label: '年', value: StatisticsPeriod.YEAR }
];

/** A single scripted record used to populate a demo ledger. */
interface DemoEntry { ruleId: string; quantity: number; unit: QuantityUnit; daysAgo: number; note: string; }
/** Spread over ~7 weeks with gaps, so charts, heat map and streaks all have shape. */
const DEMO_DAYS: number[] = [0, 1, 2, 3, 4, 5, 7, 9, 11, 13, 16, 18, 21, 24, 27, 31, 35, 40, 46, 52];
const DEMO_TAG: string = '演示数据';

@Component
export struct DataTransferPanel {
  @State private period: StatisticsPeriod = StatisticsPeriod.MONTH;
  @State private anchor: string = '';
  @State private busy: boolean = false;
  @State private message: string = '';
  @State private error: string = '';
  @State private hasInspection: boolean = false;
  @State private inspectionSummary: string = '';
  private backupDigest: string = '';
  @State private confirmRestore: boolean = false;
  private backupUri: string = '';
  private restoreRequestId: string = '';
  private services: AppServices = AppComposition.getServices();
  private active: boolean = false;

  aboutToAppear(): void { this.active = true; this.anchor = this.services.clock.today(); }
  aboutToDisappear(): void { this.active = false; }

  private step(direction: number): void {
    const range = dateRange(this.period, this.anchor);
    this.anchor = direction < 0 ? addDays(range.startDateInclusive, -1) : range.endDateExclusive;
  }

  private async exportFile(backup: boolean): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.message = ''; this.error = '';
    try {
      if (backup) { await this.services.backup.exportBackup(); }
      else { await this.services.backup.exportCsv({ period: this.period, anchorDate: this.anchor, category: null }); }
      if (this.active) { this.message = '已保存到选择的位置。'; }
    } catch (error) {
      if (this.active) { this.error = toAppError(error as Object).message; }
    }
    this.busy = false;
  }

  private async chooseBackup(): Promise<void> {
    if (this.busy) { return; }
    this.busy = true; this.error = ''; this.message = ''; this.hasInspection = false;
    this.confirmRestore = false; this.backupUri = ''; this.restoreRequestId = '';
    try {
      const options = new picker.DocumentSelectOptions();
      options.maxSelectNumber = 1;
      const uris = await new picker.DocumentViewPicker(getContext(this) as common.UIAbilityContext).select(options);
      if (uris.length > 0) {
        const result = await this.services.backup.inspectBackup(uris[0]);
        if (this.active) {
          this.backupUri = uris[0]; this.backupDigest = result.contentDigest;
          this.inspectionSummary = `备份包含 ${result.recordCount} 条记录、${result.ledgerEntryCount} 条积分流水、${result.redemptionCount} 项兑换。`;
          this.hasInspection = true;
        }
      }
    } catch (error) { if (this.active) { this.error = toAppError(error as Object).message; } }
    this.busy = false;
  }

  private async restore(): Promise<void> {
    if (this.busy || !this.hasInspection || this.backupUri.length === 0) { return; }
    if (this.restoreRequestId.length === 0) { this.restoreRequestId = this.services.ids.newId(); }
    this.busy = true; this.error = ''; this.message = '';
    try {
      const result = await this.services.backup.restoreBackup(this.backupUri,
        this.backupDigest, this.restoreRequestId);
      if (this.active) {
        this.hasInspection = false; this.backupUri = ''; this.confirmRestore = false; this.restoreRequestId = '';
        this.message = `已恢复 ${result.recordCount} 条记录，积分余额 ${result.finalPointsBalance}。`;
      }
    } catch (error) {
      if (this.active) {
        const appError = toAppError(error as Object);
        this.error = appError.message;
        if (appError.code === ErrorCode.BACKUP_CHANGED) {
          this.hasInspection = false; this.backupUri = ''; this.confirmRestore = false; this.restoreRequestId = '';
        }
      }
    }
    this.busy = false;
  }

  @Builder
  private localHero() {
    Stack() {
      Circle()
        .width(160)
        .height(160)
        .fill('#00000000')
        .stroke('#D9F26E')
        .strokeWidth(1)
        .opacity(0.16)
        .position({ x: 250, y: -70 })
      Column({ space: 10 }) {
        Row({ space: 8 }) {
          Text('LOCAL FIRST')
            .fontSize(8)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.2)
            .fontColor(V.lime)
          Blank()
          Text('仅本机')
            .fontSize(8)
            .fontColor('#D8E6D5')
            .padding({ left: 8, right: 8, top: 3, bottom: 3 })
            .backgroundColor('#1AFFFFFF')
            .borderRadius(9)
        }
        .width('100%')
        Text('数据由你保管。')
          .fontSize(22)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.cream)
          .width('100%')
        Text('导出文件会保存到你选择的位置，应用不会上传你的记录。')
          .fontSize(10)
          .fontColor('#B9CFBB')
          .lineHeight(16)
          .width('100%')
        Row({ space: 16 }) {
          this.heroNote('本机', '记录存储')
          Column().width(1).height(22).backgroundColor('#1AFFFFFF')
          this.heroNote('CSV', '可按期导出')
          Column().width(1).height(22).backgroundColor('#1AFFFFFF')
          this.heroNote('备份', '可检查恢复')
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
      angle: 132,
      colors: [['#0C3527', 0.0], ['#154836', 0.55], ['#286147', 1.0]]
    })
    .shadow({ radius: 22, color: '#4D0E3526', offsetX: 0, offsetY: 10 })
  }

  @Builder
  private heroNote(value: string, label: string) {
    Column({ space: 2 }) {
      Text(value)
        .fontSize(11)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.lime)
      Text(label)
        .fontSize(8)
        .fontColor('#9EB9A2')
    }
    .alignItems(HorizontalAlign.Start)
  }

  @Builder
  private noticeBanner() {
    if (this.message.length > 0) {
      Text(this.message)
        .fontSize(11)
        .fontWeight(FontWeight.Medium)
        .fontColor(V.pine)
        .width('100%')
        .padding(12)
        .backgroundColor('#EAF2CE')
        .borderRadius(14)
    }
    if (this.error.length > 0) {
      Text(this.error)
        .fontSize(11)
        .fontColor(V.error)
        .width('100%')
        .padding(12)
        .backgroundColor('#FCF1EC')
        .borderRadius(14)
    }
  }

  @Builder
  private backupCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('本地备份')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('记录、积分、任务和奖励')
            .fontSize(9)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('01')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.sage)
      }
      .width('100%')

      Text('导出记录、积分、任务和奖励，也可以检查备份文件。')
        .fontSize(10)
        .fontColor(V.text)
        .lineHeight(16)
        .width('100%')

      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Text(this.busy ? '请稍候…' : '导出备份')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
          Text('↓').fontSize(14).fontColor(V.forest)
        }
        .height(42)
        .justifyContent(FlexAlign.Center)
      }
      .id('data-export-backup')
      .width('100%')
      .height(42)
      .backgroundColor(V.lime)
      .borderRadius(21)
      .clickEffect({ level: ClickEffectLevel.MIDDLE })
      .enabled(!this.busy)
      .onClick(() => { this.exportFile(true); })

      Button('选择备份并检查', { type: ButtonType.Normal })
        .id('data-inspect-backup')
        .fontSize(11)
        .fontColor(V.pine)
        .backgroundColor('#EAF0DF')
        .height(40)
        .width('100%')
        .borderRadius(20)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .enabled(!this.busy)
        .onClick(() => { this.chooseBackup(); })

      if (this.hasInspection) {
        Column({ space: 8 }) {
          Row({ space: 6 }) {
            Circle().width(6).height(6).fill(V.amber)
            Text('检查结果')
              .fontSize(10)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.amber)
          }
          Text(this.inspectionSummary)
            .fontSize(10)
            .fontColor(V.ink)
            .lineHeight(16)
            .width('100%')
          Text('恢复会替换本机全部记录、积分和任务。建议先导出当前备份。')
            .fontSize(9)
            .fontColor(V.coral)
            .lineHeight(15)
            .width('100%')
          if (!this.confirmRestore) {
            Button('准备恢复', { type: ButtonType.Normal })
              .id('data-restore-prepare')
              .fontSize(11)
              .fontColor(V.pine)
              .backgroundColor('#F5E7C6')
              .height(38)
              .width('100%')
              .borderRadius(19)
              .enabled(!this.busy)
              .onClick(() => { this.confirmRestore = true; })
          } else {
            Text('确认用这份备份替换本机全部数据？此操作无法撤销。')
              .fontSize(10)
              .fontColor(V.error)
              .lineHeight(16)
              .width('100%')
            Row({ space: 8 }) {
              Button('取消', { type: ButtonType.Normal })
                .id('data-restore-cancel')
                .fontSize(10)
                .fontColor(V.pine)
                .backgroundColor('#EAF0DF')
                .height(36)
                .borderRadius(18)
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => { this.confirmRestore = false; })
              Button(this.busy ? '恢复中…' : '确认替换', { type: ButtonType.Normal })
                .id('data-restore-confirm')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.white)
                .backgroundColor('#984C42')
                .height(36)
                .borderRadius(18)
                .layoutWeight(1)
                .enabled(!this.busy)
                .onClick(() => { this.restore(); })
            }
            .width('100%')
          }
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(12)
        .backgroundColor('#FBF4E2')
        .borderRadius(16)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(22)
    .shadow({ radius: 16, color: '#14173B2A', offsetX: 0, offsetY: 6 })
  }

  @Builder
  private csvCard() {
    Column({ space: 12 }) {
      Row() {
        Column({ space: 3 }) {
          Text('统计报表')
            .fontSize(17)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('CSV 明细与净减排汇总')
            .fontSize(9)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text('02')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.sage)
      }
      .width('100%')

      Row({ space: 3 }) {
        ForEach(EXPORT_PERIODS, (choice: ExportPeriod) => {
          Button(choice.label, { type: ButtonType.Normal })
            .fontSize(11)
            .fontWeight(this.period === choice.value ? FontWeight.Bold : FontWeight.Normal)
            .fontColor(this.period === choice.value ? V.forest : V.text)
            .backgroundColor(this.period === choice.value ? V.lime : '#00000000')
            .height(32)
            .borderRadius(16)
            .layoutWeight(1)
            .enabled(!this.busy)
            .onClick(() => { this.period = choice.value; })
        }, (choice: ExportPeriod) => choice.value)
      }
      .width('100%')
      .padding(4)
      .backgroundColor('#E9EEE0')
      .borderRadius(20)

      if (this.anchor.length > 0) {
        Row({ space: 6 }) {
          Button('‹', { type: ButtonType.Normal })
            .fontSize(18)
            .fontColor(V.pine)
            .backgroundColor('#F1F4E6')
            .height(34)
            .width(34)
            .borderRadius(17)
            .enabled(!this.busy)
            .onClick(() => { this.step(-1); })
          Text(`${dateRange(this.period, this.anchor).startDateInclusive} — ${addDays(dateRange(this.period, this.anchor).endDateExclusive, -1)}`)
            .fontSize(10)
            .fontColor(V.text)
            .textAlign(TextAlign.Center)
            .layoutWeight(1)
          Button('›', { type: ButtonType.Normal })
            .fontSize(18)
            .fontColor(V.pine)
            .backgroundColor('#F1F4E6')
            .height(34)
            .width(34)
            .borderRadius(17)
            .enabled(!this.busy)
            .onClick(() => { this.step(1); })
        }
        .width('100%')
      }

      Button({ type: ButtonType.Normal }) {
        Row({ space: 7 }) {
          Text(this.busy ? '请稍候…' : '导出 CSV')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.pine)
          Text('↗').fontSize(13).fontColor(V.pine)
        }
        .height(42)
        .justifyContent(FlexAlign.Center)
      }
      .id('data-export-csv')
      .width('100%')
      .height(42)
      .backgroundColor('#EAF0DF')
      .borderRadius(21)
      .clickEffect({ level: ClickEffectLevel.MIDDLE })
      .enabled(!this.busy)
      .onClick(() => { this.exportFile(false); })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(22)
  }

  /** Rounds to two decimals so generated quantities never carry float noise. */
  private round2(value: number): number {
    return Math.round(value * 100) / 100;
  }

  private demoPlan(): DemoEntry[] {
    const plan: DemoEntry[] = [];
    for (let i = 0; i < DEMO_DAYS.length; i++) {
      const daysAgo = DEMO_DAYS[i];
      const slot = i % 4;
      if (slot === 0) {
        plan.push({ ruleId: 'saved-electricity-cn-2023', quantity: this.round2(1.2 + (i % 3) * 0.6),
          unit: QuantityUnit.KWH, daysAgo: daysAgo, note: `${DEMO_TAG} · 空调少开` });
      } else if (slot === 1) {
        plan.push({ ruleId: 'green-travel-avoided-km-2010', quantity: this.round2(2 + (i % 5) * 1.5),
          unit: QuantityUnit.KM, daysAgo: daysAgo, note: `${DEMO_TAG} · 骑车上学` });
      } else if (slot === 2) {
        plan.push({ ruleId: 'avoided-pork-waste-handbook-2010', quantity: this.round2(0.1 + (i % 3) * 0.05),
          unit: QuantityUnit.KG, daysAgo: daysAgo, note: `${DEMO_TAG} · 光盘` });
      } else if (i === 10 || i === 15) {
        // A single resold phone is worth 25 kg, so keep it out of the current week
        // to avoid flattening every other day in the weekly chart.
        plan.push({ ruleId: 'completed-phone-reuse-ndrc-2022', quantity: 1,
          unit: QuantityUnit.PORTION, daysAgo: daysAgo, note: `${DEMO_TAG} · 旧物转卖` });
      } else {
        plan.push({ ruleId: 'saved-electricity-cn-2023', quantity: this.round2(0.8 + (i % 2) * 0.5),
          unit: QuantityUnit.KWH, daysAgo: daysAgo, note: `${DEMO_TAG} · 随手关灯` });
      }
    }
    return plan;
  }

  private async seedDemo(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.message = '';
    this.error = '';
    try {
      const today = this.services.clock.today();
      const plan = this.demoPlan();
      let written = 0;
      for (let i = 0; i < plan.length; i++) {
        const entry = plan[i];
        const input: CalculationInput = {
          ruleId: entry.ruleId,
          quantity: entry.quantity,
          unit: entry.unit,
          businessDate: addDays(today, -entry.daysAgo),
          note: entry.note,
          baselineConfirmed: true
        };
        await this.services.records.create(input, this.services.ids.newId());
        written += 1;
      }
      this.services.changes.notifyDataChanged();
      this.message = `已写入 ${written} 条${DEMO_TAG}，可在记录页查看或逐条撤销。`;
    } catch (error) {
      this.error = toAppError(error as Object).message;
    }
    this.busy = false;
  }

  private async clearDemo(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.message = '';
    this.error = '';
    try {
      const targets: BehaviorRecord[] = [];
      let offset = 0;
      let total = 0;
      do {
        const page: RecordPage = await this.services.records.list({
          startDateInclusive: null, endDateExclusive: null, category: null, keyword: null,
          offset: offset, limit: 100
        });
        for (let i = 0; i < page.items.length; i++) {
          if (page.items[i].note.indexOf(DEMO_TAG) >= 0) {
            targets.push(page.items[i]);
          }
        }
        total = page.total;
        offset += page.items.length;
      } while (offset < total && offset < 500);
      for (let i = 0; i < targets.length; i++) {
        await this.services.records.voidRecord(targets[i].id, this.services.ids.newId());
      }
      this.services.changes.notifyDataChanged();
      this.message = targets.length === 0 ? `没有找到${DEMO_TAG}。` : `已撤销 ${targets.length} 条${DEMO_TAG}。`;
    } catch (error) {
      this.error = toAppError(error as Object).message;
    }
    this.busy = false;
  }

  @Builder
  private demoCard() {
    Column({ space: 10 }) {
      Row() {
        Text('演示数据')
          .fontSize(15)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Text('演示用')
          .fontSize(9)
          .fontColor(V.forest)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(V.limeSoft)
          .borderRadius(8)
          .margin({ left: 8 })
        Blank()
        Text(`${DEMO_DAYS.length} 条 · 跨 7 周`)
          .fontSize(9)
          .fontColor(V.sage)
      }
      .width('100%')

      Text('覆盖四类行为、跨约七周的示例记录，让图表、火花和统计有内容可讲。全部通过正式接口保存，可一键撤销。')
        .fontSize(10)
        .fontColor(V.muted)
        .lineHeight(16)
        .width('100%')

      Row({ space: 8 }) {
        Button('填充演示数据', { type: ButtonType.Normal })
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
          .backgroundColor(V.lime)
          .height(38)
          .borderRadius(19)
          .padding({ left: 16, right: 16 })
          .enabled(!this.busy)
          .onClick(() => { this.seedDemo(); })
        Button('撤销演示数据', { type: ButtonType.Normal })
          .fontSize(12)
          .fontColor(V.pine)
          .backgroundColor('#00000000')
          .border({ width: 1, color: V.line })
          .height(38)
          .borderRadius(19)
          .padding({ left: 16, right: 16 })
          .enabled(!this.busy)
          .onClick(() => { this.clearDemo(); })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor('#FDFBF2')
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(22)
  }

  build() {
    Column({ space: 14 }) {
      this.localHero()
      this.noticeBanner()
      this.backupCard()
      this.csvCard()
      this.demoCard()
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
