import { AppComposition } from '../../common/composition/AppComposition';
import { Article, ArticleSection, ArticleSource, ArticleSummary } from '../../common/contracts/Content';
import { AppServices } from '../../common/contracts/Services';
import { toAppError } from '../../common/errors/AppError';
import { softSpring, V } from '../ui/VisualKit';

@Component
export struct KnowledgePanel {
  @State private articles: ArticleSummary[] = [];
  @State private current: Article | null = null;
  @State private loading: boolean = true;
  @State private error: string = '';
  @State private appeared: boolean = false;
  private services: AppServices = AppComposition.getServices();
  private active: boolean = false;
  private sequence: number = 0;
  private entranceTimer: number = -1;

  aboutToAppear(): void {
    this.active = true;
    this.entranceTimer = setTimeout(() => { this.appeared = true; }, 60);
    this.load();
  }
  aboutToDisappear(): void {
    this.active = false;
    this.sequence += 1;
    if (this.entranceTimer !== -1) {
      clearTimeout(this.entranceTimer);
      this.entranceTimer = -1;
    }
  }

  private async load(): Promise<void> {
    const sequence = ++this.sequence;
    this.loading = true;
    this.error = '';
    try {
      const articles = await this.services.knowledge.listArticles();
      if (this.active && sequence === this.sequence) { this.articles = articles; this.appeared = true; }
    } catch (error) {
      if (this.active && sequence === this.sequence) { this.error = toAppError(error as Object).message; }
    }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }

  private async open(id: string): Promise<void> {
    const sequence = ++this.sequence;
    this.loading = true;
    this.error = '';
    try {
      const article = await this.services.knowledge.getArticle(id);
      if (this.active && sequence === this.sequence) { this.current = article; }
    } catch (error) {
      if (this.active && sequence === this.sequence) { this.error = toAppError(error as Object).message; }
    }
    if (this.active && sequence === this.sequence) { this.loading = false; }
  }

  private illustration(id: string): Resource {
    if (id === 'home-energy') { return $r('app.media.knowledge_energy'); }
    if (id === 'food-and-reuse') { return $r('app.media.knowledge_reuse'); }
    return $r('app.media.knowledge_climate');
  }

  private articleIcon(index: number): Resource {
    if (index === 0) { return $r('app.media.lucide_leaf'); }
    if (index === 1) { return $r('app.media.lucide_zap'); }
    return $r('app.media.lucide_utensils');
  }

  private articleTint(index: number): string {
    if (index === 0) { return V.limeSoft; }
    if (index === 1) { return '#F6E7C8'; }
    return '#F3E5D9';
  }

  @Builder
  private articleList() {
    Column({ space: 14 }) {
      if (this.articles.length > 0) {
        Button({ type: ButtonType.Normal }) {
          Stack({ alignContent: Alignment.BottomStart }) {
            Image(this.illustration(this.articles[0].id))
              .width('100%')
              .height(148)
              .objectFit(ImageFit.Cover)
            Column()
              .width('100%')
              .height(148)
              .linearGradient({
                angle: 180,
                colors: [['#00122A1D', 0.0], ['#8C12291F', 0.48], ['#F20A2418', 1.0]]
              })
            Column({ space: 5 }) {
              Row({ space: 6 }) {
                Text('本期精选')
                  .fontSize(8)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(V.forest)
                  .padding({ left: 7, right: 7, top: 3, bottom: 3 })
                  .backgroundColor(V.lime)
                  .borderRadius(8)
                Text('约 3 分钟')
                  .fontSize(8)
                  .fontColor('#D8E6D5')
              }
              Text(this.articles[0].title)
                .fontSize(17)
                .fontWeight(FontWeight.Bold)
                .fontColor(V.cream)
                .maxLines(2)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
              Text('向下阅读，带走一个能用上的小知识。')
                .fontSize(9)
                .fontColor('#C6D9C2')
                .maxLines(1)
                .textOverflow({ overflow: TextOverflow.Ellipsis })
                .width('100%')
            }
            .alignItems(HorizontalAlign.Start)
            .width('100%')
            .padding({ left: 16, right: 16, bottom: 14 })
          }
          .width('100%')
          .height(148)
          .borderRadius(24)
          .clip(true)
        }
        .id(`knowledge-${this.articles[0].id}`)
        .width('100%')
        .height(148)
        .backgroundColor('#00000000')
        .borderRadius(24)
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .onClick(() => { this.open(this.articles[0].id); })
      }

      ForEach(this.articles, (article: ArticleSummary, index: number) => {
        if (index > 0) {
          Button({ type: ButtonType.Normal }) {
            Row({ space: 12 }) {
              Stack() {
                Image(this.articleIcon(index))
                  .width(20)
                  .height(20)
              }
              .width(44)
              .height(44)
              .backgroundColor(this.articleTint(index))
              .borderRadius(15)

              Column({ space: 4 }) {
                Text(article.title)
                  .fontSize(14)
                  .fontWeight(FontWeight.Bold)
                  .fontColor(V.ink)
                  .width('100%')
                Text(article.summary)
                  .fontSize(10)
                  .fontColor(V.muted)
                  .lineHeight(15)
                  .maxLines(2)
                  .textOverflow({ overflow: TextOverflow.Ellipsis })
                  .width('100%')
              }
              .alignItems(HorizontalAlign.Start)
              .layoutWeight(1)

              Text('›')
                .fontSize(20)
                .fontColor(V.moss)
            }
            .width('100%')
            .padding(13)
          }
          .id(`knowledge-${article.id}`)
          .width('100%')
          .backgroundColor(V.paper)
          .border({ width: 1, color: '#E9EEDF' })
          .borderRadius(20)
          .clickEffect({ level: ClickEffectLevel.MIDDLE })
          .opacity(this.appeared ? 1 : 0)
          .translate({ y: this.appeared ? 0 : 12 })
          .animation({ duration: 420, delay: 80 + index * 50, curve: softSpring() })
          .onClick(() => { this.open(article.id); })
        }
      }, (article: ArticleSummary) => article.id)

      Text('内容已内置，可离线阅读。')
        .fontSize(9)
        .fontColor(V.sage)
        .width('100%')
    }
    .width('100%')
  }

  @Builder
  private articleDetail() {
    Column({ space: 14 }) {
      Button('‹  返回文章列表', { type: ButtonType.Normal })
        .id('knowledge-back')
        .fontSize(11)
        .fontColor(V.pine)
        .backgroundColor('#EAF0DF')
        .height(36)
        .borderRadius(18)
        .padding({ left: 13, right: 13 })
        .clickEffect({ level: ClickEffectLevel.MIDDLE })
        .onClick(() => { this.current = null; })

      Stack({ alignContent: Alignment.BottomStart }) {
        Image(this.illustration((this.current as Article).id))
          .width('100%')
          .height(176)
          .objectFit(ImageFit.Cover)
        Column()
          .width('100%')
          .height(176)
          .linearGradient({
            angle: 180,
            colors: [['#00122A1D', 0.0], ['#8012291F', 0.46], ['#FA0A2418', 1.0]]
          })
        Column({ space: 6 }) {
          Text('GREEN LIVING  /  阅读')
            .fontSize(8)
            .fontWeight(FontWeight.Bold)
            .letterSpacing(1.2)
            .fontColor(V.lime)
          Text((this.current as Article).title)
            .fontSize(21)
            .fontWeight(FontWeight.Bold)
            .fontColor(V.cream)
            .lineHeight(29)
            .maxLines(2)
            .textOverflow({ overflow: TextOverflow.Ellipsis })
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding({ left: 18, right: 18, bottom: 16 })
      }
      .width('100%')
      .height(176)
      .borderRadius(26)
      .clip(true)
      .shadow({ radius: 20, color: '#4D0E3526', offsetX: 0, offsetY: 10 })

      Text((this.current as Article).summary)
        .fontSize(12)
        .fontColor(V.text)
        .lineHeight(20)
        .width('100%')
        .padding(15)
        .backgroundColor('#FBF6E4')
        .borderRadius(18)

      ForEach((this.current as Article).sections, (section: ArticleSection) => {
        Column({ space: 8 }) {
          Row({ space: 7 }) {
            Column().width(3).height(16).backgroundColor(V.lime).borderRadius(2)
            Text(section.heading)
              .fontSize(15)
              .fontWeight(FontWeight.Bold)
              .fontColor(V.ink)
              .layoutWeight(1)
          }
          .width('100%')
          Text(section.body)
            .fontSize(12)
            .fontColor(V.text)
            .lineHeight(22)
            .width('100%')
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor(V.paper)
        .border({ width: 1, color: '#E9EEDF' })
        .borderRadius(20)
      }, (section: ArticleSection) => section.heading)

      Column({ space: 7 }) {
        Text('参考来源')
          .fontSize(9)
          .fontWeight(FontWeight.Bold)
          .letterSpacing(1)
          .fontColor(V.moss)
          .width('100%')
        ForEach((this.current as Article).sources, (source: ArticleSource) => {
          Column({ space: 3 }) {
            Text(`${source.publisher} · ${source.title}`)
              .fontSize(10)
              .fontColor(V.text)
              .width('100%')
            Text(source.url)
              .fontSize(9)
              .fontColor(V.sage)
              .maxLines(1)
              .textOverflow({ overflow: TextOverflow.Ellipsis })
              .width('100%')
          }
          .alignItems(HorizontalAlign.Start)
          .width('100%')
        }, (source: ArticleSource) => source.url)
      }
      .alignItems(HorizontalAlign.Start)
      .width('100%')
      .padding(14)
      .backgroundColor('#EEF2E0')
      .borderRadius(18)
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }

  build() {
    Column({ space: 14 }) {
      if (this.loading) {
        Row({ space: 10 }) {
          LoadingProgress().width(20).height(20).color(V.pine)
          Text('正在打开内容…').fontSize(11).fontColor(V.text)
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
            .onClick(() => { this.current = null; this.load(); })
        }
        .alignItems(HorizontalAlign.Start)
        .width('100%')
        .padding(16)
        .backgroundColor('#FCF1EC')
        .borderRadius(18)
      } else if (this.current === null) {
        this.articleList()
      } else {
        this.articleDetail()
      }
    }
    .alignItems(HorizontalAlign.Start)
    .width('100%')
  }
}
