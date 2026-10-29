import common from '@ohos.app.ability.common';
import { AppComposition } from '../../common/composition/AppComposition';
import { CalculationInput, CalculationPreview, CalculationRule } from '../../common/contracts/Calculation';
import { BehaviorRecord, RecordPage } from '../../common/contracts/Records';
import { AppServices } from '../../common/contracts/Services';
import { addDays } from '../../common/utils/Dates';
import { V } from '../ui/VisualKit';
import { AiConfig, askModel, friendlyAiError, isConfigured, loadAiConfig } from './AiClient';

/** Records a day may create through AI, so a chatty model cannot farm points. */
const DAILY_AI_LIMIT: number = 5;
const AI_NOTE_PREFIX: string = 'AI 辅助 · ';

interface ParsedRecord {
  ruleId: string;
  quantity: number;
  note: string;
  ask: string;
}

/**
 * One-sentence logging: the model only translates language into a rule id and a
 * quantity. It never writes to the database — the caller still runs the normal
 * preview, condition confirmation and save, so every guard rail stays in place.
 */
@Component
export struct QuickRecord {
  onApply: (ruleId: string, quantity: string, note: string) => void = () => {};
  actionLabel: string = '填入表单';
  @State private text: string = '';
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private askText: string = '';
  @State private parsed: ParsedRecord | null = null;
  @State private matchedName: string = '';
  @State private matchedUnit: string = '';
  @State private previewGrams: number = -1;
  @State private configured: boolean = false;
  @State private remaining: number = DAILY_AI_LIMIT;
  private services: AppServices = AppComposition.getServices();
  private config: AiConfig = { baseUrl: '', model: '', apiKey: '' };
  private active: boolean = true;

  aboutToAppear(): void {
    this.active = true;
    this.load();
  }

  aboutToDisappear(): void {
    this.active = false;
  }

  private async load(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.config = await loadAiConfig(context);
      this.configured = isConfigured(this.config);
      this.remaining = DAILY_AI_LIMIT - await this.aiCountToday();
    } catch (error) {
      this.configured = false;
    }
  }

  private async aiCountToday(): Promise<number> {
    const today = this.services.clock.today();
    const page: RecordPage = await this.services.records.list({
      startDateInclusive: today, endDateExclusive: addDays(today, 1),
      category: null, keyword: null, offset: 0, limit: 100
    });
    let count = 0;
    page.items.forEach((record: BehaviorRecord) => {
      if (record.note.indexOf(AI_NOTE_PREFIX) >= 0) {
        count += 1;
      }
    });
    return count;
  }

  private ruleList(rules: CalculationRule[]): string {
    const lines: string[] = [];
    rules.forEach((rule: CalculationRule) => {
      lines.push(`- ${rule.id}｜${rule.name}｜单位 ${rule.inputUnit}｜范围 ${rule.minQuantity}-${rule.maxQuantity}`);
    });
    return lines.join('\n');
  }

  private prompt(rules: CalculationRule[]): string {
    return '你是低碳行为录入助手，把用户的一句话转成一条结构化记录。' +
      '只能从下面的规则里选，不要发明规则：\n' + this.ruleList(rules) + '\n' +
      '只输出一个 JSON 对象，不要解释、不要代码块：' +
      '{"ruleId":"规则id","quantity":数字,"note":"不超过20字的中文描述","ask":""}。' +
      '如果缺关键信息（比如说了骑车但没说公里数），把 ruleId 和 quantity 留空，' +
      '在 ask 里用一句中文追问，例如「大概骑了几公里？」。' +
      '完全无法对应任何规则时输出 {"ruleId":"","quantity":0,"note":"","ask":""}。';
  }

  private extractJson(raw: string): string {
    const start = raw.indexOf('{');
    const end = raw.lastIndexOf('}');
    return start >= 0 && end > start ? raw.substring(start, end + 1) : raw;
  }

  /**
   * Runs the real calculation engine so the number shown next to the parsed
   * sentence comes from the local factor library, never from the model.
   */
  private async previewGramsFor(parsed: ParsedRecord, rule: CalculationRule): Promise<number> {
    try {
      const input: CalculationInput = {
        ruleId: rule.id,
        quantity: parsed.quantity,
        unit: rule.inputUnit,
        businessDate: this.services.clock.today(),
        note: '',
        baselineConfirmed: true
      };
      const preview: CalculationPreview = await this.services.calculation.preview(input);
      return preview.reductionGrams;
    } catch (error) {
      return -1;
    }
  }

  private async parse(): Promise<void> {
    if (this.busy) {
      return;
    }
    const sentence = this.text.trim();
    if (sentence.length === 0) {
      this.error = '先用一句话说说你做了什么。';
      return;
    }
    if (!this.configured) {
      this.error = '还没配置模型：到「低碳建议 → AI 助手 → 设置」填入地址和密钥。';
      return;
    }
    if (this.remaining <= 0) {
      this.error = `今天用 AI 记账已达 ${DAILY_AI_LIMIT} 次上限，可以手动选择行动。`;
      return;
    }
    this.busy = true;
    this.error = '';
    this.askText = '';
    this.parsed = null;
    try {
      const rules = await this.services.calculation.listRules();
      const reply = await askModel(this.config, this.prompt(rules), sentence);
      const parsed = JSON.parse(this.extractJson(reply)) as ParsedRecord;
      let matched: CalculationRule | null = null;
      for (let i = 0; i < rules.length; i++) {
        if (rules[i].id === parsed.ruleId) {
          matched = rules[i];
        }
      }
      if (matched === null) {
        const ask = parsed.ask === undefined ? '' : parsed.ask;
        this.askText = ask;
        this.error = ask.length > 0 ? '' : '没听懂这件事对应哪类行动，换个说法，或直接手动选择。';
      } else if (!(parsed.quantity >= matched.minQuantity && parsed.quantity <= matched.maxQuantity)) {
        this.askText = '';
        this.error = `识别到的数量超出「${matched.name}」的范围（${matched.minQuantity}-${matched.maxQuantity}）。`;
      } else {
        this.askText = '';
        this.parsed = parsed;
        this.matchedName = matched.name;
        this.matchedUnit = `${matched.inputUnit}`;
        this.previewGrams = await this.previewGramsFor(parsed, matched);
        this.remaining = DAILY_AI_LIMIT - await this.aiCountToday();
      }
    } catch (error) {
      this.error = friendlyAiError((error as Error).message);
    }
    this.busy = false;
  }

  private apply(): void {
    if (this.parsed === null) {
      return;
    }
    const note = this.parsed.note.trim().length === 0 ? '' : this.parsed.note.trim();
    this.onApply(this.parsed.ruleId, `${this.parsed.quantity}`, AI_NOTE_PREFIX + note);
    this.text = '';
    this.parsed = null;
  }

  build() {
    Column({ space: 9 }) {
      Row({ space: 7 }) {
        Text('一句话记账')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Text('AI')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
          .padding({ left: 6, right: 6, top: 2, bottom: 2 })
          .backgroundColor(V.limeSoft)
          .borderRadius(7)
        Blank()
        if (!this.configured) {
          Text('未配置')
            .fontSize(9)
            .fontColor(V.sage)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      Row({ space: 8 }) {
        TextInput({ text: this.text, placeholder: '比如：今天骑车上学 3 公里' })
          .id('quick-record-input')
          .layoutWeight(1)
          .height(44)
          .fontSize(12)
          .fontColor(V.ink)
          .backgroundColor('#FCFAF0')
          .border({ width: 1, color: V.line })
          .borderRadius(13)
          .onChange((value: string) => {
            this.text = value;
            this.error = '';
          })
          .onSubmit(() => { this.parse(); })

        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            if (this.busy) {
              LoadingProgress().width(14).height(14).color(V.forest)
            }
            Text(this.busy ? '解析中' : '解析')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.forest)
          }
          .height(44)
          .padding({ left: 14, right: 14 })
          .justifyContent(FlexAlign.Center)
        }
        .id('quick-record-parse')
        .height(44)
        .backgroundColor(V.lime)
        .borderRadius(13)
        .enabled(!this.busy)
        .onClick(() => { this.parse(); })
      }
      .width('100%')

      if (this.parsed !== null) {
        Row({ space: 8 }) {
          Column({ space: 2 }) {
            Text('识别结果')
              .fontSize(9)
              .fontColor(V.sage)
            Text(`${this.matchedName} · ${(this.parsed as ParsedRecord).quantity} ${this.matchedUnit}`)
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.ink)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
            if (this.previewGrams >= 0) {
              Text(`本地因子库核算 ≈ ${this.previewGrams} g CO₂e`)
                .fontSize(9)
                .fontColor(V.pine)
            }
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Button(this.actionLabel, { type: ButtonType.Normal })
            .id('quick-record-apply')
            .fontSize(11)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
            .backgroundColor(V.lime)
            .height(34)
            .borderRadius(17)
            .padding({ left: 14, right: 14 })
            .onClick(() => { this.apply(); })
        }
        .width('100%')
        .padding(11)
        .backgroundColor('#F7FAEE')
        .border({ width: 1, color: '#E4EBD2' })
        .borderRadius(13)
      }

      if (this.askText.length > 0) {
        Text(this.askText)
          .fontSize(11)
          .fontColor(V.ink)
          .lineHeight(17)
          .width('100%')
          .padding(10)
          .backgroundColor('#F7FAEE')
          .border({ width: 1, color: '#E4EBD2' })
          .borderRadius(11)
      }

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(10)
          .fontColor(V.error)
          .lineHeight(15)
          .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(13)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E3E9D6' })
    .borderRadius(18)
  }
}
