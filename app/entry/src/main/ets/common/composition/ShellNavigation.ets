import { RouteId, RouteRequest } from '../contracts/Routes';

export class ShellTab {
  readonly route: RouteId;
  readonly title: string;
  readonly mark: string;

  constructor(route: RouteId, title: string, mark: string) {
    this.route = route;
    this.title = title;
    this.mark = mark;
  }
}

/** Four tabs plus the AI button in the centre; 统计 is reached from 总览. */
export const MAIN_TABS: ShellTab[] = [
  new ShellTab(RouteId.OVERVIEW, '总览', '览'),
  new ShellTab(RouteId.RECORDS, '记录', '记'),
  new ShellTab(RouteId.TASKS, '任务', '任'),
  new ShellTab(RouteId.PROFILE, '我的', '我')
];

export function routeTitle(route: RouteId): string {
  switch (route) {
    case RouteId.OVERVIEW: return '总览';
    case RouteId.RECORDS: return '记录';
    case RouteId.STATISTICS: return '统计';
    case RouteId.TASKS: return '任务';
    case RouteId.PROFILE: return '我的';
    case RouteId.RECORD_CREATE: return '记录低碳行为';
    case RouteId.RECORD_DETAIL: return '记录详情';
    case RouteId.RECORD_EDIT: return '更正记录';
    case RouteId.KNOWLEDGE: return '低碳科普';
    case RouteId.ARTICLE_DETAIL: return '科普详情';
    case RouteId.REWARDS: return '虚拟奖励';
    case RouteId.DATA_MANAGEMENT: return '数据管理';
    case RouteId.ADVICE: return '低碳建议';
    default: return '碳足迹';
  }
}

export function rootRequest(route: RouteId): RouteRequest {
  return { route: route, entityId: null };
}
