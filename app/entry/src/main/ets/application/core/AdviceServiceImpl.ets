import { AdviceService, AppServices } from '../../common/contracts/Services';
import { Suggestion, SuggestionFeedback } from '../../common/contracts/Content';
import { BehaviorRecord } from '../../common/contracts/Records';
import { CalculationRule } from '../../common/contracts/Calculation';
import { PersistenceGateway } from '../../common/contracts/Persistence';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { addDays, requireLocalDate } from '../../common/utils/Dates';

export class AdviceServiceImpl implements AdviceService {
  private gateway: () => Promise<PersistenceGateway>;
  private services: AppServices;
  constructor(gateway: () => Promise<PersistenceGateway>, services: AppServices) { this.gateway = gateway; this.services = services; }

  async listSuggestions(date: string): Promise<Suggestion[]> {
    requireLocalDate(date);
    const db = await this.gateway();
    const records: BehaviorRecord[] = await db.read.records.getActiveSnapshot({
      startDateInclusive: addDays(date, -6), endDateExclusive: addDays(date, 1), category: null, keyword: null
    });
    const feedback = await db.read.metadata.listFeedback();
    const rules: CalculationRule[] = await this.services.calculation.listRules();
    const suggestions: Suggestion[] = [];
    for (const rule of rules) {
      const id = `advice:${date}:${rule.id}`;
      if (feedback.some(item => item.suggestionId === id)) { continue; }
      const count = records.filter((record: BehaviorRecord): boolean => record.category === rule.category).length;
      suggestions.push({ id: id, title: rule.name,
        reason: count === 0 ? '近七天还没有这一类记录，可以从适合自己的行动开始。' : `近七天已记录 ${count} 次同类行动，可以继续保持。`,
        evidenceSummary: '依据本地近七天有效记录和当前可用规则生成；录入时可查看规则与来源。',
        proposedRuleId: rule.id, estimate: null, actionLabel: '去记录', generatedForDate: date });
    }
    return suggestions;
  }

  async recordFeedback(suggestionId: string, feedback: SuggestionFeedback): Promise<void> {
    if (!/^advice:\d{4}-\d{2}-\d{2}:.+/.test(suggestionId) ||
      (feedback !== SuggestionFeedback.ACCEPTED && feedback !== SuggestionFeedback.DISMISSED)) {
      throw new AppError(ErrorCode.INVALID_INPUT, '建议反馈无效。');
    }
    const date = suggestionId.substring(7, 17);
    requireLocalDate(date);
    const ruleId = suggestionId.substring(18);
    const rules = await this.services.calculation.listRules();
    if (!rules.some((rule: CalculationRule): boolean => rule.id === ruleId)) {
      throw new AppError(ErrorCode.INVALID_INPUT, '建议对应的行动不存在。');
    }
    const db = await this.gateway();
    await db.runInTransaction(async tx => {
      await tx.metadata.putFeedback({ suggestionId: suggestionId, feedback: feedback, updatedAt: this.services.clock.nowMs() });
    });
    this.services.changes.notifyDataChanged();
  }
}
