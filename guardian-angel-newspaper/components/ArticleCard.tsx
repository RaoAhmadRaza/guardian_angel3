
import React from 'react';
import { Article, FontSize } from '../types';
import { COLORS } from '../constants';

interface ArticleCardProps {
  article: Article;
  onClick: () => void;
  isHero?: boolean;
  fontSize: FontSize;
}

export const ArticleCard: React.FC<ArticleCardProps> = ({ article, onClick, isHero, fontSize }) => {
  const getTextSize = () => {
    if (fontSize === 'large') return 'text-[19px]';
    if (fontSize === 'extra-large') return 'text-[22px]';
    return 'text-[17px]';
  };

  const getTitleSize = () => {
    if (fontSize === 'large') return isHero ? 'text-[32px]' : 'text-[24px]';
    if (fontSize === 'extra-large') return isHero ? 'text-[38px]' : 'text-[28px]';
    return isHero ? 'text-[28px]' : 'text-[20px]';
  };

  return (
    <div 
      onClick={onClick}
      className={`group cursor-pointer ${COLORS.surfacePrimary} rounded-[28px] overflow-hidden tap-scale shadow-ios mb-6 transition-all duration-300 ${isHero ? 'flex flex-col' : 'flex flex-row items-center'}`}
    >
      <div className={`${isHero ? 'h-[240px] w-full' : 'h-[100px] w-[100px] m-4 shrink-0 rounded-[18px]'} bg-black/5 dark:bg-white/5 overflow-hidden relative`}>
        <img 
          src={article.imageUrl} 
          alt={article.title}
          className="w-full h-full object-cover group-hover:scale-105 transition-transform duration-1000"
        />
        {/* Subtle inner overlay for depth */}
        <div className="absolute inset-0 bg-black/[0.02] dark:bg-white/[0.02] pointer-events-none" />
      </div>
      
      <div className={`${isHero ? 'p-6 pt-5' : 'pr-6 py-4 flex-1'}`}>
        <div className="flex items-center gap-2 mb-2">
          <span className={`text-[12px] font-bold ${COLORS.textSecondary} uppercase tracking-[0.05em]`}>
            {article.category}
          </span>
          <span className={`text-[12px] ${COLORS.textTertiary}`}>• {article.readingTime}</span>
        </div>
        
        <h3 className={`font-bold ${getTitleSize()} ${COLORS.textPrimary} tracking-tight leading-[1.2] mb-2 font-serif`}>
          {article.title}
        </h3>
        
        {(isHero || fontSize !== 'normal') && (
          <p className={`${getTextSize()} ${COLORS.textSecondary} line-clamp-2 leading-[1.5] font-normal`}>
            {article.summary}
          </p>
        )}
      </div>
    </div>
  );
};
