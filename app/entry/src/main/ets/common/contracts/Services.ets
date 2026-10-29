import { ChangeNotifier, Clock, Id, IdGenerator, LocalDate, RequestId } from './Common';
import { CalculationInput, CalculationPreview, CalculationRule } from './Calculation';
import { BehaviorRecord, RecordPage, RecordQuery } from './Records';
import { PointLedgerEntry, Redemption, RewardDefinition, TaskProgress } from './Engagement';
import { StatisticsQuery, StatisticsReport, StatisticsResult } from './Statistics';
import { BackupInspection, ExportArtifact, RestoreSummary } from './Backup';
import { Article, ArticleSummary, Suggestion, SuggestionFeedback } from './Content';

export interface CalculationService {
  listRules(): Promise<CalculationRule[]>;
  preview(input: CalculationInput): Promise<CalculationPreview>;
}

export interface RecordService {
  create(input: CalculationInput, requestId: RequestId): Promise<BehaviorRecord>;
  update(recordId: Id, input: CalculationInput, requestId: RequestId): Promise<BehaviorRecord>;
  voidRecord(recordId: Id, requestId: RequestId): Promise<void>;
  getById(recordId: Id): Promise<BehaviorRecord>;
  list(query: RecordQuery): Promise<RecordPage>;
}

export interface TaskService {
  listForDate(date: LocalDate): Promise<TaskProgress[]>;
  claim(taskId: Id, date: LocalDate, requestId: RequestId): Promise<TaskProgress>;
}

export interface PointsService {
  getBalance(): Promise<number>;
  listLedger(offset: number, limit: number): Promise<PointLedgerEntry[]>;
}

export interface RewardService {
  listRewards(): Promise<RewardDefinition[]>;
  listRedemptions(): Promise<Redemption[]>;
  redeem(rewardId: Id, requestId: RequestId): Promise<Redemption>;
}

export interface StatisticsService {
  query(query: StatisticsQuery): Promise<StatisticsResult>;
  createReport(query: StatisticsQuery): Promise<StatisticsReport>;
}

export interface BackupService {
  exportBackup(): Promise<ExportArtifact>;
  inspectBackup(uri: string): Promise<BackupInspection>;
  restoreBackup(uri: string, expectedContentDigest: string, requestId: RequestId): Promise<RestoreSummary>;
  exportCsv(query: StatisticsQuery): Promise<ExportArtifact>;
}

export interface KnowledgeService {
  listArticles(): Promise<ArticleSummary[]>;
  getArticle(id: Id): Promise<Article>;
}

export interface AdviceService {
  listSuggestions(date: LocalDate): Promise<Suggestion[]>;
  recordFeedback(suggestionId: Id, feedback: SuggestionFeedback): Promise<void>;
}

export interface AppServices {
  calculation: CalculationService;
  records: RecordService;
  tasks: TaskService;
  points: PointsService;
  rewards: RewardService;
  statistics: StatisticsService;
  backup: BackupService;
  knowledge: KnowledgeService;
  advice: AdviceService;
  changes: ChangeNotifier;
  clock: Clock;
  ids: IdGenerator;
}
