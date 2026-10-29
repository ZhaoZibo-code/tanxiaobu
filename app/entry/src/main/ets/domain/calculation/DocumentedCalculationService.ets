import { CalculationInput, CalculationPreview, CalculationRule } from '../../common/contracts/Calculation';
import { CalculationService } from '../../common/contracts/Services';
import { CalculationCatalog, validateCatalog } from './Catalog';
import { CalculationEngine } from './CalculationEngine';

export class DocumentedCalculationService implements CalculationService {
  private readonly engine: CalculationEngine;

  constructor(catalog: CalculationCatalog) {
    validateCatalog(catalog, true);
    this.engine = new CalculationEngine(catalog);
  }

  async listRules(): Promise<CalculationRule[]> {
    return this.engine.listRules();
  }

  async preview(input: CalculationInput): Promise<CalculationPreview> {
    return this.engine.preview(input);
  }
}
