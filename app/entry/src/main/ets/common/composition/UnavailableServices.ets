import { Id, LocalDate, RequestId } from '../contracts/Common';
import { CalculationInput, CalculationPreview, CalculationRule } from '../contracts/Calculation';
import { BehaviorRecord, RecordPage, RecordQuery } from '../contracts/Records';
import { PointLedgerEntry, Redemption, RewardDefinition, TaskProgress } from '../contracts/Engagement';
import { StatisticsQuery, StatisticsReport, StatisticsResult } from '../contracts/Statistics';
import { BackupInspection, ExportArtifact, RestoreSummary } from '../contracts/Backup';
import { Article, ArticleSummary, Suggestion, SuggestionFeedback } from '../contracts/Content';
import { AdviceService, BackupService, CalculationService, KnowledgeService, PointsService, RecordService,
  RewardService, StatisticsService, TaskService } from '../contracts/Services';
import { moduleNotReady } from '../errors/AppError';

export class UnavailableCalculationService implements CalculationService {
  async listRules(): Promise<CalculationRule[]> { throw moduleNotReady('核算服务'); }
  async preview(input: CalculationInput): Promise<CalculationPreview> { throw moduleNotReady('核算服务'); }
}

export class UnavailableRecordService implements RecordService {
  async create(input: CalculationInput, requestId: RequestId): Promise<BehaviorRecord> {
    throw moduleNotReady('记录服务');
  }
  async update(recordId: Id, input: CalculationInput, requestId: RequestId): Promise<BehaviorRecord> {
    throw moduleNotReady('记录服务');
  }
  async voidRecord(recordId: Id, requestId: RequestId): Promise<void> { throw moduleNotReady('记录服务'); }
  async getById(recordId: Id): Promise<BehaviorRecord> { throw moduleNotReady('记录服务'); }
  async list(query: RecordQuery): Promise<RecordPage> { throw moduleNotReady('记录服务'); }
}

export class UnavailableTaskService implements TaskService {
  async listForDate(date: LocalDate): Promise<TaskProgress[]> { throw moduleNotReady('任务服务'); }
  async claim(taskId: Id, date: LocalDate, requestId: RequestId): Promise<TaskProgress> {
    throw moduleNotReady('任务服务');
  }
}

export class UnavailablePointsService implements PointsService {
  async getBalance(): Promise<number> { throw moduleNotReady('积分服务'); }
  async listLedger(offset: number, limit: number): Promise<PointLedgerEntry[]> { throw moduleNotReady('积分服务'); }
}

export class UnavailableRewardService implements RewardService {
  async listRewards(): Promise<RewardDefinition[]> { throw moduleNotReady('奖励服务'); }
  async listRedemptions(): Promise<Redemption[]> { throw moduleNotReady('奖励服务'); }
  async redeem(rewardId: Id, requestId: RequestId): Promise<Redemption> { throw moduleNotReady('奖励服务'); }
}

export class UnavailableStatisticsService implements StatisticsService {
  async query(query: StatisticsQuery): Promise<StatisticsResult> { throw moduleNotReady('统计服务'); }
  async createReport(query: StatisticsQuery): Promise<StatisticsReport> { throw moduleNotReady('统计服务'); }
}

export class UnavailableBackupService implements BackupService {
  async exportBackup(): Promise<ExportArtifact> { throw moduleNotReady('数据管理服务'); }
  async inspectBackup(uri: string): Promise<BackupInspection> { throw moduleNotReady('数据管理服务'); }
  async restoreBackup(uri: string, expectedContentDigest: string, requestId: RequestId): Promise<RestoreSummary> {
    throw moduleNotReady('数据管理服务');
  }
  async exportCsv(query: StatisticsQuery): Promise<ExportArtifact> { throw moduleNotReady('数据管理服务'); }
}

export class UnavailableKnowledgeService implements KnowledgeService {
  async listArticles(): Promise<ArticleSummary[]> { throw moduleNotReady('科普服务'); }
  async getArticle(id: Id): Promise<Article> { throw moduleNotReady('科普服务'); }
}

export class UnavailableAdviceService implements AdviceService {
  async listSuggestions(date: LocalDate): Promise<Suggestion[]> { throw moduleNotReady('建议服务'); }
  async recordFeedback(suggestionId: Id, feedback: SuggestionFeedback): Promise<void> {
    throw moduleNotReady('建议服务');
  }
}
