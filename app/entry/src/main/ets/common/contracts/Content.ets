import { Category, Id, LocalDate, TimestampMs } from './Common';

export interface ArticleSummary {
  id: Id;
  title: string;
  summary: string;
  category: Category;
}

export interface ArticleSection {
  heading: string;
  body: string;
  localImage: string | null;
}

export interface ArticleSource {
  title: string;
  url: string;
  publisher: string;
}

export interface Article extends ArticleSummary {
  sections: ArticleSection[];
  sources: ArticleSource[];
  updatedDate: LocalDate;
  localImage: string | null;
}

export enum SuggestionFeedback {
  ACCEPTED = 'accepted',
  DISMISSED = 'dismissed'
}

export interface SuggestionEstimate {
  reductionGrams: number;
  assumptions: string[];
}

export interface Suggestion {
  id: Id;
  title: string;
  reason: string;
  evidenceSummary: string;
  proposedRuleId: Id | null;
  estimate: SuggestionEstimate | null;
  actionLabel: string;
  generatedForDate: LocalDate;
}

export interface SuggestionFeedbackEntry {
  suggestionId: Id;
  feedback: SuggestionFeedback;
  updatedAt: TimestampMs;
}

export interface BusinessSetting {
  key: string;
  valueJson: string;
  updatedAt: TimestampMs;
}
