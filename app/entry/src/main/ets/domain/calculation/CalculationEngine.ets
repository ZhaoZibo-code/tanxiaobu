import { CalculationInput, CalculationMode, CalculationPreview, CalculationRule,
  EvidenceStatus, FactorDefinition } from '../../common/contracts/Calculation';
import { AppError, ErrorCode } from '../../common/errors/AppError';
import { requireLocalDate } from '../../common/utils/Dates';
import { roundReductionGrams } from '../../common/utils/Display';
import { CalculationCatalog, cloneCatalog, cloneFactor, cloneRule, referencedFactors,
  validateCatalog } from './Catalog';

function normalizeInput(input: CalculationInput, rule: CalculationRule): CalculationInput {
  if (typeof input.quantity !== 'number' || !Number.isFinite(input.quantity) ||
    input.quantity < rule.minQuantity || input.quantity > rule.maxQuantity || input.unit !== rule.inputUnit ||
    typeof input.businessDate !== 'string' || typeof input.note !== 'string' ||
    typeof input.baselineConfirmed !== 'boolean') {
    throw new AppError(ErrorCode.INVALID_INPUT, '请检查数量、单位、日期及确认信息。');
  }
  requireLocalDate(input.businessDate);
  if ((rule.mode === CalculationMode.BASELINE_DIFFERENCE || rule.confirmationText.trim().length > 0) &&
    !input.baselineConfirmed) {
    throw new AppError(ErrorCode.BASELINE_REQUIRED, '请先阅读并确认此规则的基准和适用条件。');
  }
  return {
    ruleId: rule.id, quantity: input.quantity === 0 ? 0 : input.quantity, unit: rule.inputUnit,
    businessDate: input.businessDate, note: input.note.trim(), baselineConfirmed: input.baselineConfirmed
  };
}

function displayGrams(factor: FactorDefinition): string {
  if (factor.originalUnit.includes('CO2e/')) {
    return 'gCO₂e';
  }
  return factor.originalUnit.includes('CO2/') ? 'gCO₂' : 'g参考碳减排量';
}

function appendUnique(target: string[], additions: string[]): void {
  additions.forEach((value: string): void => {
    if (!target.includes(value)) {
      target.push(value);
    }
  });
}

export class CalculationEngine {
  private readonly catalog: CalculationCatalog;

  constructor(catalog: CalculationCatalog) {
    validateCatalog(catalog, false);
    this.catalog = cloneCatalog(catalog);
  }

  listRules(): CalculationRule[] {
    return this.catalog.rules.map((rule: CalculationRule): CalculationRule => cloneRule(rule));
  }

  preview(input: CalculationInput): CalculationPreview {
    if (input === null || typeof input !== 'object' || Array.isArray(input) ||
      typeof input.ruleId !== 'string' || input.ruleId.trim().length === 0) {
      throw new AppError(ErrorCode.INVALID_INPUT, '请选择有效的核算规则。');
    }
    const found = this.catalog.rules.find((item: CalculationRule): boolean => item.id === input.ruleId);
    if (found === undefined) {
      throw new AppError(ErrorCode.RULE_NOT_FOUND, '核算规则不存在，请重新选择。');
    }
    const rule = found as CalculationRule;
    const normalized = normalizeInput(input, rule);
    const factors = referencedFactors(this.catalog, rule);
    let coefficient: number = factors[0].gramsCo2ePerUnit;
    const gramsLabel = displayGrams(factors[0]);
    let formulaText: string = `${normalized.quantity} ${normalized.unit} × ${coefficient} ${gramsLabel}/${normalized.unit}`;
    if (rule.mode === CalculationMode.BASELINE_DIFFERENCE) {
      coefficient = factors[0].gramsCo2ePerUnit - factors[1].gramsCo2ePerUnit;
      formulaText = `${normalized.quantity} ${normalized.unit} × (${factors[0].gramsCo2ePerUnit} − ` +
        `${factors[1].gramsCo2ePerUnit}) ${gramsLabel}/${normalized.unit}`;
    }
    const unrounded = normalized.quantity * coefficient;
    const reductionGrams = roundReductionGrams(unrounded);
    formulaText += ` = ${unrounded} ${gramsLabel} → ${reductionGrams} ${gramsLabel}`;
    const steps: string[] = [`输入：${normalized.quantity} ${normalized.unit}，业务日期 ${normalized.businessDate}。`];
    factors.forEach((factor: FactorDefinition): void => {
      steps.push(`${factor.name}：${factor.originalValue} ${factor.originalUnit} = ` +
        `${factor.gramsCo2ePerUnit} ${displayGrams(factor)}/${factor.unit}；版本 ${factor.version}。`);
    });
    steps.push(rule.mode === CalculationMode.DIRECT_REDUCTION ? '数量乘直接减排系数，不再扣除一次基准。' :
      '先算基准因子减实际因子，再乘同一数量。');
    steps.push(`中间结果不舍入：${unrounded} ${gramsLabel}；仅在本条末尾舍入为 ${reductionGrams} ${gramsLabel}（半克远离零）。`);
    const assumptions = rule.assumptions.slice();
    const warnings: string[] = ['本结果为给定边界下的条件估算，不是核证减排量或可交易碳信用。'];
    factors.forEach((factor: FactorDefinition): void => {
      appendUnique(assumptions, factor.assumptions);
      appendUnique(warnings, [`适用地区：${factor.source.region}。`, `核算边界：${factor.source.boundary}`, factor.source.notes]);
      if (factor.evidenceStatus === EvidenceStatus.DEVELOPMENT_FIXTURE) {
        appendUnique(warnings, ['开发测试因子，仅验证数学，不能作为正式减排依据。']);
      }
    });
    if (reductionGrams < 0) {
      warnings.push('结果为负，表示相对基准的排放增加，不计入正向任务。');
    } else if (reductionGrams === 0) {
      warnings.push('结果按整数克计为零，不计入正向任务。');
    }
    return {
      input: normalized, category: rule.category, ruleName: rule.name, reductionGrams: reductionGrams,
      formulaText: formulaText, steps: steps, assumptions: assumptions, warnings: warnings,
      factorSnapshot: {
        rule: cloneRule(rule), factors: factors.map((factor: FactorDefinition): FactorDefinition => cloneFactor(factor))
      },
      eligibleForPositiveTasks: reductionGrams > 0
    };
  }
}
