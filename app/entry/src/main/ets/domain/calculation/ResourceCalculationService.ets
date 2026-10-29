import resourceManager from '@ohos.resourceManager';
import util from '@ohos.util';
import { CalculationService } from '../../common/contracts/Services';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { parseDocumentedCatalog } from './Catalog';
import { DocumentedCalculationService } from './DocumentedCalculationService';

export const CALCULATION_CATALOG_PATH: string = 'factors/catalog-v1.2.json';

export async function loadCalculationService(manager: resourceManager.ResourceManager): Promise<CalculationService> {
  let content: Uint8Array;
  try {
    content = await manager.getRawFileContent(CALCULATION_CATALOG_PATH);
  } catch (error) {
    throw new AppError(ErrorCode.FILE_ACCESS_FAILED, '无法读取本地核算资料，请稍后重试。', true);
  }
  let text: string;
  try {
    text = util.TextDecoder.create('utf-8', { fatal: true }).decodeToString(content);
  } catch (error) {
    throw new AppError(ErrorCode.FACTOR_UNAVAILABLE, '本地核算资料编码无效。');
  }
  return new DocumentedCalculationService(parseDocumentedCatalog(text));
}
