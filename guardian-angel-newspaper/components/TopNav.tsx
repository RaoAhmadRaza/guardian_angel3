
import React from 'react';
import { Icons, COLORS } from '../constants';

interface TopNavProps {
  title: string;
  onBack?: () => void;
  onTextSizeClick?: () => void;
  rightAction?: React.ReactNode;
}

export const TopNav: React.FC<TopNavProps> = ({ title, onBack, onTextSizeClick, rightAction }) => {
  return (
    <nav className={`sticky top-0 z-[100] ${COLORS.surfaceGlass} border-b ${COLORS.borderSubtle} px-4 h-[64px] flex items-center justify-between`}>
      <div className="w-12 flex justify-start">
        {onBack && (
          <button 
            onClick={onBack}
            className={`p-2 rounded-full tap-scale ${COLORS.textLink}`}
          >
            <Icons.Back />
          </button>
        )}
      </div>
      
      <div className="flex-1 flex justify-center px-4">
        <h1 className={`text-[17px] font-bold tracking-tight ${COLORS.textPrimary} line-clamp-1 text-center font-serif italic`}>
          {title}
        </h1>
      </div>
      
      <div className="w-12 flex justify-end gap-1">
        {onTextSizeClick && (
          <button 
            onClick={onTextSizeClick}
            className={`p-2 rounded-full tap-scale ${COLORS.textLink}`}
            title="Appearance"
          >
            <Icons.TextSize />
          </button>
        )}
        {rightAction}
      </div>
    </nav>
  );
};
