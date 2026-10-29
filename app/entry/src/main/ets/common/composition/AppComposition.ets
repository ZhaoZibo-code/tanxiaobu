import { AppServices } from '../contracts/Services';
import { SystemClock, UuidGenerator } from '../utils/Runtime';
import { ChangeBus } from './ChangeBus';
import { KnowledgeServiceImpl } from '../../application/core/KnowledgeServiceImpl';
import { UnavailableAdviceService, UnavailableBackupService, UnavailableCalculationService,
  UnavailableKnowledgeService, UnavailablePointsService, UnavailableRecordService,
  UnavailableRewardService, UnavailableStatisticsService, UnavailableTaskService } from './UnavailableServices';

export function createAppServices(): AppServices {
  return {
    calculation: new UnavailableCalculationService(),
    records: new UnavailableRecordService(),
    tasks: new UnavailableTaskService(),
    points: new UnavailablePointsService(),
    rewards: new UnavailableRewardService(),
    statistics: new UnavailableStatisticsService(),
    backup: new UnavailableBackupService(),
    knowledge: new KnowledgeServiceImpl(),
    advice: new UnavailableAdviceService(),
    changes: new ChangeBus(),
    clock: new SystemClock(),
    ids: new UuidGenerator()
  };
}

export class AppComposition {
  private static services: AppServices | null = null;

  static getServices(): AppServices {
    if (AppComposition.services === null) {
      AppComposition.services = createAppServices();
    }
    return AppComposition.services;
  }
}
