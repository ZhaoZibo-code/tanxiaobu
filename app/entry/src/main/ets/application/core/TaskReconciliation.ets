import { Category } from '../../common/contracts/Common';
import { BehaviorRecord, RecordStatus } from '../../common/contracts/Records';
import { PointLedgerEntry, PointReason, TaskRewardState, TaskRuleType } from '../../common/contracts/Engagement';
import { TransactionContext } from '../../common/contracts/Persistence';
import { AppServices } from '../../common/contracts/Services';
import { addDays } from '../../common/utils/Dates';
import { requireInteger } from '../../common/utils/Display';

interface Adjustment {
  state: TaskRewardState;
  entry: PointLedgerEntry;
}

function eligible(state: TaskRewardState, records: BehaviorRecord[]): boolean {
  const categories: Category[] = [];
  let count = 0;
  records.forEach((record: BehaviorRecord) => {
    if (record.status === RecordStatus.ACTIVE && record.reductionGrams > 0) {
      count += 1;
      if (categories.indexOf(record.category) < 0) { categories.push(record.category); }
    }
  });
  return (state.definitionSnapshot.ruleType === TaskRuleType.POSITIVE_CATEGORY_COUNT ? categories.length : count) >=
    state.definitionSnapshot.target;
}

// Read all affected periods before writing: API12 RDB reads may not see uncommitted writes.
export async function planTaskAdjustments(tx: TransactionContext, before: BehaviorRecord | null,
  after: BehaviorRecord | null, services: AppServices, now: number): Promise<Adjustment[]> {
  const dates: string[] = [];
  if (before !== null) { dates.push(before.businessDate); }
  if (after !== null && dates.indexOf(after.businessDate) < 0) { dates.push(after.businessDate); }
  const plans: Adjustment[] = [];
  for (const date of dates) {
    const states = await tx.taskStates.listForPeriod(date);
    const records = await tx.records.getActiveSnapshot({ startDateInclusive: date, endDateExclusive: addDays(date, 1),
      category: null, keyword: null });
    const next = records.filter((record: BehaviorRecord) => before === null || record.id !== before.id);
    if (after !== null && after.status === RecordStatus.ACTIVE && after.businessDate === date) { next.push(after); }
    for (const oldState of states) {
      if (!oldState.everClaimed) { continue; }
      const desired = eligible(oldState, next) ? oldState.definitionSnapshot.points : 0;
      const delta = requireInteger(desired - oldState.netGrantedPoints);
      if (delta === 0) { continue; }
      const state: TaskRewardState = JSON.parse(JSON.stringify(oldState)) as TaskRewardState;
      state.netGrantedPoints = desired;
      state.transitionSequence = requireInteger(state.transitionSequence + 1);
      const entry: PointLedgerEntry = { id: services.ids.newId(), delta: delta,
        reason: delta < 0 ? PointReason.REVOCATION_ADJUSTMENT : PointReason.TASK_REWARD,
        sourceKey: `task:${state.taskId}:${date}:${state.transitionSequence}`,
        relatedRecordId: after !== null ? after.id : (before as BehaviorRecord).id,
        relatedTaskId: state.taskId, periodKey: date, createdAt: now };
      plans.push({ state: state, entry: entry });
    }
  }
  return plans;
}

export async function applyTaskAdjustments(tx: TransactionContext, plans: Adjustment[]): Promise<void> {
  for (const plan of plans) {
    await tx.taskStates.update(plan.state);
    await tx.points.insert(plan.entry);
  }
}
