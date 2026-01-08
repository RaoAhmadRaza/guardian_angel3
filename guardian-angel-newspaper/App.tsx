
import React, { useState, useEffect, useCallback } from 'react';
import { AppState, Article, Category, ReadingPreferences, FontSize } from './types';
import { Home } from './views/Home';
import { ArticleReader } from './views/ArticleReader';
import { CaregiverSettings } from './views/CaregiverSettings';
import { generateDailyEdition } from './services/geminiService';
import { COLORS } from './constants';

const INITIAL_PREFERENCES: ReadingPreferences = {
  enabled: true,
  allowedCategories: Object.values(Category),
  excludeTopics: ['Politics', 'Crime', 'Accidents'],
  audioEnabled: true,
  dailyLimit: 8
};

const App: React.FC = () => {
  const [state, setState] = useState<AppState>({
    currentView: 'home',
    fontSize: 'normal',
    preferences: INITIAL_PREFERENCES
  });
  
  const [articles, setArticles] = useState<Article[]>([]);
  const [loading, setLoading] = useState(true);

  const loadDailyNews = useCallback(async () => {
    setLoading(true);
    const news = await generateDailyEdition(state.preferences.allowedCategories);
    setArticles(news);
    setLoading(false);
  }, [state.preferences.allowedCategories]);

  useEffect(() => {
    loadDailyNews();
  }, []);

  const toggleFontSize = () => {
    setState(prev => {
      const sizes: FontSize[] = ['normal', 'large', 'extra-large'];
      const nextIndex = (sizes.indexOf(prev.fontSize) + 1) % sizes.length;
      return { ...prev, fontSize: sizes[nextIndex] };
    });
  };

  const handleArticleToggleRead = (id: string) => {
    setArticles(prev => prev.map(a => a.id === id ? { ...a, isRead: !a.isRead } : a));
  };

  const handleArticleToggleSave = (id: string) => {
    setArticles(prev => prev.map(a => a.id === id ? { ...a, isSaved: !a.isSaved } : a));
  };

  if (loading) {
    return (
      <div className={`h-screen w-full flex flex-col items-center justify-center ${COLORS.bgPrimary} p-10`}>
        <div className="w-10 h-10 border-2 border-[#007AFF]/20 border-t-[#007AFF] rounded-full animate-spin mb-8"></div>
        <div className="text-center space-y-2">
            <h2 className={`text-[20px] font-bold ${COLORS.textPrimary}`}>Preparing Morning Edition</h2>
            <p className={`${COLORS.textSecondary} text-[15px] max-w-[240px] leading-relaxed`}>Curating a peaceful reading experience for you.</p>
        </div>
      </div>
    );
  }

  const renderView = () => {
    switch (state.currentView) {
      case 'home':
        return (
          <Home 
            articles={articles}
            fontSize={state.fontSize}
            selectedCategory={state.selectedCategory}
            onCategorySelect={(cat) => setState(prev => ({ ...prev, selectedCategory: cat }))}
            onArticleSelect={(article) => setState(prev => ({ ...prev, currentView: 'article', selectedArticle: article }))}
            onOpenSettings={() => setState(prev => ({ ...prev, currentView: 'settings' }))}
            onTextSizeToggle={toggleFontSize}
          />
        );
      case 'article':
        return state.selectedArticle ? (
          <ArticleReader 
            article={state.selectedArticle}
            fontSize={state.fontSize}
            onBack={() => setState(prev => ({ ...prev, currentView: 'home', selectedArticle: undefined }))}
            onToggleRead={handleArticleToggleRead}
            onToggleSave={handleArticleToggleSave}
          />
        ) : null;
      case 'settings':
        return (
          <CaregiverSettings 
            preferences={state.preferences}
            onBack={() => setState(prev => ({ ...prev, currentView: 'home' }))}
            onUpdate={(prefs) => setState(prev => ({ ...prev, preferences: prefs }))}
          />
        );
      default:
        return null;
    }
  };

  return (
    <div className={`max-w-[100vw] overflow-x-hidden min-h-screen ${COLORS.bgPrimary}`}>
      {renderView()}
    </div>
  );
};

export default App;
