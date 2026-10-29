import { StatisticsReport } from '../../common/contracts/Statistics';
import { BehaviorRecord } from '../../common/contracts/Records';
import { categoryLabel } from '../../common/utils/Display';

function csvText(value: string): string {
  const safe = /^[\s]*[=+\-@\t\r]/.test(value) ? `'${value}` : value;
  return `"${safe.replace(/"/g, '""')}"`;
}

export function reportToCsv(report: StatisticsReport): string {
  const lines: string[] = ['业务日期,类别,行动,数量,单位,减排量(克),备注,计算依据'];
  report.records.forEach((record: BehaviorRecord) => {
    lines.push([csvText(record.businessDate), csvText(categoryLabel(record.category)), csvText(record.factorSnapshot.rule.name),
      `${record.quantity}`, csvText(record.unit), `${record.reductionGrams}`, csvText(record.note), csvText(record.formulaText)].join(','));
  });
  lines.push('');
  lines.push(`${csvText('统计期间')},${csvText(report.statistics.startDateInclusive)},${csvText(`${report.statistics.endDateExclusive}（不含结束日）`)}`);
  lines.push(`${csvText('净减排合计(克)')},${report.statistics.totalReductionGrams}`);
  lines.push(`${csvText('记录数')},${report.statistics.recordCount}`);
  return `\uFEFF${lines.join('\r\n')}\r\n`;
}
