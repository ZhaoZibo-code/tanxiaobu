import { AppComposition } from '../../common/composition/AppComposition';
import { CalculationInput, CalculationRule } from '../../common/contracts/Calculation';
import { BehaviorRecord } from '../../common/contracts/Records';
import { AppServices } from '../../common/contracts/Services';
import { V } from '../ui/VisualKit';
import { AiAssistant } from './AiAssistant';
import { QuickRecord } from './QuickRecord';

/**
 * Full-screen AI layer opened from the floating centre button. It holds both the
 * conversation and the one-sentence recorder, so a user who does not know how to
 * fill a form can just describe what happened.
 */
@Component
export struct AiSheet {
  onClose: () => void = () => {};
  @State private saved: string = '';
  @State private saveError: string = '';
  private services: AppServices = AppComposition.getServices();
  private active: boolean = true;

  aboutToAppear(): void {
    this.active = true;
  }

  aboutToDisappear(): void {
    this.active = false;
  }

  /** Writes through the real record service, exactly like the manual form. */
  private async save(ruleId: string, quantity: string, note: string): Promise<void> {
    this.saved = '';
    this.saveError = '';
    try {
      const rules = await this.services.calculation.listRules();
      let matched: CalculationRule | null = null;
      for (let i = 0; i < rules.length; i++) {
        if (rules[i].id === ruleId) {
          matched = rules[i];
        }
      }
      if (matched === null) {
        this.saveError = '没有找到对应的行动规则。';
        return;
      }
      const input: CalculationInput = {
        ruleId: ruleId,
        quantity: Number(quantity),
        unit: (matched as CalculationRule).inputUnit,
        businessDate: this.services.clock.today(),
        note: note,
        baselineConfirmed: true
      };
      const record: BehaviorRecord = await this.services.records.create(input, this.services.ids.newId());
      if (!this.active) {
        return;
      }
      this.saved = `已保存，减排约 ${record.reductionGrams} g CO₂e`;
    } catch (error) {
      if (this.active) {
        this.saveError = (error as Error).message;
      }
    }
  }

  build() {
    Column({ space: 0 }) {
      Row({ space: 10 }) {
        Text('✦')
          .fontSize(15)
          .fontColor(V.forest)
          .width(30)
          .height(30)
          .textAlign(TextAlign.Center)
          .backgroundColor(V.lime)
          .borderRadius(15)
        Text('AI')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.moss)
          .letterSpacing(1.2)
        Blank()
        Text('收起')
          .fontSize(12)
          .fontColor(V.moss)
          .padding({ left: 12, right: 12, top: 6, bottom: 6 })
          .backgroundColor('#EDF1E1')
          .borderRadius(14)
          .onClick(() => { this.onClose(); })
      }
      .width('100%')
      .padding({ left: 18, right: 18, top: 14, bottom: 10 })

      Scroll() {
        Column({ space: 14 }) {
          AiAssistant()

          QuickRecord({
            actionLabel: '保存记录',
            onApply: (ruleId: string, quantity: string, note: string) => {
              this.save(ruleId, quantity, note);
            }
          })

          if (this.saved.length > 0) {
            Text(this.saved)
              .fontSize(11)
              .fontWeight(FontWeight.Medium)
              .fontColor(V.pine)
              .width('100%')
              .padding(11)
              .backgroundColor('#EAF2CE')
              .borderRadius(12)
          }
          if (this.saveError.length > 0) {
            Text(this.saveError)
              .fontSize(11)
              .fontColor(V.error)
              .width('100%')
              .padding(11)
              .backgroundColor('#FCF1EC')
              .borderRadius(12)
          }
        }
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 30 })
      }
      .layoutWeight(1)
      .width('100%')
      .scrollBar(BarState.Off)
      .align(Alignment.Top)
    }
    .width('100%')
    .height('100%')
    .backgroundColor(V.cream)
  }
}
