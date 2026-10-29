import common from '@ohos.app.ability.common';
import picker from '@ohos.file.picker';
import fs from '@ohos.file.fs';
import util from '@ohos.util';
import { BackupCompatibility, BackupInspection, ExportArtifact, RestoreSummary } from '../../common/contracts/Backup';
import { BackupDocument, PersistenceGateway } from '../../common/contracts/Persistence';
import { StatisticsQuery } from '../../common/contracts/Statistics';
import { AppServices, BackupService } from '../../common/contracts/Services';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { reportToCsv } from './CsvReport';
import { readBackupFile } from './BackupFileReader';
import { priorResult, restoreSnapshot } from './BackupRestoreCore';

export class BackupExportService implements BackupService {
  private readonly context: common.UIAbilityContext;
  private readonly gateway: () => Promise<PersistenceGateway>;
  private readonly services: AppServices;
  constructor(context: common.UIAbilityContext, gateway: () => Promise<PersistenceGateway>, services: AppServices) {
    this.context = context; this.gateway = gateway; this.services = services;
  }

  private async save(name: string, mime: string, content: string): Promise<ExportArtifact> {
    const options = new picker.DocumentSaveOptions();
    options.newFileNames = [name];
    let uris: string[];
    try { uris = await new picker.DocumentViewPicker(this.context).save(options); }
    catch (_) { throw new AppError(ErrorCode.FILE_ACCESS_FAILED, '无法打开系统保存窗口。', true); }
    if (uris.length === 0) { throw new AppError(ErrorCode.FILE_ACCESS_FAILED, '未选择保存位置。'); }
    const byteLength = new util.TextEncoder().encodeInto(content).length;
    let file: fs.File | undefined = undefined;
    try {
      file = await fs.open(uris[0], fs.OpenMode.WRITE_ONLY | fs.OpenMode.TRUNC);
      const written = await fs.write(file.fd, content);
      if (written !== byteLength) { throw new Error('incomplete file write'); }
      return { uri: uris[0], fileName: name, mimeType: mime, byteLength: byteLength };
    } catch (_) {
      throw new AppError(ErrorCode.FILE_ACCESS_FAILED, '保存未完成，请重新选择位置重试。', true);
    } finally {
      if (file !== undefined) { await fs.close(file); }
    }
  }

  async exportBackup(): Promise<ExportArtifact> {
    const snapshot = await (await this.gateway()).read.getFullSnapshot();
    const document: BackupDocument = { schemaVersion: snapshot.schemaVersion, appVersion: '0.1.0',
      exportedAt: this.services.clock.nowMs(), records: snapshot.records, ledgerEntries: snapshot.ledgerEntries,
      taskRewardStates: snapshot.taskRewardStates, redemptions: snapshot.redemptions, operations: snapshot.operations,
      settings: snapshot.settings, feedback: snapshot.feedback };
    return await this.save(`碳足迹备份-${this.services.clock.today()}.json`, 'application/json', JSON.stringify(document));
  }

  async exportCsv(query: StatisticsQuery): Promise<ExportArtifact> {
    const report = await this.services.statistics.createReport(query);
    return await this.save(`碳足迹报表-${query.anchorDate}.csv`, 'text/csv', reportToCsv(report));
  }

  async inspectBackup(uri: string): Promise<BackupInspection> {
    const file = await readBackupFile(uri);
    const data = file.document;
    return { compatibility: BackupCompatibility.COMPATIBLE, schemaVersion: data.schemaVersion,
      appVersion: data.appVersion, recordCount: data.records.length, ledgerEntryCount: data.ledgerEntries.length,
      taskStateCount: data.taskRewardStates.length, redemptionCount: data.redemptions.length,
      warnings: ['恢复会替换本机已有数据，请先导出当前备份。'], canRestore: true, contentDigest: file.digest };
  }
  async restoreBackup(uri: string, digest: string, requestId: string): Promise<RestoreSummary> {
    if (!/^[0-9a-f]{64}$/.test(digest) || requestId.length === 0) {
      throw new AppError(ErrorCode.INVALID_INPUT, '恢复请求无效。');
    }
    const db = await this.gateway();
    const previous = await db.read.operations.getByRequestId(requestId);
    if (previous !== null) { return priorResult(previous, digest); }
    const file = await readBackupFile(uri, digest);
    return await restoreSnapshot(db, this.services, file.document, file.digest, requestId);
  }
}
