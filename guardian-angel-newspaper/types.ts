
export enum Category {
  World = 'World',
  Pakistan = 'Pakistan',
  Health = 'Health',
  Science = 'Science',
  Faith = 'Faith & Reflection',
  Positive = 'Positive Stories'
}

export interface Article {
  id: string;
  title: string;
  summary: string;
  content: string;
  category: Category;
  imageUrl: string;
  readingTime: string;
  date: string;
  isRead?: boolean;
  isSaved?: boolean;
}

export interface ReadingPreferences {
  enabled: boolean;
  allowedCategories: Category[];
  excludeTopics: string[];
  audioEnabled: boolean;
  dailyLimit: number;
}

export type FontSize = 'normal' | 'large' | 'extra-large';

export interface AppState {
  currentView: 'home' | 'article' | 'settings';
  selectedArticle?: Article;
  selectedCategory?: Category;
  fontSize: FontSize;
  preferences: ReadingPreferences;
}
