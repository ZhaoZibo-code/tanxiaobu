export interface ExportArtifact {
  uri: string;
  fileName: string;
  mimeType: string;
  byteLength: number;
}

export enum BackupCompatibility {
  COMPATIBLE = 'compatible',
  UNSUPPORTED_VERSION = 'unsupported_version',
  INVALID = 'invalid'
}

export interface BackupInspection {
  compatibility: BackupCompatibility;
  schemaVersion: number;
  appVersion: string;
  recordCount: number;
  ledgerEntryCount: number;
  taskStateCount: number;
  redemptionCount: number;
  warnings: string[];
  canRestore: boolean;
  contentDigest: string;
}

export interface RestoreSummary {
  recordCount: number;
  ledgerEntryCount: number;
  taskStateCount: number;
  redemptionCount: number;
  settingCount: number;
  feedbackCount: number;
  operationCount: number;
  finalPointsBalance: number;
}
