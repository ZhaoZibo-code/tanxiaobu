import { AppComposition } from '../../common/composition/AppComposition';
import { Unsubscribe } from '../../common/contracts/Common';
import { Redemption, RewardDefinition, TaskProgress, TaskRuleType } from '../../common/contracts/Engagement';
import { AppServices } from '../../common/contracts/Services';
import { toAppError } from '../../common/errors/AppError';
import { AnimatedInt, softSpring, V } from '../ui/VisualKit';
import { WeatherTip } from '../ai/WeatherTip';

/** Daily checklist is grouped by effort, not by list order. */
const TIERS: string[] = ['基础', '进阶', '挑战'];

@Component
export struct TaskPanel {
  onRewards: () => void = () => {};
  onRecord: () => void = () => {};
  @State private tasks: TaskProgress[] = [];
  @State private balance: number = 0;
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private message: string = '';
  @State private busy: boolean = false;
  @State private appeared: boolean = false;
  @State private recommendedId: string = '';
  private services: AppServices = AppComposition.getServices();
  private requests: Map<string, string> = new Map<string, string>();
  private active: boolean = false;
  private sequence: number = 0;
  private unsubscribe: Unsubscribe | null = null;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    this.unsubscribe = this.services.changes.subscribe(() => { this.load(); });
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 100);
    this.load();
  }
  aboutToDisappear(): void {
    this.active = false; this.sequence += 1;
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
      const tasks = await this.services.tasks.listForDate(this.services.clock.today());
      const balance = await this.services.points.getBalance();
      if (this.active && sequence === this.sequence) {
        this.tasks = tasks; this.balance = balance; this.appeared = true;
      }
    } catch (error) {
      if (this.active && sequence === this.sequence) { this.error = toAppError(error as Object).message; }
    }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }
  private async claim(task: TaskProgress): Promise<void> {
    if (this.busy) { return; }
    const requestKey = `${task.periodKey}:${task.definition.id}`;
    let requestId = this.requests.get(requestKey);
    if (requestId === undefined) { requestId = this.services.ids.newId(); this.requests.set(requestKey, requestId); }
    this.busy = true; this.error = ''; this.message = '';
    try {
      const claimed = await this.services.tasks.claim(task.definition.id, task.periodKey, requestId);
      if (this.active) { this.message = `已领取 ${claimed.earnedPoints} 积分`; await this.load(); }
    } catch (error) {
      if (this.active) { this.error = toAppError(error as Object).message; }
    }
    this.busy = false;
  }

  private taskProgress(task: TaskProgress): number {
    return Math.min(100, Math.round(Math.min(task.current, task.target) * 100 / Math.max(1, task.target)));
  }

  @Builder
  private pointsHero() {
    Stack() {
      Circle()
        .width(180)
        .height(180)
        .fill('#00000000')
        .stroke('#D9F26E')
        .strokeWidth(1)
        .opacity(0.16)
        .position({ x: 240, y: -80 })
      Circle()
        .width(90)
        .height(90)
        .fill(V.lime)
        .opacity(0.07)
        .position({ x: 270, y: 40 })
      Column({ space: 12 }) {
        Row() {
          Text('我的积分')
            .fontSize(11)
            .fontColor('#CBDDCB')
          Blank()
          Row({ space: 5 }) {
            Circle().width(5).height(5).fill(V.lime)
            Text('仅应用内')
              .fontSize(8)
              .fontColor('#D8E6D5')
          }
          .padding({ left: 8, right: 8, top: 3, bottom: 3 })
          .backgroundColor('#1AFFFFFF')
          .borderRadius(9)
        }
        .width('100%')

        Row() {
          AnimatedInt({
            value: this.balance,
            valueSize: 44,
            color: V.lime,
            idValue: 'points-balance'
          })
          Text('points')
            .fontSize(11)
            .fontColor('#9EB9A2')
            .margin({ left: 7, top: 22 })
          Blank()
          Button({ type: ButtonType.Normal }) {
            Row({ space: 5 }) {
              Text('虚拟奖励')
                .fontSize(10)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.forest)
              Text('›').fontSize(14).fontColor(V.forest)
            }
            .height(34)
            .padding({ left: 12, right: 10 })
          }
          .id('tasks-rewards')
          .height(34)
          .backgroundColor(V.lime)
          .borderRadius(17)
          .clickEffect({ level: ClickEffectLevel.MIDDLE })
          .onClick(() => { this.onRewards(); })
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)

        Text(this.tasks.length === 0 ? '完成今日行动，领取积分' :
          `今日清单全部完成可得 ${this.totalPoints()} 分`)
          .fontSize(10)
          .fontColor('#A9C4AC')
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

  /** 0 基础 / 1 进阶 / 2 挑战. */
  private tierOf(taskId: string): number {
    if (taskId === 'daily_record_once') {
      return 0;
    }
    return taskId === 'daily_reduction_1kg' ? 2 : 1;
  }

  private tasksIn(tier: number): TaskProgress[] {
    return this.tasks.filter((task: TaskProgress): boolean => this.tierOf(task.definition.id) === tier);
  }

  /** Each task borrows the colour of the category it belongs to. */
  private taskColor(taskId: string): string {
    if (taskId.indexOf('travel') >= 0) {
      return '#378ADD';
    }
    if (taskId.indexOf('food') >= 0) {
      return '#D85A30';
    }
    if (taskId.indexOf('reduction') >= 0) {
      return '#BA7517';
    }
    return '#1D9E75';
  }

  private totalPoints(): number {
    let total = 0;
    this.tasks.forEach((task: TaskProgress) => { total += task.definition.points; });
    return total;
  }

  /** Handed to the weather card so the model can pick one of today's real tasks. */
  private taskList(): string {
    const items: string[] = [];
    this.tasks.forEach((task: TaskProgress) => {
      items.push(`${task.definition.id}｜${task.definition.title}`);
    });
    return items.join('、');
  }

  @Builder
  private tierHeader(label: string, count: number) {
    Row() {
      Text(label)
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1.4)
        .fontColor(V.moss)
      Column()
        .width(14)
        .height(1)
        .backgroundColor(V.line)
        .margin({ left: 8 })
      Blank()
      Text(`${count} 项`)
        .fontSize(9)
        .fontColor(V.sage)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .margin({ top: 14, bottom: 2 })
  }

  @Builder
  private taskCard(task: TaskProgress) {
    Row({ space: 11 }) {
      Column()
        .width(3)
        .height(24)
        .borderRadius(2)
        .backgroundColor(this.taskColor(task.definition.id))
        .opacity(task.claimed ? 0.3 : 1)

      Stack() {
        if (task.claimed) {
          Text('✓')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.forest)
        } else if (task.eligible) {
          Text('✓')
            .fontSize(12)
            .fontWeight(FontWeight.Bold)
            .fontColor('#FFFFFF')
        }
      }
      .width(22)
      .height(22)
      .borderRadius(11)
      .backgroundColor(task.claimed ? V.lime : (task.eligible ? V.pine : '#00000000'))
      .border({ width: task.claimed || task.eligible ? 0 : 1.5, color: '#D5DDCE' })

      Column({ space: 3 }) {
        Row({ space: 6 }) {
          Text(task.definition.title)
            .fontSize(13)
            .fontWeight(FontWeight.Bold)
            .fontColor(task.claimed ? V.muted : V.ink)
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .layoutWeight(1)
          if (task.definition.id === this.recommendedId) {
            Text('推荐')
              .fontSize(8)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.forest)
              .padding({ left: 6, right: 6, top: 2, bottom: 2 })
              .backgroundColor(V.lime)
              .borderRadius(7)
          }
        }
        .width('100%')
        .alignItems(VerticalAlign.Center)
        Text(this.subtitle(task))
          .fontSize(9)
          .fontColor(V.sage)
          .width('100%')
          .maxLines(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      if (task.claimed) {
        Text(task.earnedPoints === 0 ? '已调整' : '已领取')
          .fontSize(10)
          .fontColor(V.sage)
      } else if (task.eligible) {
        Button('领取', { type: ButtonType.Normal })
          .id(`task-action-${task.definition.id}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
          .backgroundColor(V.lime)
          .height(30)
          .borderRadius(15)
          .padding({ left: 14, right: 14 })
          .enabled(!this.busy)
          .onClick(() => { this.claim(task); })
      } else {
        Text(`${task.definition.points} 分`)
          .fontSize(10)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
          .padding({ left: 9, right: 9, top: 4, bottom: 4 })
          .backgroundColor('#EFF4E2')
          .borderRadius(10)
      }
    }
    .width('100%')
    .padding({ top: 11, bottom: 11 })
    .alignItems(VerticalAlign.Center)
    .onClick(() => {
      if (!task.claimed && !task.eligible) {
        this.onRecord();
      }
    })
  }

  /** Description plus a live progress hint, e.g. "已 1.5 / 3 公里". */
  private subtitle(task: TaskProgress): string {
    const base = task.definition.description;
    if (task.claimed || task.current <= 0) {
      return base;
    }
    if (task.definition.ruleType === TaskRuleType.TOTAL_REDUCTION_GRAMS) {
      return `${base} · 已 ${Math.round(task.current)} / ${task.target} g`;
    }
    if (task.definition.ruleType === TaskRuleType.TRAVEL_KM_SUM) {
      return `${base} · 已 ${task.current} / ${task.target} 公里`;
    }
    return `${base} · 已 ${Math.min(task.current, task.target)} / ${task.target}`;
  }

  private claimedCount(): number {
    let done = 0;
    this.tasks.forEach((task: TaskProgress) => {
      if (task.claimed) {
        done += 1;
      }
    });
    return done;
  }

  build() {
    Column({ space: 14 }) {
      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(20).height(20).color(V.pine)
          Text('正在读取今日进度…').fontSize(11).fontColor(V.text)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(V.paper)
        .borderRadius(20)
      } else if (this.error.length > 0) {
        Column({ space: 8 }) {
          Text(this.error).fontSize(11).fontColor(V.error).width('100%')
          Button('重新读取', { type: ButtonType.Normal })
            .fontSize(11).fontColor(V.pine).backgroundColor(V.mint).height(36).borderRadius(18)
            .onClick(() => { this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FCF1EC')
        .borderRadius(18)
      } else {
        this.pointsHero()
        WeatherTip({
          taskList: this.taskList(),
          onRecommend: (taskId: string) => { this.recommendedId = taskId; }
        })

        Column({ space: 0 }) {
          ForEach(TIERS, (tier: string, tierIndex: number) => {
            if (this.tasksIn(tierIndex).length > 0) {
              this.tierHeader(tier, this.tasksIn(tierIndex).length)
              ForEach(this.tasksIn(tierIndex), (task: TaskProgress) => {
                this.taskCard(task)
              }, (task: TaskProgress) => task.definition.id)
            }
          }, (tier: string) => tier)
        }
        .width('100%')

        if (this.tasks.length === 0) {
          Text('今天暂时没有任务。')
            .fontSize(11)
            .fontColor(V.muted)
            .width('100%')
            .padding(16)
            .backgroundColor(V.paper)
            .borderRadius(18)
        }
      }
      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
          .width('100%')
          .padding(11)
          .backgroundColor('#EAF2CE')
          .borderRadius(14)
      }
      Text('积分和奖励仅在本应用内使用。')
        .fontSize(9)
        .fontColor(V.sage)
        .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}

@Component
export struct RewardsPanel {
  @State private rewards: RewardDefinition[] = [];
  @State private redemptions: Redemption[] = [];
  @State private balance: number = 0;
  @State private loading: boolean = true;
  @State private busy: boolean = false;
  @State private confirming: string = '';
  @State private error: string = '';
  @State private message: string = '';
  private services: AppServices = AppComposition.getServices();
  private requests: Map<string, string> = new Map<string, string>();
  private active: boolean = false;
  private sequence: number = 0;
  private unsubscribe: Unsubscribe | null = null;

  aboutToAppear(): void { this.active = true; this.unsubscribe = this.services.changes.subscribe(() => { this.load(); }); this.load(); }
  aboutToDisappear(): void {
    this.active = false; this.sequence += 1;
    if (this.unsubscribe !== null) { this.unsubscribe(); this.unsubscribe = null; }
  }
  private async load(): Promise<void> {
    const sequence = ++this.sequence; this.loading = true; this.error = '';
    try {
      const rewards = await this.services.rewards.listRewards();
      const redemptions = await this.services.rewards.listRedemptions();
      const balance = await this.services.points.getBalance();
      if (this.active && sequence === this.sequence) { this.rewards = rewards; this.redemptions = redemptions; this.balance = balance; }
    } catch (error) {
      if (this.active && sequence === this.sequence) { this.error = toAppError(error as Object).message; }
    }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }
  private redeemed(id: string): boolean {
    return this.redemptions.some((item: Redemption) => item.rewardId === id);
  }
  private async redeem(reward: RewardDefinition): Promise<void> {
    if (this.busy) { return; }
    let requestId = this.requests.get(reward.id);
    if (requestId === undefined) { requestId = this.services.ids.newId(); this.requests.set(reward.id, requestId); }
    this.busy = true; this.error = ''; this.message = '';
    try {
      await this.services.rewards.redeem(reward.id, requestId);
      if (this.active) { this.confirming = ''; this.message = `已兑换「${reward.title}」`; await this.load(); }
    } catch (error) {
      if (this.active) { this.error = toAppError(error as Object).message; }
    }
    this.busy = false;
  }

  @Builder
  private rewardCard(reward: RewardDefinition) {
    Column({ space: 0 }) {
      Row() {
        Stack() {
          Image(reward.id === 'badge_first_step' ?
            $r('app.media.lucide_leaf') : $r('app.media.lucide_flame'))
            .width(22)
            .height(22)
        }
        .width(44)
        .height(44)
        .backgroundColor(this.redeemed(reward.id) ? '#E6EBDD' : V.limeSoft)
        .borderRadius(14)

        Blank()

        if (this.redeemed(reward.id)) {
          Text('已拥有')
            .fontSize(9)
            .fontColor(V.sage)
            .padding({ left: 7, right: 7, top: 3, bottom: 3 })
            .backgroundColor('#ECEFE4')
            .borderRadius(8)
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Top)

      Text(reward.title)
        .fontSize(13)
        .fontWeight(FontWeight.Bold)
        .fontColor(this.redeemed(reward.id) ? V.muted : V.ink)
        .width('100%')
        .maxLines(1)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .margin({ top: 10 })

      Text(reward.description)
        .fontSize(9)
        .fontColor(V.muted)
        .lineHeight(14)
        .maxLines(2)
        .textOverflow({ overflow: TextOverflow.Ellipsis })
        .width('100%')
        .margin({ top: 4 })

      Blank()

      Row() {
        Text(`${reward.costPoints}`)
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(this.redeemed(reward.id) ? V.sage : V.amber)
        Text(' 分')
          .fontSize(9)
          .fontColor(V.sage)
        Blank()
        if (!this.redeemed(reward.id)) {
          Button(this.balance >= reward.costPoints ? '兑换' : `还差 ${reward.costPoints - this.balance}`,
            { type: ButtonType.Normal })
            .id(`reward-action-${reward.id}`)
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .fontColor(this.balance >= reward.costPoints ? V.forest : V.sage)
            .backgroundColor(this.balance >= reward.costPoints ? V.lime : '#ECEFE4')
            .height(30)
            .borderRadius(15)
            .padding({ left: 12, right: 12 })
            .enabled(!this.busy && this.balance >= reward.costPoints)
            .onClick(() => { this.confirming = reward.id; })
        }
      }
      .width('100%')
      .alignItems(VerticalAlign.Center)
      .margin({ top: 10 })
    }
    .alignItems(HorizontalAlign.Start)
    .width('48.5%')
    .height(186)
    .margin({ bottom: 10 })
    .padding(14)
    .backgroundColor(V.paper)
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(20)
  }

  /** Points still needed for the cheapest reward the user does not own yet. */
  private nextGap(): number {
    let best = -1;
    for (let i = 0; i < this.rewards.length; i++) {
      if (this.redeemed(this.rewards[i].id)) {
        continue;
      }
      const gap = this.rewards[i].costPoints - this.balance;
      if (gap > 0 && (best < 0 || gap < best)) {
        best = gap;
      }
    }
    return best;
  }

  private confirmingReward(): RewardDefinition | null {    for (let i = 0; i < this.rewards.length; i++) {
      if (this.rewards[i].id === this.confirming) {
        return this.rewards[i];
      }
    }
    return null;
  }

  @Builder
  private confirmBar() {
    Column({ space: 10 }) {
      Row({ space: 6 }) {
        Text('确认兑换')
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Text(this.confirmingReward() === null ? '' : `「${(this.confirmingReward() as RewardDefinition).title}」`)
          .fontSize(11)
          .fontColor(V.muted)
        Blank()
        Text(this.confirmingReward() === null ? '' : `-${(this.confirmingReward() as RewardDefinition).costPoints} 分`)
          .fontSize(12)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.amber)
      }
      .width('100%')

      Row({ space: 8 }) {
        Button('取消', { type: ButtonType.Normal })
          .fontSize(11)
          .fontColor(V.pine)
          .backgroundColor('#EAF0DF')
          .height(36)
          .borderRadius(18)
          .layoutWeight(1)
          .onClick(() => { this.confirming = ''; })
        Button('确认兑换', { type: ButtonType.Normal })
          .id(`reward-confirm-${this.confirming}`)
          .fontSize(11)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.forest)
          .backgroundColor(V.lime)
          .height(36)
          .borderRadius(18)
          .layoutWeight(2)
          .enabled(!this.busy)
          .onClick(() => {
            const reward = this.confirmingReward();
            if (reward !== null) {
              this.redeem(reward);
            }
          })
      }
      .width('100%')
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
    .padding(14)
    .backgroundColor('#FBF6E4')
    .border({ width: 1, color: '#EDE2C4' })
    .borderRadius(18)
  }

  build() {
    Column({ space: 14 }) {
      Stack() {
        Circle()
          .width(150)
          .height(150)
          .fill('#00000000')
          .stroke('#D9F26E')
          .strokeWidth(1)
          .opacity(0.16)
          .position({ x: 250, y: -60 })
        Column({ space: 9 }) {
          Row() {
            Text('把行动留作纪念')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.cream)
            Blank()
            Text('虚拟奖励')
              .fontSize(8)
              .fontColor(V.forest)
              .padding({ left: 8, right: 8, top: 3, bottom: 3 })
              .backgroundColor(V.limeSoft)
              .borderRadius(9)
          }
          .width('100%')
          Text(this.nextGap() > 0 ? `再得 ${this.nextGap()} 分就能兑换下一件` : '已经可以兑换纪念品了')
            .fontSize(10)
            .fontColor('#B9CFBB')
            .width('100%')
          Row({ space: 6 }) {
            Text('当前积分')
              .fontSize(10)
              .fontColor('#A9C2AC')
            Text(`${this.balance}`)
              .id('rewards-balance')
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.lime)
          }
          .width('100%')
          .alignItems(VerticalAlign.Bottom)
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(20)
      }
      .width('100%')
      .borderRadius(26)
      .clip(true)
      .linearGradient({
        angle: 130,
        colors: [['#0C3527', 0.0], ['#154836', 0.58], ['#2A6349', 1.0]]
      })
      .shadow({ radius: 22, color: '#4D0E3526', offsetX: 0, offsetY: 10 })

      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(20).height(20).color(V.pine)
          Text('正在读取奖励…').fontSize(11).fontColor(V.text)
        }
        .width('100%')
        .padding(18)
        .backgroundColor(V.paper)
        .borderRadius(20)
      } else if (this.error.length > 0) {
        Column({ space: 8 }) {
          Text(this.error).fontSize(11).fontColor(V.error).width('100%')
          Button('重新读取', { type: ButtonType.Normal })
            .fontSize(11).fontColor(V.pine).backgroundColor(V.mint).height(36).borderRadius(18)
            .onClick(() => { this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FCF1EC')
        .borderRadius(18)
      } else {
        Row() {
          Text('纪念品')
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor(V.moss)
          Blank()
          Text('兑换后留在本机')
            .fontSize(9)
            .fontColor(V.sage)
        }
        .width('100%')

        Flex({ wrap: FlexWrap.Wrap, justifyContent: FlexAlign.SpaceBetween }) {
          ForEach(this.rewards, (reward: RewardDefinition) => {
            this.rewardCard(reward)
          }, (reward: RewardDefinition) => reward.id)
        }
        .width('100%')

        if (this.confirming.length > 0) {
          this.confirmBar()
        }
        if (this.rewards.length === 0) {
          Text('暂时没有可兑换的奖励。').fontSize(11).fontColor(V.muted).width('100%')
        }
      }

      if (this.message.length > 0) {
        Text(this.message)
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
          .width('100%')
          .padding(11)
          .backgroundColor('#EAF2CE')
          .borderRadius(14)
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
