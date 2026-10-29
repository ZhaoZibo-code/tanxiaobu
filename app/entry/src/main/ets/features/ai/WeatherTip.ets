import common from '@ohos.app.ability.common';
import { AppComposition } from '../../common/composition/AppComposition';
import { StatisticsPeriod } from '../../common/contracts/Common';
import { StatisticsResult } from '../../common/contracts/Statistics';
import { AppServices } from '../../common/contracts/Services';
import { V } from '../ui/VisualKit';
import { AiConfig, askModel, friendlyAiError, isConfigured, loadAiConfig } from './AiClient';
import { WeatherNow, fetchWeather, manualWeather } from './WeatherClient';

const MANUAL_KINDS: string[] = ['sunny', 'cloud', 'rain', 'hot', 'cold'];

const WEATHER_PROMPT: string =
  '你是低碳生活助手。根据天气和用户记录，从给定任务清单里挑一项今天最值得做的，' +
  '并说明它和天气的关系。只输出一个 JSON 对象，不要解释、不要代码块：' +
  '{"taskId":"任务 id","reason":"40 字内的中文理由"}。' +
  '任务清单为空或无法判断时输出 {"taskId":"","reason":""}。';

interface TaskPick {
  taskId: string;
  reason: string;
}

/**
 * Weather-aware nudge above the daily checklist. The rule-based tip works with no
 * model at all; the button adds one AI sentence and can highlight a task.
 */
@Component
export struct WeatherTip {
  /** "id｜标题" pairs, so the model can answer with an id we can highlight. */
  taskList: string = '';
  onRecommend: (taskId: string) => void = () => {};
  @State private weather: WeatherNow | null = null;
  @State private loading: boolean = true;
  @State private aiText: string = '';
  @State private aiBusy: boolean = false;
  @State private error: string = '';
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
    const weather = await fetchWeather();
    if (!this.active) {
      return;
    }
    this.weather = weather;
    this.loading = false;
    try {
      const context = getContext(this) as common.UIAbilityContext;
      this.config = await loadAiConfig(context);
    } catch (error) {
      this.config = { baseUrl: '', model: '', apiKey: '' };
    }
  }

  private kindLabel(kind: string): string {
    if (kind === 'cloud') {
      return '多云';
    }
    if (kind === 'rain') {
      return '下雨';
    }
    if (kind === 'hot') {
      return '高温';
    }
    if (kind === 'cold') {
      return '寒冷';
    }
    return '晴';
  }

  private async ask(): Promise<void> {
    if (this.aiBusy || this.weather === null || !(this.weather as WeatherNow).ok) {
      return;
    }
    if (!isConfigured(this.config)) {
      this.error = '先在「低碳建议」里配置模型。';
      return;
    }
    this.aiBusy = true;
    this.error = '';
    this.aiText = '';
    try {
      const today = this.services.clock.today();
      const stats: StatisticsResult = await this.services.statistics.query({
        period: StatisticsPeriod.WEEK, anchorDate: today, category: null
      });
      const now = this.weather as WeatherNow;
      const context = `\n\n今天 ${today}，${now.city}天气 ${now.temperature}℃，${now.text}。` +
        `用户近 7 天记录 ${stats.recordCount} 条，净减排 ${(stats.totalReductionGrams / 1000).toFixed(2)} kg CO₂e。` +
        `可选任务（id｜标题）：${this.taskList}。`;
      const reply = await askModel(this.config, WEATHER_PROMPT + context, '推荐哪一项？');
      const start = reply.indexOf('{');
      const end = reply.lastIndexOf('}');
      const json = start >= 0 && end > start ? reply.substring(start, end + 1) : reply;
      const pick = JSON.parse(json) as TaskPick;
      if (this.active) {
        if (pick.reason !== undefined && pick.reason.length > 0) {
          this.aiText = pick.reason;
        }
        if (pick.taskId !== undefined && pick.taskId.length > 0) {
          this.onRecommend(pick.taskId);
        }
      }
    } catch (error) {
      if (this.active) {
        this.error = friendlyAiError((error as Error).message);
      }
    }
    this.aiBusy = false;
  }

  build() {
    Column({ space: 8 }) {
      if (this.loading) {
        Row({ space: 8 }) {
          LoadingProgress().width(14).height(14).color(V.pine)
          Text('正在读取天气…')
            .fontSize(10)
            .fontColor(V.sage)
        }
        .width('100%')
      } else if (this.weather !== null && (this.weather as WeatherNow).ok) {
        Row({ space: 8 }) {
          Text(`${(this.weather as WeatherNow).city} · ${(this.weather as WeatherNow).temperature}℃ ` +
            `${(this.weather as WeatherNow).text}`)
            .fontSize(11)
            .fontWeight(FontWeight.Medium)
            .fontColor(V.pine)
          Blank()
          if (this.aiText.length === 0) {
            Text(this.aiBusy ? '推荐中…' : 'AI 推荐')
              .fontSize(10)
              .fontColor(V.moss)
              .onClick(() => { this.ask(); })
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.aiText.length > 0 ? this.aiText : (this.weather as WeatherNow).tip)
          .fontSize(11)
          .fontColor(this.aiText.length > 0 ? V.ink : V.text)
          .lineHeight(18)
          .width('100%')

        if (this.error.length > 0) {
          Text(this.error)
            .fontSize(9)
            .fontColor(V.error)
            .width('100%')
        }
      } else {
        Text('天气没取到，手动选一个')
          .fontSize(10)
          .fontColor(V.sage)
          .width('100%')
        Row({ space: 6 }) {
          ForEach(MANUAL_KINDS, (kind: string) => {
            Text(this.kindLabel(kind))
              .fontSize(10)
              .fontColor(V.text)
              .padding({ left: 10, right: 10, top: 6, bottom: 6 })
              .backgroundColor('#FFFFFF')
              .borderRadius(10)
              .onClick(() => { this.weather = manualWeather(kind); })
          }, (kind: string) => kind)
        }
        .width('100%')
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding({ left: 13, right: 13, top: 11, bottom: 11 })
    .backgroundColor('#F4F7EA')
    .border({ width: 1, color: '#E2E9D2' })
    .borderRadius(16)
  }
}
