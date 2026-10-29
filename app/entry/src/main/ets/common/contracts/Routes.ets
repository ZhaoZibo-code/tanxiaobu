export enum RouteId {
  OVERVIEW = 'overview',
  RECORDS = 'records',
  STATISTICS = 'statistics',
  TASKS = 'tasks',
  PROFILE = 'profile',
  RECORD_CREATE = 'record_create',
  RECORD_DETAIL = 'record_detail',
  RECORD_EDIT = 'record_edit',
  KNOWLEDGE = 'knowledge',
  ARTICLE_DETAIL = 'article_detail',
  REWARDS = 'rewards',
  DATA_MANAGEMENT = 'data_management',
  ADVICE = 'advice'
}

export interface RouteRequest {
  route: RouteId;
  entityId: string | null;
}

export type Navigate = (request: RouteRequest) => void;
