import { Category } from '../../common/contracts/Common';
import { Article, ArticleSummary } from '../../common/contracts/Content';
import { KnowledgeService } from '../../common/contracts/Services';
import { AppError, ErrorCode } from '../../common/errors/AppError';

const ARTICLES: Article[] = [
  { id: 'carbon-goals', title: '读懂碳达峰与碳中和', summary: '两个目标，一条逐步降碳的路径。', category: Category.ENERGY_WATER,
    updatedDate: '2026-10-28', localImage: null,
    sections: [
      { heading: '先达峰，再走向平衡', body: '碳达峰指二氧化碳排放达到峰值后逐步下降。碳中和是指在一定时间内，人为排放与移除的二氧化碳相互抵消，达到净零。', localImage: null },
      { heading: '生活中的选择', body: '节约能源、绿色出行和减少浪费，都能成为参与绿色生活的起点。个人记录是参考估算，不能直接等同于核证减排量。', localImage: null }
    ], sources: [{ title: '带你轻松读懂碳达峰、碳中和、林业碳汇', publisher: '江苏省林业局',
      url: 'https://lyj.jiangsu.gov.cn/art/2023/7/19/art_54861_3653.html' }] },
  { id: 'home-energy', title: '家里的节能小事', summary: '从照明、家电和日常使用习惯开始。', category: Category.ENERGY_WATER,
    updatedDate: '2026-10-28', localImage: null,
    sections: [
      { heading: '让能源用在需要的地方', body: '离开房间时关灯，合理设定空调温度，及时关闭不再使用的电器电源；选购家电时关注能效标识。', localImage: null },
      { heading: '记录已节约的电量', body: '只有掌握了可比较的用电依据，才能填写已节约电量。不要把本月总用电量直接当作节约量。', localImage: null }
    ], sources: [{ title: '公民生态环境行为规范十条', publisher: '中华人民共和国生态环境部',
      url: 'https://www.mee.gov.cn/home/ztbd/2020/gmst/wenjian/202306/t20230615_1033831.shtml' }] },
  { id: 'food-and-reuse', title: '少一点浪费，多一点循环', summary: '按需取餐，让闲置物品重新被使用。', category: Category.FOOD,
    updatedDate: '2026-10-28', localImage: null,
    sections: [
      { heading: '从一餐开始', body: '根据需要取餐或点餐，妥善保存剩余食物。减少浪费不需要一次做到完美，持续留意自己的习惯就很好。', localImage: null },
      { heading: '延长物品的使用时间', body: '可用物品可以整理、转赠或通过二手交易继续使用；无法使用的物品应按当地分类要求投放。二手再利用与材料回收是不同的行为。', localImage: null }
    ], sources: [{ title: '公民生态环境行为规范十条', publisher: '中华人民共和国生态环境部',
      url: 'https://www.mee.gov.cn/home/ztbd/2020/gmst/wenjian/202306/t20230615_1033831.shtml' }] }
];

export class KnowledgeServiceImpl implements KnowledgeService {
  async listArticles(): Promise<ArticleSummary[]> {
    return ARTICLES.map((article: Article): ArticleSummary => ({ id: article.id, title: article.title,
      summary: article.summary, category: article.category }));
  }

  async getArticle(id: string): Promise<Article> {
    const article = ARTICLES.find((item: Article) => item.id === id);
    if (article === undefined) { throw new AppError(ErrorCode.INVALID_INPUT, '没有找到这篇文章。'); }
    return JSON.parse(JSON.stringify(article)) as Article;
  }
}
