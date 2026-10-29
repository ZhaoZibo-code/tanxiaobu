import { CalculationInput, CalculationMode, CalculationPreview, CalculationRule, FactorDefinition } from '../../common/contracts/Calculation';
import { AppServices } from '../../common/contracts/Services';
import { AppComposition } from '../../common/composition/AppComposition';
import { AppError, errorTitle, toAppError } from '../../common/errors/AppError';
import { BehaviorRecord } from '../../common/contracts/Records';
import { Category, QuantityUnit } from '../../common/contracts/Common';
import { AnimatedReduction, softSpring, V } from '../ui/VisualKit';

const INK: string = V.ink;
const MUTED: string = V.text;
const PINE: string = V.pine;
const PAPER: string = V.paper;
const LINE: string = V.line;

interface HistoryCategory { label: string; value: Category | null; }
const HISTORY_CATEGORIES: HistoryCategory[] = [
  { label: '全部', value: null }, { label: '节水节电', value: Category.ENERGY_WATER },
  { label: '出行', value: Category.TRAVEL }, { label: '光盘行动', value: Category.FOOD },
  { label: '回收', value: Category.RECYCLING }
];

/** Units are shown in Chinese first, with the technical symbol as a hint. */function unitLabel(unit: QuantityUnit): string {
  switch (unit) {
    case QuantityUnit.KWH:
      return '度（kWh）';
    case QuantityUnit.LITRE:
      return '升（L）';
    case QuantityUnit.KG:
      return '千克（kg）';
    case QuantityUnit.KM:
      return '公里（km）';
    case QuantityUnit.PORTION:
      return '份';
    default:
      return `${unit}`;
  }
}

@Component
export struct CalculationPreviewPanel {
  onEdit: () => void = () => {};
  /** Lets the host scroll the composer so the input panel is revealed after picking a category. */
  onRuleSelected: () => void = () => {};
  @State private rules: CalculationRule[] = [];
  @State private selectedIndex: number = -1;
  @State private quantity: string = '';
  @State private note: string = '';
  @State private confirmed: boolean = false;
  @State private loading: boolean = true;
  @State private calculating: boolean = false;
  @State private error: string = '';
  @State private preview: CalculationPreview | null = null;
  @State private showDetails: boolean = false;
  @State private saving: boolean = false;
  @State private saveMessage: string = '';
  @State private history: BehaviorRecord[] = [];
  @State private historyError: string = '';
  @State private historyCategory: Category | null = null;
  @State private historyTotal: number = 0;
  @State private historyLoading: boolean = false;
  @State private editingRecord: BehaviorRecord | null = null;
  @State private voidConfirmId: string = '';
  @State private mutationMessage: string = '';
  @State private mutationError: string = '';
  @State private voidBusy: boolean = false;
  @State private appeared: boolean = false;
  private requestId: string = '';
  private entranceTimer: number = -1;
  private services: AppServices = AppComposition.getServices();
  private requestSequence: number = 0;
  private active: boolean = false;
  private historySequence: number = 0;
  private voidRequests: Map<string, string> = new Map<string, string>();

  aboutToAppear(): void {
    this.active = true;
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 60);
    this.loadRules();
    this.loadHistory();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.requestSequence += 1;
    this.historySequence += 1;
    if (this.entranceTimer !== -1) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
  }

  private async loadRules(): Promise<void> {
    const sequence = ++this.requestSequence;
    this.loading = true;
    this.calculating = false;
    this.error = '';
    this.preview = null;
    try {
      const rules = await this.services.calculation.listRules();
      if (!this.active || sequence !== this.requestSequence) {
        return;
      }
      this.rules = rules;
      this.selectedIndex = -1;
      this.confirmed = false;
    } catch (error) {
      if (!this.active || sequence !== this.requestSequence) {
        return;
      }
      const appError: AppError = toAppError(error as Object);
      this.error = `${errorTitle(appError)}：${appError.message}`;
    }
    if (this.active && sequence === this.requestSequence) {
      this.loading = false;
    }
  }

  private invalidatePreview(): void {
    this.requestSequence += 1;
    this.calculating = false;
    this.preview = null;
    this.showDetails = false;
    this.error = '';
    this.requestId = '';
    this.saveMessage = '';
  }

  private selectRule(index: number): void {
    this.invalidatePreview();
    this.selectedIndex = index;
    const rule = this.rules[index];
    this.quantity = rule.minQuantity === rule.maxQuantity ? `${rule.minQuantity}` : '';
    this.confirmed = false;
  }

  private requiresConfirmation(rule: CalculationRule): boolean {
    return rule.mode === CalculationMode.BASELINE_DIFFERENCE || rule.confirmationText.trim().length > 0;
  }

  private categoryTitle(category: Category): string {
    switch (category) {
      case Category.ENERGY_WATER: return '节约用电';
      case Category.TRAVEL: return '低碳出行';
      case Category.FOOD: return '光盘行动';
      case Category.RECYCLING: return '旧物再利用';
      default: return '低碳行动';
    }
  }

  private categoryIcon(category: Category): Resource {
    switch (category) {
      case Category.ENERGY_WATER: return $r('app.media.lucide_zap');
      case Category.TRAVEL: return $r('app.media.lucide_car_front');
      case Category.FOOD: return $r('app.media.lucide_utensils');
      case Category.RECYCLING: return $r('app.media.lucide_smartphone');
      default: return $r('app.media.lucide_leaf');
    }
  }

  private editRecord(record: BehaviorRecord): void {
    const index = this.rules.findIndex((rule: CalculationRule) => rule.id === record.ruleId);
    if (index < 0) { this.mutationError = '该记录对应的规则当前不可用，暂时无法更正。'; return; }
    this.invalidatePreview();
    this.editingRecord = record;
    this.selectedIndex = index;
    this.quantity = `${record.quantity}`;
    this.confirmed = false;
    this.voidConfirmId = '';
    this.mutationError = '';
    this.mutationMessage = '';
    this.onEdit();
  }

  private cancelEdit(): void {
    this.invalidatePreview();
    this.editingRecord = null;
    this.selectedIndex = -1;
    this.quantity = '';
    this.confirmed = false;
  }

  private async voidRecord(record: BehaviorRecord): Promise<void> {
    if (this.voidBusy) { return; }
    let requestId = this.voidRequests.get(record.id);
    if (requestId === undefined) { requestId = this.services.ids.newId(); this.voidRequests.set(record.id, requestId); }
    this.voidBusy = true; this.mutationError = ''; this.mutationMessage = '';
    try {
      await this.services.records.voidRecord(record.id, requestId);
      if (this.active) {
        if (this.editingRecord !== null && (this.editingRecord as BehaviorRecord).id === record.id) { this.cancelEdit(); }
        this.voidConfirmId = ''; this.mutationMessage = '已撤销该行动，相关积分已重新计算。';
        await this.loadHistory();
      }
    } catch (error) {
      if (this.active) { this.mutationError = toAppError(error as Object).message; }
    }
    this.voidBusy = false;
  }

  private async calculate(): Promise<void> {
    if (this.selectedIndex < 0 || this.selectedIndex >= this.rules.length) {
      this.error = '请先选择一项行动。';
      return;
    }
    const rule = this.rules[this.selectedIndex];
    const text = this.quantity.trim();
    if (text.length === 0 || !Number.isFinite(Number(text))) {
      this.error = '请输入有效的数量。';
      return;
    }
    if (this.requiresConfirmation(rule) && !this.confirmed) {
      this.error = '请阅读并确认这项行动的适用条件。';
      return;
    }
    const input: CalculationInput = {
      ruleId: rule.id,
      quantity: Number(text),
      unit: rule.inputUnit,
      businessDate: this.editingRecord === null ? this.services.clock.today() : (this.editingRecord as BehaviorRecord).businessDate,
      note: this.editingRecord === null ? this.note : (this.editingRecord as BehaviorRecord).note,
      baselineConfirmed: this.confirmed
    };
    const sequence = ++this.requestSequence;
    this.requestId = '';
    this.saveMessage = '';
    this.calculating = true;
    this.preview = null;
    this.error = '';
    try {
      const result = await this.services.calculation.preview(input);
      if (!this.active || sequence !== this.requestSequence) {
        return;
      }
      this.preview = result;
    } catch (error) {
      if (!this.active || sequence !== this.requestSequence) {
        return;
      }
      const appError: AppError = toAppError(error as Object);
      this.error = `${errorTitle(appError)}：${appError.message}`;
    }
    if (this.active && sequence === this.requestSequence) {
      this.calculating = false;
    }
  }

  private async loadHistory(append: boolean = false): Promise<void> {
    const sequence = ++this.historySequence;
    const offset = append ? this.history.length : 0;
    this.historyLoading = true;
    this.historyError = '';
    if (!append) { this.history = []; this.historyTotal = 0; }
    try {
      const page = await this.services.records.list({ startDateInclusive: null, endDateExclusive: null,
        category: this.historyCategory, keyword: null, offset: offset, limit: 20 });
      if (this.active && sequence === this.historySequence) {
        this.history = append ? this.history.concat(page.items) : page.items;
        this.historyTotal = page.total;
        this.historyError = '';
      }
    } catch (error) {
      if (this.active && sequence === this.historySequence) {
        this.historyError = toAppError(error as Object).message;
      }
    }
    if (this.active && sequence === this.historySequence) { this.historyLoading = false; }
  }

  private async savePreview(): Promise<void> {
    if (this.preview === null || this.saving) {
      return;
    }
    if (this.requestId.length === 0) {
      this.requestId = this.services.ids.newId();
    }
    this.saving = true;
    this.error = '';
    try {
      if (this.editingRecord === null) {
        await this.services.records.create(this.preview.input, this.requestId);
      } else {
        await this.services.records.update((this.editingRecord as BehaviorRecord).id, this.preview.input, this.requestId);
      }
      if (this.active) {
        this.saveMessage = this.editingRecord === null ? '已保存到本地账页。' : '更正已保存，相关积分已重新计算。';
        await this.loadHistory();
      }
    } catch (error) {
      if (this.active) {
        this.error = toAppError(error as Object).message;
      }
    } finally {
      this.saving = false;
    }
  }

  @Builder
  private stepRail() {
    Row({ space: 6 }) {
      Text('01  选择')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIndex < 0 ? V.forest : V.muted)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.selectedIndex < 0 ? V.lime : '#00000000')
        .borderRadius(11)
      Text('02  核算')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.selectedIndex >= 0 ? V.forest : V.muted)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.selectedIndex >= 0 && this.preview === null ? V.limeSoft : '#00000000')
        .borderRadius(11)
      Text('03  保存')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.preview !== null ? V.forest : V.muted)
        .padding({ left: 10, right: 10, top: 5, bottom: 5 })
        .backgroundColor(this.preview !== null ? V.limeSoft : '#00000000')
        .borderRadius(11)
    }
    .width('100%')
    .padding(4)
    .backgroundColor('#ECF1E0')
    .borderRadius(15)
  }

  private quantityText(value: number): string {
    if (Number.isInteger(value)) { return `${value}`; }
    return `${value}`;
  }

  private quickValues(rule: CalculationRule): number[] {
    if (rule.minQuantity === rule.maxQuantity) { return [rule.minQuantity]; }
    const middle = Math.round((rule.minQuantity + rule.maxQuantity) / 2 * 10) / 10;
    if (middle <= rule.minQuantity || middle >= rule.maxQuantity) {
      return [rule.minQuantity, rule.maxQuantity];
    }
    return [rule.minQuantity, middle, rule.maxQuantity];
  }

  /** Applies a parsed one-sentence record: pick the rule, then fill quantity and note. */
  private applyQuick(ruleId: string, quantity: string, note: string): void {
    for (let i = 0; i < this.rules.length; i++) {
      if (this.rules[i].id === ruleId) {
        this.selectRule(i);
        this.quantity = quantity;
        this.note = note;
        this.confirmed = false;
        this.invalidatePreview();
        return;
      }
    }
  }

  private recordAmount(grams: number): string {
    if (Math.abs(grams) >= 1000) {
      return `${(grams / 1000).toFixed(2)} kg`;
    }
    return `${grams} g`;
  }

  @Builder
  private ruleCard(rule: CalculationRule, index: number) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 9 }) {
        Row() {
          Stack() {
            Image(this.categoryIcon(rule.category))
              .width(20)
              .height(20)
          }
          .width(38)
          .height(38)
          .backgroundColor(this.selectedIndex === index ? V.limeSoft : '#EAF0DF')
          .borderRadius(13)

          Blank()
          Text(this.selectedIndex === index ? '✓' : '›')
            .fontSize(this.selectedIndex === index ? 15 : 19)
            .fontColor(this.selectedIndex === index ? V.lime : V.moss)
        }
        .width('100%')

        Column({ space: 3 }) {
          Text(this.categoryTitle(rule.category))
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.selectedIndex === index ? V.cream : V.ink)
            .width('100%')
          Text(rule.name)
            .fontSize(10)
            .fontColor(this.selectedIndex === index ? '#B9CFBB' : V.muted)
            .lineHeight(15)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding({ left: 13, right: 13, top: 12, bottom: 12 })
    }
    .id(`preview-rule-${rule.id}`)
    .width('48.5%')
    .height(118)
    .margin({ bottom: 10 })
    .backgroundColor(this.selectedIndex === index ? V.forest : V.paper)
    .border({ width: 1, color: this.selectedIndex === index ? V.forest : '#E9EEDF' })
    .borderRadius(20)
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .shadow(this.selectedIndex === index ? {
      radius: 18, color: '#33123424', offsetX: 0, offsetY: 8
    } : { radius: 0, color: '#00000000', offsetX: 0, offsetY: 0 })
    .enabled(!this.saving)
    .onClick(() => {
      if (this.selectedIndex === index) {
        this.invalidatePreview();
        this.selectedIndex = -1;
        this.confirmed = false;
      } else {
        this.selectRule(index);
        this.onRuleSelected();
      }
    })
  }

  @Builder
  private editBanner() {
    if (this.editingRecord !== null) {
      Row({ space: 12 }) {
        Stack() {
          Text('✎').fontSize(17).fontColor(V.forest)
        }
        .width(36)
        .height(36)
        .backgroundColor(V.limeSoft)
        .borderRadius(18)
        Column({ space: 3 }) {
          Text(`正在更正 ${(this.editingRecord as BehaviorRecord).businessDate} 的行动`)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
            .width('100%')
          Text('会按当前规则重新核算，并可能调整积分。')
            .fontSize(10)
            .fontColor(V.muted)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Button('取消', { type: ButtonType.Normal })
          .id('record-cancel-edit')
          .fontSize(11)
          .fontColor(V.forest)
          .backgroundColor('#DCE7C8')
          .height(32)
          .borderRadius(16)
          .enabled(!this.saving)
          .onClick(() => { this.cancelEdit(); })
      }
      .width('100%')
      .padding(13)
      .backgroundColor('#F8EFCF')
      .borderRadius(18)
    }
  }

  @Builder
  private inputPanel() {
    Column({ space: 13 }) {
      Row() {
        Column({ space: 3 }) {
          Text('输入数量')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(V.moss)
          Text(unitLabel(this.rules[this.selectedIndex].inputUnit))
            .fontSize(19)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        Text(`${this.rules[this.selectedIndex].minQuantity} – ${this.rules[this.selectedIndex].maxQuantity}`)
          .fontSize(10)
          .fontColor(V.muted)
      }
      .width('100%')

      TextInput({ placeholder: '输入数量', text: this.quantity })
        .id('preview-quantity')
        .type(InputType.NUMBER_DECIMAL)
        .height(54)
        .fontSize(22)
        .fontWeight(FontWeight.Bold)
        .fontColor(V.ink)
        .placeholderColor(V.sage)
        .backgroundColor('#FCFAF0')
        .border({ width: 1, color: V.line })
        .borderRadius(16)
        .padding({ left: 15, right: 15 })
        .enabled(!this.saving)
        .onChange((value: string) => {
          this.quantity = value;
          this.invalidatePreview();
        })

      if (this.requiresConfirmation(this.rules[this.selectedIndex])) {
        Column({ space: 9 }) {
          Text('适用条件')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1)
            .fontColor(V.amber)
            .width('100%')
          Text(this.rules[this.selectedIndex].confirmationText.length > 0 ?
            this.rules[this.selectedIndex].confirmationText :
            `基准：${this.rules[this.selectedIndex].baselineLabel}；实际：${this.rules[this.selectedIndex].actualLabel}`)
            .fontSize(12)
            .fontColor(V.ink)
            .lineHeight(19)
            .width('100%')
          Button({ type: ButtonType.Normal }) {
            Row({ space: 9 }) {
              Stack() {
                Text(this.confirmed ? '✓' : '')
                  .fontSize(12)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(V.forest)
              }
              .width(20)
              .height(20)
              .backgroundColor(this.confirmed ? V.lime : '#00000000')
              .border({ width: this.confirmed ? 0 : 1, color: V.sage })
              .borderRadius(10)
              Text(this.confirmed ? '已确认适用条件' : '确认符合以上条件')
                .fontSize(12)
                .fontWeight(FontWeight.Medium)
                .fontColor(V.ink)
            }
            .height(40)
            .padding({ left: 12, right: 14 })
          }
          .id('preview-confirm')
          .width('100%')
          .backgroundColor(this.confirmed ? '#EAF2CE' : '#FCFAF0')
          .border({ width: 1, color: this.confirmed ? '#D3E39A' : V.line })
          .borderRadius(14)
          .enabled(!this.saving)
          .onClick(() => {
            this.invalidatePreview();
            this.confirmed = !this.confirmed;
          })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(13)
        .backgroundColor('#FBF6E4')
        .borderRadius(16)
      }

      Button({ type: ButtonType.Normal }) {
        Row({ space: 8 }) {
          if (this.calculating) {
            LoadingProgress().width(18).height(18).color(V.lime)
          }
          Text(this.calculating ? '正在核算…' : '查看核算预览')
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.lime)
          if (!this.calculating) {
            Text('→')
              .fontSize(17)
              .fontColor(V.lime)
          }
        }
        .height(48)
        .justifyContent(FlexAlign.Center)
      }
      .id('preview-calculate')
      .width('100%')
      .height(48)
      .backgroundColor(V.forest)
      .borderRadius(24)
      .clickEffect({ level: ClickEffectLevel.MIDDLE })
      .shadow({ radius: 18, color: '#33123424', offsetX: 0, offsetY: 8 })
      .enabled(!this.calculating && !this.saving)
      .onClick(() => { this.calculate(); })
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(16)
    .backgroundColor('#FDFBF2')
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(22)
    .shadow({ radius: 16, color: '#14173B2A', offsetX: 0, offsetY: 6 })
  }

  @Builder
  private resultPanel(result: CalculationPreview) {
    Column({ space: 13 }) {
      Row() {
        Row({ space: 7 }) {
          Circle().width(6).height(6).fill(this.saveMessage.length > 0 ? V.lime : '#BBD6B8')
          Text(this.saveMessage.length > 0 ? '已保存的行动' : '核算预览 · 尚未保存')
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor('#CBDDCB')
        }
        Blank()
        Text(`规则 · ${result.factorSnapshot.rule.name}`)
          .fontSize(9)
          .fontColor('#94B09A')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .constraintSize({ maxWidth: '45%' })
      }
      .width('100%')

      AnimatedReduction({
        grams: result.reductionGrams,
        valueSize: 44,
        unitSize: 13,
        color: V.cream,
        accent: '#B9D3B9',
        idValue: 'preview-result'
      })

      Text(result.reductionGrams < 0 ? '相对基准的排放增加' : '参考减排量 · 估算值')
        .fontSize(10)
        .fontColor('#9EB9A2')
        .width('100%')

      Row({ space: 10 }) {
        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            Text(this.saving ? '正在保存' : (this.saveMessage.length > 0 ? '✓ 已保存' :
              (this.editingRecord === null ? '保存这次行动' : '保存更正')))
              .fontSize(13)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.forest)
          }
          .height(44)
          .justifyContent(FlexAlign.Center)
        }
        .id('preview-save')
        .layoutWeight(1)
        .height(44)
        .backgroundColor(this.saveMessage.length > 0 ? '#DCE9C0' : V.lime)
        .borderRadius(22)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .enabled(!this.saving && this.saveMessage.length === 0)
        .onClick(() => { this.savePreview(); })

        Button(this.showDetails ? '收起依据' : '计算依据', { type: ButtonType.Normal })
          .id('preview-details')
          .fontSize(11)
          .fontColor(V.cream)
          .backgroundColor('#1CFFFFFF')
          .border({ width: 1, color: '#1FFFFFFF' })
          .height(44)
          .borderRadius(22)
          .clickEffect({ level: ClickEffectLevel.MIDDLE })
          .onClick(() => { this.showDetails = !this.showDetails; })
      }
      .width('100%')

      if (this.saveMessage.length > 0) {
        Text(this.saveMessage)
          .fontSize(11)
          .fontColor(V.lime)
          .width('100%')
      }

      if (this.showDetails) {
        Column({ space: 10 }) {
          Column().width('100%').height(1).backgroundColor('#1AFFFFFF')
          Text(result.formulaText)
            .fontSize(12)
            .fontColor('#DCE9DA')
            .lineHeight(19)
            .width('100%')
          Text('适用假设')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.lime)
            .width('100%')
          ForEach(result.assumptions, (item: string, index: number) => {
            Text(`· ${item}`)
              .fontSize(11)
              .fontColor('#B9CFBB')
              .lineHeight(18)
              .width('100%')
          }, (item: string, index: number) => `${index}-${item}`)
          Text('来源与边界')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.lime)
            .width('100%')
          ForEach(result.factorSnapshot.factors, (factor: FactorDefinition) => {
            Column({ space: 2 }) {
              Text(factor.source.title)
                .fontSize(11)
                .fontWeight(FontWeight.Medium)
                .fontColor('#E6F0E2')
                .width('100%')
              Text(`${factor.source.publisher} · ${factor.source.region}`)
                .fontSize(10)
                .fontColor('#9EB9A2')
                .width('100%')
              Text(factor.source.url)
                .fontSize(9)
                .fontColor('#87A18B')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
          }, (factor: FactorDefinition) => factor.id)
          ForEach(result.warnings, (warning: string, index: number) => {
            Text(warning)
              .fontSize(10)
              .fontColor('#D9B98C')
              .lineHeight(17)
              .width('100%')
          }, (warning: string, index: number) => `${index}-${warning}`)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(20)
    .borderRadius(26)
    .linearGradient({
      angle: 135,
      colors: [['#0D382A', 0.0], ['#154836', 0.55], ['#286147', 1.0]]
    })
    .shadow({ radius: 24, color: '#4D0E3526', offsetX: 0, offsetY: 12 })
  }

  @Builder
  private historyCard(record: BehaviorRecord, index: number) {
    Column({ space: 9 }) {
      Row({ space: 10 }) {
        Column({ space: 3 }) {
          Text(record.factorSnapshot.rule.name)
            .fontSize(14)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
            .width('100%')
          Text(record.businessDate)
            .fontSize(9)
            .fontColor(V.muted)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text(this.recordAmount(record.reductionGrams))
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(record.reductionGrams < 0 ? V.coral : V.pine)
          .padding({ left: 10, right: 10, top: 5, bottom: 5 })
          .backgroundColor(record.reductionGrams < 0 ? '#F7E9E2' : '#EAF0DF')
          .borderRadius(12)
      }
      .width('100%')

      Text(record.formulaText)
        .fontSize(10)
        .fontColor(V.text)
        .lineHeight(16)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')

      ForEach(record.factorSnapshot.factors, (factor: FactorDefinition) => {
        Text(`依据 · ${factor.source.title}`)
          .fontSize(9)
          .fontColor(V.sage)
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }, (factor: FactorDefinition) => factor.id)

      if (this.voidConfirmId === record.id) {
        Column({ space: 8 }) {
          Text('撤销后记录会从统计中移除，已领取积分可能调整。')
            .fontSize(10)
            .fontColor(V.coral)
            .lineHeight(16)
            .width('100%')
          Row({ space: 8 }) {
            Button('取消', { type: ButtonType.Normal })
              .fontSize(11)
              .fontColor(V.pine)
              .backgroundColor('#EDF1E1')
              .height(32)
              .borderRadius(16)
              .enabled(!this.voidBusy)
              .onClick(() => { this.voidConfirmId = ''; })
            Button('确认撤销', { type: ButtonType.Normal })
              .id(`record-confirm-void-${record.id}`)
              .fontSize(11)
              .fontColor(V.white)
              .backgroundColor('#9B4B43')
              .height(32)
              .borderRadius(16)
              .enabled(!this.voidBusy)
              .onClick(() => { this.voidRecord(record); })
          }
          .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(10)
        .backgroundColor('#FAEEE8')
        .borderRadius(12)
      } else {
        Row({ space: 8 }) {
          Button('更正', { type: ButtonType.Normal })
            .id(`record-edit-${record.id}`)
            .fontSize(11)
            .fontColor(V.pine)
            .backgroundColor('#EDF1E1')
            .height(32)
            .borderRadius(16)
            .enabled(!this.saving && !this.voidBusy)
            .onClick(() => { this.editRecord(record); })
          Button('撤销', { type: ButtonType.Normal })
            .id(`record-void-${record.id}`)
            .fontSize(11)
            .fontColor(V.coral)
            .backgroundColor('#F7EDE7')
            .height(32)
            .borderRadius(16)
            .enabled(!this.saving && !this.voidBusy)
            .onClick(() => {
              this.voidConfirmId = record.id;
              this.mutationError = '';
              this.mutationMessage = '';
            })
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(18)
    .opacity(this.appeared ? 1 : 0)
    .translate({ y: this.appeared ? 0 : 12 })
    .animation({ duration: 420, delay: 60 + Math.min(index, 6) * 40, curve: softSpring() })
  }

  build() {
    Column({ space: 16 }) {
      this.editBanner()
      this.stepRail()

      Row() {
        Column({ space: 3 }) {
          Text('选择一项行动')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text(this.selectedIndex < 0 ? '从今天最顺手的一件小事开始' : '换一张卡片，或继续填写数量')
            .fontSize(10)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.selectedIndex >= 0) {
          Text('已选择')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor(V.limeSoft)
            .borderRadius(10)
        }
      }
      .width('100%')

      if (this.loading) {
        Row({ space: 12 }) {
          LoadingProgress().width(22).height(22).color(V.pine)
          Text('正在读取行动规则…')
            .fontSize(12)
            .fontColor(V.text)
        }
        .width('100%')
        .padding(20)
        .backgroundColor('#FDFBF2')
        .borderRadius(20)
      } else {
        if (this.rules.length === 0 && this.error.length === 0) {
          Text('暂时没有可用的行动规则。')
            .fontSize(12)
            .fontColor(V.muted)
            .width('100%')
        }
        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.rules, (rule: CalculationRule, index: number) => {
            this.ruleCard(rule, index)
          }, (rule: CalculationRule) => rule.id)
        }
        .width('100%')

        if (this.selectedIndex >= 0 && this.selectedIndex < this.rules.length) {
          this.inputPanel()
        }
      }

      if (this.error.length > 0) {
        Row({ space: 10 }) {
          Text('!')
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.error)
            .width(22)
            .height(22)
            .textAlign(TextAlign.Center)
            .backgroundColor('#F8E5DF')
            .borderRadius(11)
          Text(this.error)
            .id('preview-error')
            .fontSize(11)
            .fontColor(V.error)
            .lineHeight(17)
            .layoutWeight(1)
        }
        .width('100%')
        .padding(12)
        .backgroundColor('#FCF1EC')
        .borderRadius(14)
        if (this.rules.length === 0) {
          Button('重新读取规则', { type: ButtonType.Normal })
            .fontSize(12)
            .fontColor(V.pine)
            .backgroundColor(V.mint)
            .height(38)
            .width('100%')
            .borderRadius(19)
            .onClick(() => { this.loadRules(); })
        }
      }

      if (this.preview !== null) {
        this.resultPanel(this.preview as CalculationPreview)
      }

      Row() {
        Column({ space: 3 }) {
          Text('最近的行动')
            .fontSize(20)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
          Text('更正或撤销会同步重新核算')
            .fontSize(10)
            .fontColor(V.muted)
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)
        if (this.historyTotal > 0) {
          Text(`${this.historyTotal} 条`)
            .fontSize(10)
            .fontColor(V.moss)
            .padding({ left: 9, right: 9, top: 4, bottom: 4 })
            .backgroundColor('#EAF0DF')
            .borderRadius(10)
        }
      }
      .width('100%')
      .margin({ top: 4 })

      if (this.mutationMessage.length > 0) {
        Text(this.mutationMessage).fontSize(11).fontColor(V.pine).width('100%')
      }
      if (this.mutationError.length > 0) {
        Text(this.mutationError).fontSize(11).fontColor(V.error).width('100%')
      }

      Scroll() {
        Row({ space: 7 }) {
          ForEach(HISTORY_CATEGORIES, (choice: HistoryCategory) => {
            Button(choice.label, { type: ButtonType.Normal })
              .id(`history-category-${choice.label}`)
              .fontSize(11)
              .fontColor(this.historyCategory === choice.value ? V.forest : V.text)
              .backgroundColor(this.historyCategory === choice.value ? V.lime : '#EAF0DF')
              .height(32)
              .borderRadius(16)
              .padding({ left: 13, right: 13 })
              .onClick(() => { this.historyCategory = choice.value; this.loadHistory(); })
          }, (choice: HistoryCategory) => choice.label)
        }
      }
      .scrollable(ScrollDirection.Horizontal)
      .scrollBar(BarState.Off)
      .width('100%')

      if (this.historyError.length > 0) {
        Text(this.historyError).fontSize(11).fontColor(V.error).width('100%')
        Button('重新读取记录', { type: ButtonType.Normal })
          .fontSize(11).fontColor(V.pine).backgroundColor(V.mint).height(36).borderRadius(18)
          .onClick(() => { this.loadHistory(); })
      } else if (this.historyLoading && this.history.length === 0) {
        Text('正在读取记录…').fontSize(11).fontColor(V.muted).width('100%')
      } else if (this.history.length === 0) {
        Column({ space: 7 }) {
          Text('这一页还是空的')
            .fontSize(14)
            .fontWeight(FontWeight.Medium)
            .fontColor(V.ink)
          Text('保存第一项行动后，会在这里留下真实的减排记录。')
            .fontSize(10)
            .fontColor(V.muted)
            .lineHeight(16)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(18)
        .backgroundColor(V.paper)
        .borderRadius(18)
      } else {
        ForEach(this.history, (record: BehaviorRecord, index: number) => {
          this.historyCard(record, index)
        }, (record: BehaviorRecord) => record.id)
        if (this.history.length < this.historyTotal) {
          Button(this.historyLoading ? '正在读取…' : '查看更多记录', { type: ButtonType.Normal })
            .id('history-more')
            .fontSize(12)
            .fontColor(V.pine)
            .backgroundColor('#EAF0DF')
            .width('100%')
            .height(42)
            .borderRadius(21)
            .enabled(!this.historyLoading)
            .onClick(() => { this.loadHistory(true); })
        }
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
