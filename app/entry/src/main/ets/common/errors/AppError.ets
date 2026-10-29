export enum ErrorCode {
  INVALID_INPUT = 'INVALID_INPUT',
  RULE_NOT_FOUND = 'RULE_NOT_FOUND',
  FACTOR_UNAVAILABLE = 'FACTOR_UNAVAILABLE',
  BASELINE_REQUIRED = 'BASELINE_REQUIRED',
  RECORD_NOT_FOUND = 'RECORD_NOT_FOUND',
  IDEMPOTENCY_CONFLICT = 'IDEMPOTENCY_CONFLICT',
  TASK_NOT_ELIGIBLE = 'TASK_NOT_ELIGIBLE',
  INVALID_TASK_PERIOD = 'INVALID_TASK_PERIOD',
  INSUFFICIENT_POINTS = 'INSUFFICIENT_POINTS',
  ALREADY_REDEEMED = 'ALREADY_REDEEMED',
  BACKUP_INVALID = 'BACKUP_INVALID',
  BACKUP_VERSION_UNSUPPORTED = 'BACKUP_VERSION_UNSUPPORTED',
  BACKUP_CHANGED = 'BACKUP_CHANGED',
  FILE_ACCESS_FAILED = 'FILE_ACCESS_FAILED',
  STORAGE_FAILED = 'STORAGE_FAILED',
  MODULE_NOT_READY = 'MODULE_NOT_READY'
}

export class AppError extends Error {
  readonly code: ErrorCode;
  readonly retryable: boolean;

  constructor(code: ErrorCode, message: string, retryable: boolean = false) {
    super(message);
    this.name = 'AppError';
    this.code = code;
    this.retryable = retryable;
  }
}

export function moduleNotReady(moduleName: string): AppError {
  return new AppError(ErrorCode.MODULE_NOT_READY, `${moduleName}尚未接入，当前不能读取或保存业务数据。`);
}

export function toAppError(error: Object): AppError {
  if (error instanceof AppError) {
    return error;
  }
  return new AppError(ErrorCode.STORAGE_FAILED, '操作未完成，请稍后重试。', true);
}

export function errorTitle(error: AppError): string {
  switch (error.code) {
    case ErrorCode.MODULE_NOT_READY:
      return '功能尚未就绪';
    case ErrorCode.INVALID_INPUT:
    case ErrorCode.BASELINE_REQUIRED:
    case ErrorCode.INVALID_TASK_PERIOD:
      return '请检查输入';
    case ErrorCode.BACKUP_CHANGED:
      return '请重新预览备份';
    case ErrorCode.INSUFFICIENT_POINTS:
      return '积分不足';
    default:
      return '暂时无法完成';
  }
}
