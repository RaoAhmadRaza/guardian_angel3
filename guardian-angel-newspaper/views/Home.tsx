
import React from 'react';
import { Article, Category, FontSize } from '../types';
import { TopNav } from '../components/TopNav';
import { CategoryRow } from '../components/CategoryRow';
import { ArticleCard } from '../components/ArticleCard';
import { Icons, COLORS } from '../constants';

interface HomeProps {
  articles: Article[];
  fontSize: FontSize;
  selectedCategory?: Category;
  onCategorySelect: (cat: Category | undefined) => void;
  onArticleSelect: (article: Article) => void;
  onOpenSettings: () => void;
  onTextSizeToggle: () => void;
}

export const Home: React.FC<HomeProps> = ({ 
  articles, 
  fontSize, 
  selectedCategory, 
  onCategorySelect, 
  onArticleSelect, 
  onOpenSettings,
  onTextSizeToggle
}) => {
  const filteredArticles = selectedCategory 
    ? articles.filter(a => a.category === selectedCategory)
    : articles;

  const dateStr = new Date().toLocaleDateString('en-GB', { 
    weekday: 'long', 
    day: 'numeric', 
    month: 'long' 
  });

  return (
    <div className={`min-h-screen ${COLORS.bgPrimary} flex flex-col`}>
      <TopNav 
        title="Guardian Angel" 
        onTextSizeClick={onTextSizeToggle}
        rightAction={
          <button 
            onClick={onOpenSettings}
            className={`p-2 rounded-full tap-scale ${COLORS.textLink}`}
          >
            <Icons.Settings />
          </button>
        }
      />
      
      <main className="flex-1 px-5 py-8 max-w-[800px] mx-auto w-full">
        <header className="mb-8">
          <p className={`${COLORS.textSecondary} font-bold text-[13px] uppercase tracking-[0.15em] mb-1`}>Morning Edition</p>
          <h2 className={`text-[34px] md:text-[42px] font-bold ${COLORS.textPrimary} tracking-tight leading-tight`}>
            {dateStr}
          </h2>
        </header>

        <CategoryRow 
          categories={Object.values(Category)} 
          selected={selectedCategory}
          onSelect={onCategorySelect}
        />

        <div className="mt-2">
          {filteredArticles.length > 0 ? (
            <div className="space-y-4">
              <ArticleCard 
                article={filteredArticles[0]} 
                isHero={!selectedCategory}
                onClick={() => onArticleSelect(filteredArticles[0])}
                fontSize={fontSize}
              />

              <div className="grid grid-cols-1 md:grid-cols-2 gap-x-6">
                {filteredArticles.slice(1).map(article => (
                  <ArticleCard 
                    key={article.id} 
                    article={article} 
                    onClick={() => onArticleSelect(article)}
                    fontSize={fontSize}
                  />
                ))}
              </div>
            </div>
          ) : (
            <div className="flex flex-col items-center justify-center py-40 text-center">
              <div className={`w-12 h-12 border-2 border-[#007AFF]/20 border-t-[#007AFF] rounded-full animate-spin mb-6`}></div>
              <p className={`text-[17px] font-medium ${COLORS.textSecondary} font-serif italic`}>Reviewing global events...</p>
            </div>
          )}
        </div>
      </main>
      
      <footer className="py-16 text-center">
          <p className={`${COLORS.textTertiary} text-[11px] font-bold tracking-[0.3em] uppercase`}>Guardian Angel Editorial</p>
          <div className="mt-4 flex justify-center gap-4">
              <div className="w-1 h-1 rounded-full bg-gray-300" />
              <div className="w-1 h-1 rounded-full bg-gray-300" />
              <div className="w-1 h-1 rounded-full bg-gray-300" />
          </div>
      </footer>
    </div>
  );
};
