import common from '@ohos.app.ability.common';
import { AppServices } from '../common/contracts/Services';
import { Unsubscribe, StatisticsPeriod } from '../common/contracts/Common';
import { RouteId, RouteRequest } from '../common/contracts/Routes';
import { AppComposition } from '../common/composition/AppComposition';
import { MAIN_TABS, ShellTab, rootRequest, routeTitle } from '../common/composition/ShellNavigation';
import { AppError, ErrorCode, errorTitle, moduleNotReady, toAppError } from '../common/errors/AppError';
import { StatusPanel, ViewStatus } from '../common/design/StatusPanel';
import { CalculationPreviewPanel } from '../features/records/CalculationPreview';
import { SparkPanel } from '../features/spark/SparkPanel';
import { StatisticsPanel } from '../features/statistics/StatisticsPanel';
import { KnowledgePanel } from '../features/knowledge/KnowledgePanel';
import { OverviewSummary } from '../features/overview/OverviewSummary';
import { RewardsPanel, TaskPanel } from '../features/engagement/EngagementPanels';
import { AdvicePanel } from '../features/advice/AdvicePanel';
import { DataTransferPanel } from '../features/dataTransfer/DataTransferPanel';
import { FamilyPanel } from '../features/family/FamilyPanel';
import { AuroraBackdrop, V, softSpring } from '../features/ui/VisualKit';
import { LoginGate } from '../features/account/LoginGate';
import { Account, loadAccount } from '../features/account/AccountStore';
import { AiSheet } from '../features/ai/AiSheet';

@Entry
@Component
struct Index {
  @State private familyOpen: boolean = false;
  @State private aiOpen: boolean = false;
  @State private booted: boolean = false;
  @State private signedIn: boolean = false;
  @State private nickname: string = '';
  @State private selectedTab: RouteId = RouteId.OVERVIEW;
  @State private route: RouteId = RouteId.OVERVIEW;
  @State private status: ViewStatus = ViewStatus.LOADING;
  @State private statusTitle: string = '正在读取本地数据';
  @State private statusMessage: string = '';
  @State private retryable: boolean = false;
  @State private pageShift: boolean = true;
  @State private headerIn: boolean = false;
  private services: AppServices = AppComposition.getServices();
  private unsubscribe: Unsubscribe | null = null;
  private loadSequence: number = 0;
  private visible: boolean = false;
  private pageScroller: Scroller = new Scroller();
  private navTimer: number = -1;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.entranceTimer = setTimeout(() => { this.headerIn = true; }, 40);
    this.restoreAccount();
  }

  /**
   * Saved credentials prefill the gate but do not skip it: the login screen stays
   * the first thing a user sees, and only the password is needed to get in.
   */
  private async restoreAccount(): Promise<void> {
    try {
      const context = getContext(this) as common.UIAbilityContext;
      const account = await loadAccount(context);
      if (account !== null) {
        this.nickname = (account as Account).nickname;
      }
    } catch (error) {
      this.nickname = '';
    }
    this.booted = true;
  }

  onPageShow(): void {
    this.visible = true;
    if (this.unsubscribe === null) {
      this.unsubscribe = this.services.changes.subscribe(() => { this.refresh(); });
    }
    this.refresh();
  }

  onPageHide(): void {
    this.detach();
  }

  aboutToDisappear(): void {
    this.detach();
    if (this.navTimer !== -1) {
      clearTimeout(this.navTimer);
      this.navTimer = -1;
    }
    if (this.entranceTimer !== -1) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
  }

  onBackPress(): boolean {
    if (this.familyOpen) {
      this.closeFamily();
      return true;
    }
    if (this.isChild()) {
      this.navigate(rootRequest(this.selectedTab));
      return true;
    }
    return false;
  }

  private detach(): void {
    this.visible = false;
    this.loadSequence += 1;
    if (this.unsubscribe !== null) {
      this.unsubscribe();
      this.unsubscribe = null;
    }
  }

  private navigate(request: RouteRequest): void {
    if (this.navTimer !== -1) {
      clearTimeout(this.navTimer);
    }
    this.familyOpen = false;
    this.pageShift = false;
    this.navTimer = setTimeout(() => {
      this.route = request.route;
      this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0 });
      this.refresh();
      this.headerIn = false;
      this.headerIn = true;
      this.pageShift = true;
      this.navTimer = -1;
    }, 110);
  }

  private selectTab(route: RouteId): void {
    animateTo({ duration: 460, curve: softSpring() }, () => { this.selectedTab = route; });
    this.navigate(rootRequest(route));
  }

  private closeFamily(): void {
    this.familyOpen = false;
    this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0 });
  }

  private isChild(): boolean {
    return this.familyOpen || this.route !== this.selectedTab;
  }

  /** Every main tab opens with its own block; only pushed sub-pages use the shared header. */
  private showHeroHeader(): boolean {
    return this.isChild();
  }

  private activeTab(): number {
    for (let i = 0; i < MAIN_TABS.length; i++) {
      if (MAIN_TABS[i].route === this.selectedTab) {
        return i;
      }
    }
    return 0;
  }

  private tabIcon(route: RouteId): Resource {
    switch (route) {
      case RouteId.OVERVIEW: return $r('app.media.lucide_house');
      case RouteId.RECORDS: return $r('app.media.lucide_notebook_pen');
      case RouteId.STATISTICS: return $r('app.media.lucide_chart_column');
      case RouteId.TASKS: return $r('app.media.lucide_flame');
      default: return $r('app.media.lucide_user_round');
    }
  }

  private async readCurrentRoute(): Promise<boolean> {
    const today = this.services.clock.today();
    switch (this.route) {
      case RouteId.OVERVIEW:
      case RouteId.STATISTICS:
        const statistics = await this.services.statistics.query({
          period: StatisticsPeriod.DAY, anchorDate: today, category: null
        });
        return statistics.recordCount === 0;
      case RouteId.RECORDS:
        const records = await this.services.records.list({
          startDateInclusive: null, endDateExclusive: null, category: null,
          keyword: null, offset: 0, limit: 20
        });
        return records.total === 0;
      case RouteId.TASKS:
        return (await this.services.tasks.listForDate(today)).length === 0;
      case RouteId.PROFILE:
        await this.services.points.getBalance();
        return false;
      case RouteId.KNOWLEDGE:
        return (await this.services.knowledge.listArticles()).length === 0;
      case RouteId.REWARDS:
        return (await this.services.rewards.listRewards()).length === 0;
      case RouteId.ADVICE:
        return (await this.services.advice.listSuggestions(today)).length === 0;
      default:
        throw moduleNotReady(routeTitle(this.route));
    }
  }

  private async refresh(): Promise<void> {
    const sequence = ++this.loadSequence;
    this.status = ViewStatus.LOADING;
    this.statusTitle = '正在读取本地数据';
    this.statusMessage = '请稍候。';
    this.retryable = false;
    try {
      const empty = await this.readCurrentRoute();
      if (!this.visible || sequence !== this.loadSequence) {
        return;
      }
      this.status = empty ? ViewStatus.EMPTY : ViewStatus.CONNECTED;
      this.statusTitle = empty ? '暂无可展示的内容' : '服务已连接';
      this.statusMessage = empty ? '服务已返回空结果。后续可在记录页添加行为。' :
        '业务服务已返回结果，此应用壳尚未接入对应的功能组件。';
    } catch (error) {
      if (!this.visible || sequence !== this.loadSequence) {
        return;
      }
      const appError: AppError = toAppError(error as Object);
      this.status = appError.code === ErrorCode.MODULE_NOT_READY ? ViewStatus.UNAVAILABLE : ViewStatus.ERROR;
      this.statusTitle = errorTitle(appError);
      this.statusMessage = appError.message;
      this.retryable = appError.retryable;
    }
  }

  private pageLead(): string {
    switch (this.route) {
      case RouteId.OVERVIEW: return '今天，也轻一点';
      case RouteId.RECORDS: return '记下这一小步';
      case RouteId.STATISTICS: return '看见改变的形状';
      case RouteId.TASKS: return '把坚持变成习惯';
      case RouteId.PROFILE: return '你的绿色账本';
      case RouteId.KNOWLEDGE: return '读一页绿色生活';
      case RouteId.ADVICE: return '换一种生活选择';
      case RouteId.REWARDS: return '给坚持一点回响';
      case RouteId.DATA_MANAGEMENT: return '数据由你保管';
      default: return routeTitle(this.route);
    }
  }

  private pageNote(): string {
    switch (this.route) {
      case RouteId.OVERVIEW: return '记录每一次小小的绿色选择。';
      case RouteId.RECORDS: return '选择行动，填好数量，核算会如实给出参考结果。';
      case RouteId.STATISTICS: return '只汇总已经保存在本机的真实记录。';
      case RouteId.TASKS: return '完成今日行动，积累应用内积分。';
      case RouteId.PROFILE: return '所有记录留在本机，你可以随时备份与导出。';
      case RouteId.KNOWLEDGE: return '离线内容，随时翻看。';
      case RouteId.ADVICE: return '根据近七天记录整理，不虚构你的数据。';
      case RouteId.REWARDS: return '应用内虚拟奖励，不代表实物或实际植树。';
      case RouteId.DATA_MANAGEMENT: return '备份、恢复和 CSV 导出都在这里。';
      default: return '';
    }
  }

  private eyebrow(): string {
    switch (this.route) {
      case RouteId.OVERVIEW: return 'GREEN JOURNAL  /  今日';
      case RouteId.RECORDS: return 'LOG  /  低碳行动';
      case RouteId.STATISTICS: return 'INSIGHT  /  行动统计';
      case RouteId.TASKS: return 'RITUAL  /  每日任务';
      case RouteId.PROFILE: return 'LOCAL  /  本机账本';
      case RouteId.KNOWLEDGE: return 'READ  /  低碳科普';
      case RouteId.ADVICE: return 'IDEA  /  行动灵感';
      case RouteId.REWARDS: return 'REWARD  /  虚拟奖励';
      case RouteId.DATA_MANAGEMENT: return 'DATA  /  本地数据';
      default: return 'CARBON STEPS';
    }
  }

  @Builder
  private brandBar() {
    Row({ space: 11 }) {
      Stack() {
        Text('碳')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.lime)
      }
      .width(38)
      .height(38)
      .backgroundColor(V.forest)
      .borderRadius(13)
      .shadow({ radius: 12, color: '#33123524', offsetX: 0, offsetY: 5 })

      Column({ space: 1 }) {
        Text('碳小步')
          .fontSize(17)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
        Text('CARBON STEPS')
          .fontSize(8)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1.6)
          .fontColor(V.moss)
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)

      Row({ space: 6 }) {
        Circle().width(6).height(6).fill(V.pine)
        Text(this.services.clock.today())
          .fontSize(11)
          .fontWeight(FontWeight.Medium)
          .fontColor(V.pine)
      }
      .padding({ left: 11, right: 12, top: 7, bottom: 7 })
      .backgroundColor('#FDFBF2')
      .border({ width: 1, color: V.line })
      .borderRadius(16)
    }
    .width('100%')
    .padding({ left: 20, right: 20, top: 14, bottom: 6 })
    .opacity(this.headerIn ? 1 : 0)
    .translate({ y: this.headerIn ? 0 : -10 })
    .animation({ duration: 460, curve: softSpring() })
  }

  @Builder
  private pageHeader() {
    Row({ space: 10 }) {
      if (this.isChild()) {
        Button({ type: ButtonType.Normal }) {
          Text('‹')
            .fontSize(26)
            .fontWeight(FontWeight.Medium)
            .fontColor(V.ink)
            .margin({ top: -2 })
        }
        .id('shell-back')
        .width(40)
        .height(40)
        .backgroundColor('#FDFBF2')
        .border({ width: 1, color: V.line })
        .borderRadius(20)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .accessibilityText('返回')
        .onClick(() => { this.navigate(rootRequest(this.selectedTab)); })
      }

      Column({ space: this.isChild() ? 2 : 7 }) {
        if (!this.isChild()) {
          Text(this.eyebrow())
            .fontSize(10)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.2)
            .fontColor(V.moss)
            .width('100%')
        }
        Text(this.isChild() ? (this.familyOpen ? '家庭绿色账本' : routeTitle(this.route)) : this.pageLead())
          .id('shell-page-title')
          .fontSize(this.isChild() ? 25 : 32)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.ink)
          .letterSpacing(this.isChild() ? 0 : -0.8)
          .lineHeight(this.isChild() ? 32 : 40)
          .width('100%')
        Text(this.isChild() ? (this.familyOpen ? '一家人的小行动，一起积累。' : this.pageNote()) : this.pageNote())
          .fontSize(this.isChild() ? 11 : 13)
          .fontColor(this.isChild() ? V.muted : V.text)
          .lineHeight(this.isChild() ? 16 : 20)
          .maxLines(this.isChild() ? 1 : 2)
          .textOverflow({ overflow: TextOverflow.Ellipsis })
          .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .layoutWeight(1)
    }
    .width('100%')
    .alignItems(VerticalAlign.Center)
    .padding({ left: 20, right: 20, top: 10, bottom: 8 })
    .opacity(this.headerIn ? 1 : 0)
    .translate({ y: this.headerIn ? 0 : 14 })
    .animation({ duration: 520, curve: softSpring() })
  }

  @Builder
  private menuRow(icon: Resource, title: string, note: string, target: RouteId) {
    Button({ type: ButtonType.Normal }) {
      Row({ space: 13 }) {
        Stack() {
          Image(icon).width(20).height(20)
        }
        .width(42)
        .height(42)
        .backgroundColor(V.mint)
        .borderRadius(15)

        Column({ space: 3 }) {
          Text(title)
            .fontSize(15)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.ink)
            .width('100%')
          Text(note)
            .fontSize(11)
            .fontColor(V.muted)
            .width('100%')
            .maxLines(1)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
        }
        .alignItems(HorizontalAlign.Start)
        .layoutWeight(1)

        Text('›')
          .fontSize(22)
          .fontColor(V.moss)
      }
      .width('100%')
      .padding({ left: 14, right: 14, top: 11, bottom: 11 })
    }
    .id(`shell-link-${target}`)
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .width('100%')
    .backgroundColor('#FDFBF2')
    .border({ width: 1, color: '#E9EEDF' })
    .borderRadius(20)
    .onClick(() => { this.navigate(rootRequest(target)); })
  }

  @Builder
  private familyBanner() {
    Button({ type: ButtonType.Normal }) {
      Stack() {
        Circle()
          .width(150)
          .height(150)
          .fill('#FFFFFF')
          .opacity(0.05)
          .position({ x: 235, y: -55 })
        Circle()
          .width(110)
          .height(110)
          .fill(V.lime)
          .opacity(0.12)
          .position({ x: 265, y: 45 })
        Row({ space: 14 }) {
          Column({ space: 7 }) {
            Row({ space: 8 }) {
              Text('FAMILY  /  家庭账本')
                .fontSize(9)
                .fontWeight(FontWeight.Bold)
                .letterSpacing(1.1)
                .fontColor('#BDD5BE')
              Text('体验预览')
                .fontSize(9)
                .fontColor(V.forest)
                .padding({ left: 7, right: 7, top: 2, bottom: 2 })
                .backgroundColor(V.limeSoft)
                .borderRadius(8)
            }
            Text('一家人的小行动，\n一起积累成大改变。')
              .fontSize(19)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.cream)
              .lineHeight(27)
              .width('100%')
            Text('把绿色生活，过成共同的习惯。')
              .fontSize(11)
              .fontColor('#B9CFBB')
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .layoutWeight(1)

          Stack() {
            Text('›')
              .fontSize(24)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.forest)
          }
          .width(46)
          .height(46)
          .backgroundColor(V.lime)
          .borderRadius(23)
          .shadow({ radius: 14, color: '#55D9F26E', offsetX: 0, offsetY: 4 })
        }
        .width('100%')
        .padding({ left: 20, right: 18, top: 18, bottom: 18 })
      }
      .width('100%')
      .borderRadius(26)
      .clip(true)
      .linearGradient({
        angle: 125,
        colors: [['#0E3A2B', 0.0], ['#1C5540', 0.62], ['#2F6B4E', 1.0]]
      })
    }
    .id('family-open')
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .width('100%')
    .backgroundColor(V.forest)
    .borderRadius(26)
    .shadow({ radius: 22, color: '#33153B2C', offsetX: 0, offsetY: 10 })
    .onClick(() => {
      this.familyOpen = true;
      this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0 });
    })
  }

  @Builder
  private profileHero() {
    Stack() {
      Circle()
        .width(170)
        .height(170)
        .fill(V.lime)
        .opacity(0.1)
        .position({ x: 230, y: -70 })
      Circle()
        .width(90)
        .height(90)
        .fill('#FFFFFF')
        .opacity(0.06)
        .position({ x: 280, y: 50 })
      Column({ space: 14 }) {
        Row() {
          Text('LOCAL LEDGER')
            .fontSize(9)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.4)
            .fontColor('#B7CFB8')
          Blank()
          Row({ space: 5 }) {
            Circle().width(6).height(6).fill(V.lime)
            Text('仅本机')
              .fontSize(9)
              .fontColor('#D7E6D2')
          }
          .padding({ left: 8, right: 8, top: 4, bottom: 4 })
          .backgroundColor('#14FFFFFF')
          .borderRadius(10)
        }
        .width('100%')

        Text('每一笔记录，\n都是生活的另一种选择。')
          .fontSize(23)
          .fontWeight(FontWeight.Bold)
          .fontColor(V.cream)
          .lineHeight(32)
          .width('100%')

        Row({ space: 20 }) {
          Column({ space: 2 }) {
            Text('今日')
              .fontSize(9)
              .fontColor('#A9C2AC')
            Text(this.services.clock.today().substring(5).replace('-', ' / '))
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.lime)
          }
          .alignItems(HorizontalAlign.Start)
          Column({ space: 2 }) {
            Text('账号')
              .fontSize(9)
              .fontColor('#A9C2AC')
            Text(this.nickname.length === 0 ? '本机' : this.nickname)
              .fontSize(13)
              .fontWeight(FontWeight.Medium)
              .fontColor(V.cream)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
          }
          .alignItems(HorizontalAlign.Start)
        }
        .width('100%')
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(22)
    }
    .width('100%')
    .borderRadius(28)
    .clip(true)
    .linearGradient({
      angle: 130,
      colors: [['#0D382A', 0.0], ['#174C39', 0.6], ['#2C664B', 1.0]]
    })
    .shadow({ radius: 24, color: '#33123424', offsetX: 0, offsetY: 10 })
  }

  @Builder
  private profileContent() {
    Column({ space: 14 }) {
      this.profileHero()
      Text('探索与设置')
        .fontSize(10)
        .fontWeight(FontWeight.Bold)
        .letterSpacing(1.2)
        .fontColor(V.moss)
        .width('100%')
        .margin({ top: 4 })
      this.menuRow($r('app.media.lucide_leaf'), '低碳科普', '离线文章与来源', RouteId.KNOWLEDGE)
      this.menuRow($r('app.media.lucide_zap'), '低碳建议', '根据近七天记录整理', RouteId.ADVICE)
      this.menuRow($r('app.media.lucide_smartphone'), '备份、恢复与导出', 'CSV 与本地备份', RouteId.DATA_MANAGEMENT)
      Text('退出登录')
        .fontSize(11)
        .fontColor(V.moss)
        .width('100%')
        .textAlign(TextAlign.Center)
        .padding({ top: 12, bottom: 8 })
        .onClick(() => { this.signedIn = false; })
    }
    .width('100%')
  }

  @Builder
  private routeContent() {
    if (this.familyOpen) {
      FamilyPanel()
    } else if (this.route === RouteId.OVERVIEW) {
      OverviewSummary({ onStatistics: () => { this.navigate(rootRequest(RouteId.STATISTICS)); },
        onRecord: () => { this.selectTab(RouteId.RECORDS); } })
      SparkPanel({ onRecord: () => { this.selectTab(RouteId.RECORDS); } })
      this.familyBanner()
    } else if (this.route === RouteId.RECORDS) {
      CalculationPreviewPanel({ onEdit: () => {
        this.pageScroller.scrollTo({ xOffset: 0, yOffset: 0, animation: { duration: 260, curve: Curve.EaseOut } });
      }, onRuleSelected: () => {
        this.pageScroller.scrollTo({ xOffset: 0, yOffset: 430, animation: { duration: 320, curve: Curve.EaseOut } });
      } })
    } else if (this.route === RouteId.STATISTICS) {
      StatisticsPanel()
    } else if (this.route === RouteId.KNOWLEDGE) {
      KnowledgePanel()
    } else if (this.route === RouteId.TASKS) {
      TaskPanel({ onRewards: () => { this.navigate(rootRequest(RouteId.REWARDS)); },
        onRecord: () => { this.selectTab(RouteId.RECORDS); } })
    } else if (this.route === RouteId.REWARDS) {
      RewardsPanel()
    } else if (this.route === RouteId.ADVICE) {
      AdvicePanel({ onRecord: () => { this.selectTab(RouteId.RECORDS); } })
    } else if (this.route === RouteId.DATA_MANAGEMENT) {
      DataTransferPanel()
    } else if (this.route === RouteId.PROFILE) {
      this.profileContent()
    } else {
      StatusPanel({
        status: this.status, title: this.statusTitle, message: this.statusMessage,
        retryable: this.retryable, retry: () => { this.refresh(); }
      })
      this.menuRow($r('app.media.lucide_leaf'), '低碳科普', '离线文章与来源', RouteId.KNOWLEDGE)
      this.menuRow($r('app.media.lucide_leaf'), '数据管理', '备份、恢复与导出', RouteId.DATA_MANAGEMENT)
    }
  }

  @Builder
  private tabSlot(tab: ShellTab) {
    Button({ type: ButtonType.Normal }) {
      Column({ space: 3 }) {
        Image(this.tabIcon(tab.route))
          .width(20)
          .height(20)
          .opacity(this.selectedTab === tab.route ? 1 : 0.55)
        Text(tab.title)
          .fontSize(9)
          .fontWeight(this.selectedTab === tab.route ? FontWeight.Bold : FontWeight.Normal)
          .fontColor(this.selectedTab === tab.route ? V.ink : V.muted)
      }
      .width('100%')
      .height(62)
      .justifyContent(FlexAlign.Center)
    }
    .id(`shell-tab-${tab.route}`)
    .clickEffect({ level: ClickEffectLevel.MIDDLE })
    .accessibilityText(tab.title)
    .layoutWeight(1)
    .backgroundColor('#00000000')
    .onClick(() => { this.selectTab(tab.route); })
  }

  @Builder
  private bottomBar() {
    Row() {
      this.tabSlot(MAIN_TABS[0])
      this.tabSlot(MAIN_TABS[1])

      Stack({ alignContent: Alignment.Center }) {
        Stack() {
          Text('✦')
            .fontSize(21)
            .fontColor(V.forest)
        }
        .id('ai-fab')
        .width(54)
        .height(54)
        .borderRadius(27)
        .backgroundColor(V.lime)
        .shadow({ radius: 16, color: '#55163224', offsetX: 0, offsetY: 5 })
        .onClick(() => { this.aiOpen = true; })
      }
      .width(72)
      .height(62)
      .translate({ y: -14 })

      this.tabSlot(MAIN_TABS[2])
      this.tabSlot(MAIN_TABS[3])
    }
    .width('100%')
    .height(62)
    .padding({ left: 4, right: 4 })
    .backgroundColor('#F9F7EC')
    .border({ width: 1, color: '#CCFFFFFF' })
    .borderRadius(31)
    .shadow({ radius: 26, color: '#2E163B2A', offsetX: 0, offsetY: 12 })
    .margin({ left: 16, right: 16, bottom: 14 })
  }

  build() {
    Stack() {
      AuroraBackdrop()
      if (!this.booted) {
        Column()
          .width('100%')
          .height('100%')
      } else if (!this.signedIn) {
        LoginGate({
          onSuccess: (nickname: string) => {
            this.nickname = nickname;
            this.signedIn = true;
            this.visible = true;
            if (this.unsubscribe === null) {
              this.unsubscribe = this.services.changes.subscribe(() => { this.refresh(); });
            }
            this.refresh();
          }
        })
      } else {
      Column() {
        this.brandBar()
        if (this.showHeroHeader()) {
          this.pageHeader()
        }

        Scroll(this.pageScroller) {
          Column({ space: 18 }) {
            this.routeContent()
            Text('记录保存在本机 · 减排量为参考估算')
              .fontSize(10)
              .letterSpacing(0.4)
              .fontColor(V.muted)
              .width('100%')
              .textAlign(TextAlign.Center)
              .margin({ top: 4, bottom: 2 })
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
          .padding({ left: 20, right: 20, top: 8, bottom: 26 })
          .opacity(this.pageShift ? 1 : 0)
          .translate({ y: this.pageShift ? 0 : 18 })
          .animation({ duration: 420, curve: softSpring() })
        }
        .align(Alignment.Top)
        .layoutWeight(1)
        .width('100%')
        .scrollBar(BarState.Off)
        .edgeEffect(EdgeEffect.Spring)

        this.bottomBar()
      }
      .width('100%')
      .height('100%')

      if (this.aiOpen) {
        AiSheet({ onClose: () => { this.aiOpen = false; } })
      }
      }
    }
    .width('100%')
    .height('100%')
    .backgroundColor(V.cream)
  }
}
