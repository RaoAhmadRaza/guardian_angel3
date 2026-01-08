
import React from 'react';
import { ReadingPreferences, Category } from '../types';
import { TopNav } from '../components/TopNav';
import { Icons, COLORS } from '../constants';

interface CaregiverSettingsProps {
  preferences: ReadingPreferences;
  onBack: () => void;
  onUpdate: (prefs: ReadingPreferences) => void;
}

export const CaregiverSettings: React.FC<CaregiverSettingsProps> = ({ preferences, onBack, onUpdate }) => {
  const toggleCategory = (cat: Category) => {
    const newCats = preferences.allowedCategories.includes(cat)
      ? preferences.allowedCategories.filter(c => c !== cat)
      : [...preferences.allowedCategories, cat];
    onUpdate({ ...preferences, allowedCategories: newCats });
  };

  return (
    <div className={`min-h-screen ${COLORS.bgPrimary} flex flex-col`}>
      <TopNav title="Settings" onBack={onBack} />
      
      <main className="flex-1 p-5 max-w-[600px] mx-auto w-full space-y-8">
        <section>
          <h3 className={`text-[13px] font-semibold mb-2 ml-4 uppercase ${COLORS.textSecondary} tracking-wider`}>Newspaper Controls</h3>
          <div className={`${COLORS.surfacePrimary} rounded-[14px] overflow-hidden shadow-sm`}>
            <div className={`flex items-center justify-between p-4 border-b ${COLORS.borderSubtle}`}>
              <span className={`font-medium ${COLORS.textPrimary}`}>Enable Service</span>
              <button 
                onClick={() => onUpdate({ ...preferences, enabled: !preferences.enabled })}
                className={`w-12 h-7 rounded-full transition-all flex items-center px-1 ${preferences.enabled ? 'bg-[#34C759] justify-end' : 'bg-[#E9E9EB] dark:bg-[#39393D] justify-start'}`}
              >
                <div className="w-5 h-5 bg-white rounded-full shadow-md" />
              </button>
            </div>
            <div className={`flex items-center justify-between p-4`}>
              <span className={`font-medium ${COLORS.textPrimary}`}>Audio Reading</span>
              <button 
                onClick={() => onUpdate({ ...preferences, audioEnabled: !preferences.audioEnabled })}
                className={`w-12 h-7 rounded-full transition-all flex items-center px-1 ${preferences.audioEnabled ? 'bg-[#34C759] justify-end' : 'bg-[#E9E9EB] dark:bg-[#39393D] justify-start'}`}
              >
                <div className="w-5 h-5 bg-white rounded-full shadow-md" />
              </button>
            </div>
          </div>
        </section>

        <section>
          <h3 className={`text-[13px] font-semibold mb-2 ml-4 uppercase ${COLORS.textSecondary} tracking-wider`}>Topic Whitelist</h3>
          <div className={`${COLORS.surfacePrimary} rounded-[14px] overflow-hidden shadow-sm divide-y ${COLORS.borderSubtle}`}>
            {Object.values(Category).map(cat => (
              <button
                key={cat}
                onClick={() => toggleCategory(cat)}
                className="w-full flex items-center justify-between p-4 tap-scale text-left"
              >
                <span className={`font-medium ${COLORS.textPrimary}`}>{cat}</span>
                {preferences.allowedCategories.includes(cat) && (
                    <div className="text-[#007AFF]">
                        <Icons.Check />
                    </div>
                )}
              </button>
            ))}
          </div>
        </section>

        <section>
          <h3 className={`text-[13px] font-semibold mb-2 ml-4 uppercase ${COLORS.textSecondary} tracking-wider`}>Curation Threshold</h3>
          <div className={`${COLORS.surfacePrimary} rounded-[14px] p-5 shadow-sm`}>
            <div className="flex items-center justify-between mb-4">
                <span className={`font-medium ${COLORS.textPrimary}`}>Daily Limit</span>
                <span className={`font-bold text-[#007AFF]`}>{preferences.dailyLimit} stories</span>
            </div>
            <input 
              type="range" 
              min="3" 
              max="15" 
              step="1"
              value={preferences.dailyLimit}
              onChange={(e) => onUpdate({ ...preferences, dailyLimit: parseInt(e.target.value) })}
              className="w-full h-1 bg-gray-200 dark:bg-gray-700 rounded-lg appearance-none cursor-pointer accent-[#007AFF]"
            />
            <p className={`text-[12px] ${COLORS.textSecondary} mt-4`}>Lower limits are recommended for users who experience digital overwhelm.</p>
          </div>
        </section>

        <div className={`py-10 text-center ${COLORS.textTertiary} text-[12px] font-medium`}>
          Guardian Angel System Software 2.1.0
        </div>
      </main>
    </div>
  );
};
