
import React from 'react';
import { Category } from '../types';
import { COLORS } from '../constants';

interface CategoryRowProps {
  categories: Category[];
  selected?: Category;
  onSelect: (category: Category | undefined) => void;
}

export const CategoryRow: React.FC<CategoryRowProps> = ({ categories, selected, onSelect }) => {
  return (
    <div className="flex items-center gap-2 overflow-x-auto no-scrollbar py-6 px-1">
      <button
        onClick={() => onSelect(undefined)}
        className={`shrink-0 px-5 py-2 rounded-full text-[14px] font-semibold tap-scale transition-all duration-300 ${
          !selected 
            ? `${COLORS.actionPrimaryBg} ${COLORS.actionPrimaryFg}` 
            : `${COLORS.bgSecondary} ${COLORS.textPrimary} border ${COLORS.borderSubtle}`
        }`}
      >
        For You
      </button>
      {categories.map((cat) => (
        <button
          key={cat}
          onClick={() => onSelect(cat)}
          className={`shrink-0 px-5 py-2 rounded-full text-[14px] font-semibold tap-scale transition-all duration-300 ${
            selected === cat 
              ? `${COLORS.actionPrimaryBg} ${COLORS.actionPrimaryFg}` 
              : `${COLORS.bgSecondary} ${COLORS.textPrimary} border ${COLORS.borderSubtle}`
          }`}
        >
          {cat}
        </button>
      ))}
    </div>
  );
};
