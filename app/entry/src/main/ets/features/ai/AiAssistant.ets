import common from '@ohos.app.ability.common';
import { AppComposition } from '../../common/composition/AppComposition';
import { StatisticsPeriod } from '../../common/contracts/Common';
import { StatisticsItem, StatisticsResult } from '../../common/contracts/Statistics';
import { AppServices } from '../../common/contracts/Services';
import { TaskProgress } from '../../common/contracts/Engagement';
import { V } from '../ui/VisualKit';
import { AiConfig, ChatTurn, DEFAULT_BASE_URL, DEFAULT_MODEL, askChat, friendlyAiError, isConfigured,
  loadAiConfig, saveAiConfig } from './AiClient';

const SYSTEM_PROMPT: string =
  '你是「碳小步」应用里的低碳生活助手，面向中国的大学生和家庭用户。' +
  '回答规则：1) 只依据下面给出的用户真实记录说话，不要编造用户没做过的行为；' +
  '2) 减排量是参考估算，不要说成核证数据或可交易碳信用；' +
  '3) 给具体、今天就能做的建议，说清为什么适合他；' +
  '4) 中文，口语化，每次 180 字以内，不要用 markdown 标题。';

const QUICK_QUESTIONS: string[] = ['今天做什么最值得？', '我的减排还有哪些空间？', '怎么把火花续下去？'];
/** Only the tail of the conversation is sent, to keep tokens bounded. */
const MAX_HISTORY_TURNS: number = 8;

/**
 * Optional online assistant. It only ever calls an endpoint the user configured
 * on this device; with no key it stays dormant and the page keeps using the
 * offline rule-based suggestions below it.
 */
@Component
export struct AiAssistant {
  @State private config: AiConfig = { baseUrl: DEFAULT_BASE_URL, model: DEFAULT_MODEL, apiKey: '' };
  @State private configured: boolean = false;
  @State private editing: boolean = false;
  @State private question: string = '';
  @State private turns: ChatTurn[] = [];
  @State private typing: string = '';
  @State private busy: boolean = false;
  @State private error: string = '';
  @State private baseUrlInput: string = DEFAULT_BASE_URL;
  @State private modelInput: string = DEFAULT_MODEL;
  @State private keyInput: string = '';
  private services: AppServices = AppComposition.getServices();
  private active: boolean = true;
  private typingTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    this.loadConfig();
  }

  aboutToDisappear(): void {
    this.active = false;
    this.stopTyping();
  }

  private stopTyping(): void {
    if (this.typingTimer !== -1) {
      clearInterval(this.typingTimer);
      this.typingTimer = -1;
    }
  }

  /** Reveals a finished reply character by character; the request itself is not streamed. */
  private typeOut(text: string): void {
    this.stopTyping();
    this.typing = '';
    let index = 0;
    this.typingTimer = setInterval(() => {
      index += 2;
      this.typing = text.substring(0, index);
      if (index >= text.length) {
        this.stopTyping();
        const next: ChatTurn[] = this.turns.slice();
        next.push({ role: 'assistant', content: text });
        this.turns = next;
        this.typing = '';
        this.busy = false;
      }
    }, 30);
  }

  private async loadConfig(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const config = await loadAiConfig(context);
      if (!this.active) {
        return;
      }
      this.config = config;
      this.baseUrlInput = config.baseUrl;
      this.modelInput = config.model;
      this.keyInput = config.apiKey;
      this.configured = isConfigured(config);
      this.editing = !this.configured;
    } catch (error) {
      this.error = '读取本机 AI 设置失败。';
    }
  }

  private async save(): Promise<void> {
    if (this.busy) {
      return;
    }
    this.busy = true;
    this.error = '';
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const config: AiConfig = {
        baseUrl: this.baseUrlInput.trim().length === 0 ? DEFAULT_BASE_URL : this.baseUrlInput.trim(),
        model: this.modelInput.trim(),
        apiKey: this.keyInput.trim()
      };
      await saveAiConfig(context, config);
      if (!this.active) {
        return;
      }
      this.config = config;
      this.configured = isConfigured(config);
      this.editing = false;
      if (!this.configured) {
        this.error = '地址、模型和密钥都要填写。';
      }
    } catch (error) {
      this.error = '保存失败，请重试。';
    }
    this.busy = false;
  }

  /** Summarises the last seven days so the model answers from real data. */
  private async buildContext(): Promise<string> {
    const today = this.services.clock.today();
    const stats: StatisticsResult = await this.services.statistics.query({
      period: StatisticsPeriod.WEEK, anchorDate: today, category: null
    });
    const parts: string[] = [];
    parts.push(`\n\n【用户最近 7 天真实记录】共 ${stats.recordCount} 条，净减排 ` +
      `${(stats.totalReductionGrams / 1000).toFixed(2)} kg CO₂e。`);
    const labels: string[] = [];
    stats.categories.forEach((item: StatisticsItem) => {
      if (item.recordCount > 0) {
        labels.push(`${item.label} ${(item.positiveReductionGrams / 1000).toFixed(2)} kg（${item.recordCount} 条）`);
      }
    });
    parts.push(labels.length === 0 ? '分类构成：本周还没有记录。' : `分类构成：${labels.join('；')}。`);
    try {
      const tasks = await this.services.tasks.listForDate(today);
      let done = 0;
      tasks.forEach((task: TaskProgress) => {
        if (task.claimed) {
          done += 1;
        }
      });
      const balance = await this.services.points.getBalance();
      parts.push(`今日任务 ${done}/${tasks.length} 已完成，当前积分 ${balance}。`);
    } catch (error) {
      // Task context is optional; keep the answer grounded on records alone.
    }
    return parts.join('');
  }

  private async ask(): Promise<void> {
    if (this.busy || !this.configured) {
      return;
    }
    const question = this.question.trim().length === 0 ? QUICK_QUESTIONS[0] : this.question.trim();
    const sent: ChatTurn[] = this.turns.slice();
    sent.push({ role: 'user', content: question });
    this.turns = sent;
    this.question = '';
    this.busy = true;
    this.error = '';
    try {
      const context = await this.buildContext();
      const history = sent.length > MAX_HISTORY_TURNS ? sent.slice(sent.length - MAX_HISTORY_TURNS) : sent;
      const reply = await askChat(this.config, SYSTEM_PROMPT + context, history);
      if (this.active) {
        this.typeOut(reply);
        return;
      }
    } catch (error) {
      if (this.active) {
        const kept: ChatTurn[] = [];
        for (let i = 0; i < this.turns.length - 1; i++) {
          kept.push(this.turns[i]);
        }
        this.turns = kept;
        this.question = question;
        this.error = friendlyAiError((error as Error).message);
      }
    }
    this.busy = false;
  }

  @Builder
  private setupForm() {
    Column({ space: 9 }) {
      Text('地址与密钥只保存在本机。')
        .fontSize(10)
        .fontColor(V.muted)
        .width('100%')

      TextInput({ text: this.baseUrlInput, placeholder: DEFAULT_BASE_URL })
        .id('ai-base-url')
        .height(44)
        .fontSize(12)
        .fontColor(V.ink)
        .backgroundColor('#FCFAF0')
        .border({ width: 1, color: V.line })
        .borderRadius(12)
        .onChange((value: string) => { this.baseUrlInput = value; })

      TextInput({ text: this.modelInput, placeholder: DEFAULT_MODEL })
        .id('ai-model')
        .height(44)
        .fontSize(12)
        .fontColor(V.ink)
        .backgroundColor('#FCFAF0')
        .border({ width: 1, color: V.line })
        .borderRadius(12)
        .onChange((value: string) => { this.modelInput = value; })

      TextInput({ text: this.keyInput, placeholder: 'API Key（sk-…）' })
        .id('ai-key')
        .type(InputType.Password)
        .height(44)
        .fontSize(12)
        .fontColor(V.ink)
        .backgroundColor('#FCFAF0')
        .border({ width: 1, color: V.line })
        .borderRadius(12)
        .onChange((value: string) => { this.keyInput = value; })

      Row({ space: 8 }) {
        Button('保存并启用', { type: ButtonType.Normal })
          .id('ai-save')
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
          .backgroundColor(V.lime)
          .height(38)
          .borderRadius(19)
          .layoutWeight(1)
          .enabled(!this.busy)
          .onClick(() => { this.save(); })
        if (this.configured) {
          Button('取消', { type: ButtonType.Normal })
            .fontSize(12)
            .fontColor(V.pine)
            .backgroundColor('#EAF0DF')
            .height(38)
            .borderRadius(19)
            .padding({ left: 16, right: 16 })
            .onClick(() => { this.editing = false; })
        }
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  @Builder
  private bubble(turn: ChatTurn, isUser: boolean) {
    Row() {
      Text(turn.content)
        .fontSize(12)
        .fontColor(isUser ? V.forest : V.ink)
        .lineHeight(19)
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor(isUser ? V.limeSoft : '#F7FAEE')
        .border({ width: isUser ? 0 : 1, color: '#E4EBD2' })
        .borderRadius(14)
        .constraintSize({ maxWidth: '84%' })
        .copyOption(CopyOptions.LocalDevice)
    }
    .width('100%')
    .justifyContent(isUser ? FlexAlign.End : FlexAlign.Start)
  }

  @Builder
  private typingBubble() {
    Row() {
      Text(this.typing)
        .fontSize(12)
        .fontColor(V.ink)
        .lineHeight(19)
        .padding({ left: 12, right: 12, top: 9, bottom: 9 })
        .backgroundColor('#F7FAEE')
        .border({ width: 1, color: '#E4EBD2' })
        .borderRadius(14)
        .constraintSize({ maxWidth: '84%' })
    }
    .width('100%')
    .justifyContent(FlexAlign.Start)
  }

  @Builder
  private askBox() {
    Column({ space: 10 }) {
      if (this.turns.length > 0) {
        Column({ space: 8 }) {
          ForEach(this.turns, (turn: ChatTurn, index: number) => {
            this.bubble(turn, turn.role === 'user')
          }, (turn: ChatTurn, index: number) => `${index}-${turn.role}`)
          if (this.typing.length > 0) {
            this.typingBubble()
          }
          if (this.busy && this.typing.length === 0) {
            Row({ space: 7 }) {
              LoadingProgress().width(14).height(14).color(V.pine)
              Text('正在思考…')
                .fontSize(11)
                .fontColor(V.sage)
            }
            .width('100%')
          }
        }
        .width('100%')
      }

      Row({ space: 6 }) {
        ForEach(QUICK_QUESTIONS, (item: string) => {
          Text(item)
            .fontSize(10)
            .fontColor(this.question === item ? V.forest : V.text)
            .padding({ left: 9, right: 9, top: 6, bottom: 6 })
            .backgroundColor(this.question === item ? V.limeSoft : '#F1F4E9')
            .borderRadius(11)
            .onClick(() => { this.question = item; })
        }, (item: string) => item)
      }
      .width('100%')

      Row({ space: 8 }) {
        TextInput({ text: this.question, placeholder: '接着聊，比如：那通勤呢？' })
          .id('ai-question')
          .layoutWeight(1)
          .height(46)
          .fontSize(12)
          .fontColor(V.ink)
          .backgroundColor('#FCFAF0')
          .border({ width: 1, color: V.line })
          .borderRadius(13)
          .onChange((value: string) => { this.question = value; })
          .onSubmit(() => { this.ask(); })

        Button({ type: ButtonType.Normal }) {
          Row({ space: 6 }) {
            if (this.busy) {
              LoadingProgress().width(14).height(14).color(V.lime)
            }
            Text(this.busy ? '思考中' : '发送')
              .fontSize(12)
              .fontWeight(FontWeight.Bold)
              .fontColor(this.busy ? '#B9CFBB' : V.lime)
          }
          .height(46)
          .padding({ left: 15, right: 15 })
          .justifyContent(FlexAlign.Center)
        }
        .id('ai-ask')
        .height(46)
        .backgroundColor(V.forest)
        .borderRadius(13)
        .enabled(!this.busy)
        .onClick(() => { this.ask(); })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column({ space: 11 }) {
      Row({ space: 8 }) {
        Text('✦')
          .fontSize(13)
          .fontColor(V.pine)
        Text('AI 助手')
          .fontSize(13)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Text(this.configured ? '在线' : '未配置')
          .fontSize(9)
          .fontColor(this.configured ? V.forest : V.sage)
          .padding({ left: 7, right: 7, top: 2, bottom: 2 })
          .backgroundColor(this.configured ? V.limeSoft : '#EDF1E1')
          .borderRadius(8)
        Blank()
        if (this.turns.length > 0) {
          Text('清空')
            .fontSize(10)
            .fontColor(V.moss)
            .margin({ right: 10 })
            .onClick(() => {
              this.stopTyping();
              this.typing = '';
              this.turns = [];
              this.error = '';
            })
        }
        Text(this.editing ? '收起' : '设置')
          .fontSize(10)
          .fontColor(V.moss)
          .onClick(() => { this.editing = !this.editing; })
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)

      if (this.editing) {
        this.setupForm()
      } else {
        this.askBox()
      }

      if (this.error.length > 0) {
        Text(this.error)
          .fontSize(10)
          .fontColor(V.error)
          .lineHeight(15)
          .width('100%')
          .padding(10)
          .backgroundColor('#FCF1EC')
          .borderRadius(10)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(15)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#DDE6D2' })
    .borderRadius(22)
  }
}
