import fs from '@ohos.file.fs';
import util from '@ohos.util';
import cryptoFramework from '@ohos.security.cryptoFramework';
import { BackupDocument } from '../../common/contracts/Persistence';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { validateBackupDocument } from './BackupValidation';

const MAX_BYTES: number = 8 * 1024 * 1024;
export interface ReadBackup { document: BackupDocument; digest: string; byteLength: number; }

export async function readBackupFile(uri: string, expectedDigest: string = ''): Promise<ReadBackup> {
  let file: fs.File | undefined = undefined;
  let bytes: Uint8Array;
  try {
    file = await fs.open(uri, fs.OpenMode.READ_ONLY);
    const size = (await fs.stat(file.fd)).size;
    if (!Number.isSafeInteger(size) || size <= 0 || size > MAX_BYTES) {
      throw new AppError(ErrorCode.BACKUP_INVALID, '备份文件为空或超过 8 MB。');
    }
    const buffer = new ArrayBuffer(size);
    const read = await fs.read(file.fd, buffer);
    if (read !== size || (await fs.stat(file.fd)).size !== size) {
      throw new AppError(ErrorCode.BACKUP_INVALID, '备份文件读取不完整，请重试。');
    }
    bytes = new Uint8Array(buffer);
  } catch (error) {
    if (error instanceof AppError) { throw error; }
    throw new AppError(ErrorCode.FILE_ACCESS_FAILED, '无法读取备份文件，请重新选择。', true);
  } finally { if (file !== undefined) { await fs.close(file); } }
  const hash = cryptoFramework.createMd('SHA256');
  await hash.update({ data: bytes });
  const digest = await hash.digest();
  let hex = '';
  digest.data.forEach((item: number) => { hex += item.toString(16).padStart(2, '0'); });
  if (expectedDigest.length > 0 && hex !== expectedDigest) {
    throw new AppError(ErrorCode.BACKUP_CHANGED, '备份内容已改变，请重新预览。');
  }
  let document: BackupDocument;
  try {
    const text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(bytes);
    document = JSON.parse(text) as BackupDocument;
  } catch (_) { throw new AppError(ErrorCode.BACKUP_INVALID, '备份不是有效的 UTF-8 JSON。'); }
  validateBackupDocument(document);
  return { document: document, digest: hex, byteLength: bytes.length };
}
