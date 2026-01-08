
import React, { useState, useEffect } from 'react';
import { Article, FontSize } from '../types';
import { TopNav } from '../components/TopNav';
import { Icons, COLORS } from '../constants';
import { playArticleAudio } from '../services/geminiService';

interface ArticleReaderProps {
  article: Article;
  fontSize: FontSize;
  onBack: () => void;
  onToggleRead: (id: string) => void;
  onToggleSave: (id: string) => void;
}

export const ArticleReader: React.FC<ArticleReaderProps> = ({ article, fontSize, onBack, onToggleRead, onToggleSave }) => {
  const [isPlaying, setIsPlaying] = useState(false);
  const [audioSource, setAudioSource] = useState<AudioBufferSourceNode | null>(null);

  const getBodyTextSize = () => {
    if (fontSize === 'large') return 'text-[24px] leading-[1.6]';
    if (fontSize === 'extra-large') return 'text-[28px] leading-[1.7]';
    return 'text-[20px] leading-[1.6]';
  };

  const handleListen = async () => {
    if (isPlaying && audioSource) {
      audioSource.stop();
      setIsPlaying(false);
      setAudioSource(null);
    } else {
      setIsPlaying(true);
      const source = await playArticleAudio(article.content);
      if (source) {
        setAudioSource(source);
        source.onended = () => {
          setIsPlaying(false);
          setAudioSource(null);
        };
      } else {
        setIsPlaying(false);
      }
    }
  };

  useEffect(() => {
    return () => {
      if (audioSource) audioSource.stop();
    };
  }, [audioSource]);

  return (
    <div className={`min-h-screen ${COLORS.bgSecondary} flex flex-col`}>
      <TopNav 
        title={article.category} 
        onBack={onBack}
        onTextSizeClick={() => {}} 
      />
      
      <main className="flex-1 px-6 pt-10 pb-48 max-w-[700px] mx-auto w-full">
        <header className="mb-10 text-center">
          <p className={`text-[13px] font-bold ${COLORS.textSecondary} uppercase tracking-[0.2em] mb-4`}>{article.date}</p>
          <h1 className={`text-[36px] md:text-[44px] font-bold font-serif ${COLORS.textPrimary} leading-[1.1] tracking-tight mb-8`}>
            {article.title}
          </h1>
          <div className="w-16 h-[2px] bg-[#007AFF] mx-auto rounded-full opacity-20" />
        </header>

        <div className="rounded-[32px] overflow-hidden mb-12 shadow-ios">
          <img src={article.imageUrl} alt={article.title} className="w-full h-auto" />
        </div>

        <div className={`${getBodyTextSize()} ${COLORS.textPrimary} font-serif whitespace-pre-wrap selection:bg-[#007AFF]/10`}>
          {article.content}
        </div>
      </main>

      {/* Dynamic Action Island */}
      <div className="fixed bottom-8 left-0 right-0 px-6 z-[100]">
        <div className={`max-w-[440px] mx-auto flex items-center justify-between gap-2 p-2 rounded-[32px] ${COLORS.surfaceGlass} shadow-ios border ${COLORS.borderSubtle}`}>
          <button 
            onClick={handleListen}
            className={`flex-1 flex items-center justify-center gap-3 py-4 px-6 rounded-full tap-scale transition-all ${isPlaying ? 'bg-[#FF3B30] text-white shadow-lg' : `${COLORS.actionPrimaryBg} ${COLORS.actionPrimaryFg} shadow-lg`}`}
          >
            <Icons.Listen />
            <span className="font-bold text-[15px]">{isPlaying ? 'Stop' : 'Listen'}</span>
          </button>
          
          <div className="flex items-center gap-1">
            <button 
              onClick={() => onToggleSave(article.id)}
              className={`p-4 rounded-full tap-scale transition-all ${article.isSaved ? 'text-[#007AFF] bg-[#007AFF]/10' : `${COLORS.textSecondary} hover:bg-black/5 dark:hover:bg-white/5`}`}
            >
              <Icons.Save filled={!!article.isSaved} />
            </button>
            <button 
              onClick={() => onToggleRead(article.id)}
              className={`p-4 rounded-full tap-scale transition-all ${article.isRead ? 'text-[#34C759] bg-[#34C759]/10' : `${COLORS.textSecondary} hover:bg-black/5 dark:hover:bg-white/5`}`}
            >
              <Icons.Check />
            </button>
            <button className={`p-4 rounded-full tap-scale text-[#007AFF] hover:bg-black/5 dark:hover:bg-white/5`}>
              <Icons.Share />
            </button>
          </div>
        </div>
      </div>
    </div>
  );
};
