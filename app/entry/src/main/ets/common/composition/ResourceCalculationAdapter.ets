import resourceManager from '@ohos.resourceManager';
import common from '@ohos.app.ability.common';
import { AdviceServiceImpl } from '../../application/core/AdviceServiceImpl';
import { RecordServiceImpl } from '../../application/core/RecordServiceImpl';
import { StatisticsServiceImpl } from '../../application/core/StatisticsServiceImpl';
import { EngagementServiceImpl } from '../../application/core/EngagementServiceImpl';
import { BackupExportService } from '../../features/dataTransfer/BackupExportService';
import { RdbPersistenceGateway } from '../../data/persistence/RdbPersistenceGateway';
import { RecordService } from '../contracts/Services';
import { PointsService, RewardService, TaskService } from '../contracts/Services';
import { PointLedgerEntry, Redemption, RewardDefinition, TaskProgress } from '../contracts/Engagement';
import { BehaviorRecord, RecordPage, RecordQuery } from '../contracts/Records';
import { CalculationInput, CalculationPreview, CalculationRule } from '../contracts/Calculation';
import { CalculationService } from '../contracts/Services';
import { loadCalculationService } from '../../domain/calculation/ResourceCalculationService';
import { AppComposition } from './AppComposition';

export function configureCalculation(manager: resourceManager.ResourceManager): void {
  AppComposition.getServices().calculation = new ResourceCalculationAdapter(manager);
}

export function configureRecords(context: common.UIAbilityContext): void {
  const adapter = new ResourceRecordAdapter(context);
  const services = AppComposition.getServices();
  services.records = adapter;
  services.statistics = new StatisticsServiceImpl(() => adapter.gateway(), () => services.clock.nowMs());
  const engagement = new ResourceEngagementAdapter(adapter);
  services.tasks = engagement;
  services.points = engagement;
  services.rewards = engagement;
  services.backup = new BackupExportService(context, () => adapter.gateway(), services);
  services.advice = new AdviceServiceImpl(() => adapter.gateway(), services);
}

class ResourceEngagementAdapter implements TaskService, PointsService, RewardService {
  private readonly records: ResourceRecordAdapter;
  constructor(records: ResourceRecordAdapter) { this.records = records; }
  private async service(): Promise<EngagementServiceImpl> {
    return new EngagementServiceImpl(await this.records.gateway(), AppComposition.getServices());
  }
  async listForDate(date: string): Promise<TaskProgress[]> { return await (await this.service()).listForDate(date); }
  async claim(taskId: string, date: string, requestId: string): Promise<TaskProgress> {
    return await (await this.service()).claim(taskId, date, requestId);
  }
  async getBalance(): Promise<number> { return await (await this.service()).getBalance(); }
  async listLedger(offset: number, limit: number): Promise<PointLedgerEntry[]> {
    return await (await this.service()).listLedger(offset, limit);
  }
  async listRewards(): Promise<RewardDefinition[]> { return await (await this.service()).listRewards(); }
  async listRedemptions(): Promise<Redemption[]> { return await (await this.service()).listRedemptions(); }
  async redeem(rewardId: string, requestId: string): Promise<Redemption> {
    return await (await this.service()).redeem(rewardId, requestId);
  }
}

class ResourceRecordAdapter implements RecordService {
  private loading: Promise<RecordServiceImpl> | null = null;
  private gatewayLoading: Promise<RdbPersistenceGateway> | null = null;

  private readonly context: common.UIAbilityContext;

  constructor(context: common.UIAbilityContext) {
    this.context = context;
  }

  async gateway(): Promise<RdbPersistenceGateway> {
    if (this.gatewayLoading === null) {
      this.gatewayLoading = RdbPersistenceGateway.open(this.context);
    }
    try {
      return await this.gatewayLoading;
    } catch (error) {
      this.gatewayLoading = null;
      throw error as Error;
    }
  }

  private async load(): Promise<RecordServiceImpl> {
    if (this.loading === null) {
      this.loading = this.gateway().then((gateway: RdbPersistenceGateway): RecordServiceImpl =>
        new RecordServiceImpl(gateway, AppComposition.getServices()));
    }
    try {
      return await this.loading;
    } catch (error) {
      this.loading = null;
      throw error as Error;
    }
  }

  async create(input: CalculationInput, requestId: string): Promise<BehaviorRecord> {
    return await (await this.load()).create(input, requestId);
  }
  async update(recordId: string, input: CalculationInput, requestId: string): Promise<BehaviorRecord> {
    return await (await this.load()).update(recordId, input, requestId);
  }
  async voidRecord(recordId: string, requestId: string): Promise<void> {
    await (await this.load()).voidRecord(recordId, requestId);
  }
  async getById(recordId: string): Promise<BehaviorRecord> {
    return await (await this.load()).getById(recordId);
  }
  async list(query: RecordQuery): Promise<RecordPage> {
    return await (await this.load()).list(query);
  }
}

export class ResourceCalculationAdapter implements CalculationService {
  private manager: resourceManager.ResourceManager;
  private loading: Promise<CalculationService> | null = null;

  constructor(manager: resourceManager.ResourceManager) {
    this.manager = manager;
  }

  private async load(): Promise<CalculationService> {
    if (this.loading === null) {
      this.loading = loadCalculationService(this.manager);
    }
    try {
      return await this.loading;
    } catch (error) {
      this.loading = null;
      throw error as Error;
    }
  }

  async listRules(): Promise<CalculationRule[]> {
    return (await this.load()).listRules();
  }

  async preview(input: CalculationInput): Promise<CalculationPreview> {
    return (await this.load()).preview(input);
  }
}
