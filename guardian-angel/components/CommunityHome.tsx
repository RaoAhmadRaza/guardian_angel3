import React, { useState, useEffect } from 'react';
import { Sun, Heart, BookOpen, Coffee, Users, Info, ArrowRight, ChevronLeft, Sparkles, MessageCircle, Zap, Image as ImageIcon, Flame, ShieldCheck, Bell, Calendar as CalendarIcon } from 'lucide-react';

interface CommunityHomeProps {
  onSelectCommunity: (id: string) => void;
  onBack: () => void;
  isEmergency?: boolean;
}

export const CommunityHome: React.FC<CommunityHomeProps> = ({ onSelectCommunity, onBack, isEmergency }) => {
  const [timeLeft, setTimeLeft] = useState(15730); // Start with ~4h 22m

  useEffect(() => {
    const timer = setInterval(() => {
        setTimeLeft(prev => (prev > 0 ? prev - 1 : 0));
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatCountdown = (seconds: number) => {
    const h = Math.floor(seconds / 3600);
    const m = Math.floor((seconds % 3600) / 60);
    const s = seconds % 60;
    return `${h.toString().padStart(2, '0')}h : ${m.toString().padStart(2, '0')}m : ${s.toString().padStart(2, '0')}s`;
  };
  
  const renderAvatarPile = (count: number) => (
      <div className="flex items-center -space-x-2.5 overflow-hidden">
          <img src="https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=64&h=64&fit=crop&crop=faces" className="w-6 h-6 rounded-full border-[1.5px] border-white object-cover" />
          <img src="https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=64&h=64&fit=crop&crop=faces" className="w-6 h-6 rounded-full border-[1.5px] border-white object-cover" />
          <img src="https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=64&h=64&fit=crop&crop=faces" className="w-6 h-6 rounded-full border-[1.5px] border-white object-cover" />
          <div className="w-6 h-6 rounded-full border-[1.5px] border-white bg-gray-100 flex items-center justify-center text-[9px] font-bold text-gray-500">
              +{count}
          </div>
      </div>
  );

  if (isEmergency) {
      return (
          <div className="h-full flex flex-col items-center justify-center p-8 text-center bg-gray-100">
              <div className="w-16 h-16 bg-gray-200 rounded-full flex items-center justify-center mb-4">
                  <Users className="w-8 h-8 text-gray-400" />
              </div>
              <h2 className="text-xl font-bold text-gray-500 mb-2">Community Paused</h2>
              <p className="text-gray-400">Community features are unavailable while Emergency Mode is active.</p>
              <button onClick={onBack} className="mt-8 text-blue-600 font-medium">Return to Chats</button>
          </div>
      )
  }

  return (
    <div className="h-full flex flex-col bg-[#f2f2f7] safe-area-top safe-area-bottom slide-in-right fixed inset-0 z-20 font-sans">
      {/* Header */}
      <header className="px-5 py-3 bg-[#f2f2f7]/95 backdrop-blur-xl sticky top-0 z-30 transition-all border-b border-gray-200/50">
        <button 
          onClick={onBack} 
          className="flex items-center gap-1 text-blue-600 mb-2 active:opacity-50 transition-opacity"
        >
            <ChevronLeft className="w-7 h-7 -ml-2" />
            <span className="text-[17px] font-medium">Chats</span>
        </button>
        <div className="flex justify-between items-end px-1">
            <div>
                <h1 className="text-[34px] font-bold text-black tracking-tight leading-none">Community</h1>
            </div>
            <div className="w-9 h-9 bg-gray-200/50 rounded-full flex items-center justify-center text-gray-500 shadow-sm">
                <Users className="w-5 h-5 fill-current" />
            </div>
        </div>
      </header>

      {/* Main Scrollable Content */}
      <div className="flex-1 overflow-y-auto px-5 pb-24 no-scrollbar pt-4">
        
        {/* 1. STORIES RAIL (Daily Moments) */}
        <div className="mb-8">
            <div className="flex gap-5 overflow-x-auto no-scrollbar py-1 snap-x -mx-5 px-5">
                 {[
                    { name: 'Dr. Emily', img: 'https://images.unsplash.com/photo-1559839734-2b71ea860632?w=120&h=120&fit=crop', isNew: true },
                    { name: 'Moderator', img: 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=120&h=120&fit=crop', isNew: true },
                    { name: 'Highlights', img: 'https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?w=120&h=120&fit=crop', isNew: false },
                    { name: 'Tips', img: 'https://images.unsplash.com/photo-1544367563-12123d8966cd?w=120&h=120&fit=crop', isNew: false },
                    { name: 'Events', img: 'https://images.unsplash.com/photo-1511632765486-a01980e01a18?w=120&h=120&fit=crop', isNew: false },
                 ].map((story, i) => (
                     <button key={i} className="flex flex-col items-center gap-1.5 snap-start shrink-0 group">
                         <div className={`p-[3px] rounded-full transition-transform duration-300 group-active:scale-95 ${story.isNew ? 'bg-gradient-to-tr from-amber-400 to-orange-500' : 'bg-gray-200'}`}>
                             <div className="p-[2px] bg-[#f2f2f7] rounded-full">
                                 <img src={story.img} className="w-14 h-14 rounded-full object-cover" />
                             </div>
                         </div>
                         <span className={`text-[11px] font-medium ${story.isNew ? 'text-gray-900 font-semibold' : 'text-gray-500'}`}>{story.name}</span>
                     </button>
                 ))}
            </div>
        </div>

        {/* 2. HERO CAROUSEL: "Featured Today" with Parallax */}
        <div className="mb-6 animate-in slide-in-from-bottom-4 duration-500 relative group cursor-pointer" onClick={() => onSelectCommunity('comm-grat')}>
            <div className="flex justify-between items-baseline mb-3 px-1">
                <p className="text-[13px] font-bold text-gray-400 uppercase tracking-wide">Featured Today</p>
            </div>
            
            {/* 3D Tilt Container */}
            <div className="w-full relative overflow-hidden rounded-[32px] aspect-[4/3] shadow-lg bg-black transform transition-transform duration-300 active:scale-[0.98]">
                {/* Parallax Background Layer */}
                <div className="absolute inset-0 transition-transform duration-700 ease-out group-active:scale-110 group-active:translate-y-2">
                    <div className="absolute inset-0 bg-gradient-to-br from-amber-400/80 to-orange-600/80 z-10 mix-blend-multiply" />
                    <img 
                        src="https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=800" 
                        className="absolute inset-0 w-full h-full object-cover opacity-90"
                    />
                </div>
                
                {/* Content Overlay (Relative Z-Index to stay sharp) */}
                <div className="absolute inset-0 p-6 flex flex-col justify-between z-20">
                    <div className="flex justify-between items-start">
                        <div className="bg-white/20 backdrop-blur-md px-3 py-1 rounded-full flex items-center gap-1.5 border border-white/20 shadow-sm">
                            <Sparkles className="w-3.5 h-3.5 text-yellow-100" />
                            <span className="text-[11px] font-bold text-white tracking-wide">Daily Prompt</span>
                        </div>
                        <div className="bg-black/20 backdrop-blur-md rounded-full px-2 py-1 flex items-center gap-1 border border-white/10">
                            <Users className="w-3 h-3 text-white/80" />
                            <span className="text-[10px] font-bold text-white">24 Online</span>
                        </div>
                    </div>

                    <div className="transform transition-transform duration-500 group-active:translate-y-[-4px]">
                        <div className="w-12 h-12 rounded-2xl bg-white/20 backdrop-blur-md flex items-center justify-center text-white mb-3 shadow-inner border border-white/20">
                            <Coffee className="w-6 h-6" />
                        </div>
                        <h2 className="text-3xl font-bold text-white leading-tight mb-2 shadow-sm">Daily Gratitude</h2>
                        <p className="text-orange-50 text-sm font-medium mb-5 line-clamp-1 drop-shadow-sm">"What made you smile this morning?"</p>
                        
                        <div className="flex items-center justify-between">
                             {renderAvatarPile(18)}
                             <div className="bg-white text-orange-600 text-[12px] font-bold px-4 py-2 rounded-full shadow-lg shadow-black/10">
                                 Join Discussion
                             </div>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        {/* 3. FILTER PILLS (Standard Scroll) */}
        <div className="mb-6 -mx-5 px-5 pt-2">
             <div className="flex gap-2 overflow-x-auto no-scrollbar snap-x">
                {['All', 'Active Now', 'Quiet', 'Reading', 'Outdoors', 'Wellness'].map((filter, i) => (
                    <button 
                        key={i} 
                        className={`px-4 py-2 rounded-full text-[13px] font-bold border snap-start whitespace-nowrap transition-all active:scale-95 shadow-sm
                            ${i === 0 
                                ? 'bg-black/80 text-white border-black/80' 
                                : 'bg-white text-gray-600 border-gray-200/50 hover:bg-white hover:border-gray-300'
                            }
                        `}
                    >
                        {filter}
                    </button>
                ))}
            </div>
        </div>
        
        {/* MASONRY GRID LAYOUT */}
        <div className="grid grid-cols-2 gap-4">

            {/* 4. UPCOMING EVENT COUNTDOWN WIDGET */}
            <div className="col-span-2 bg-[#1c1c1e] rounded-[28px] p-1 flex items-center justify-between shadow-lg overflow-hidden relative group active:scale-[0.99] transition-transform">
                {/* Ambient Glow */}
                <div className="absolute top-0 right-0 w-64 h-64 bg-blue-600/20 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
                
                <div className="relative z-10 flex items-center gap-4 pl-4 py-3">
                        <div className="w-12 h-12 bg-[#2c2c2e] rounded-2xl flex flex-col items-center justify-center border border-white/10 shadow-inner shrink-0">
                            <span className="text-[8px] font-bold text-red-400 uppercase">SUN</span>
                            <span className="text-xl font-bold text-white leading-none">24</span>
                        </div>
                        <div>
                            <p className="text-[10px] font-bold text-blue-300 uppercase tracking-wider mb-0.5">Upcoming Event</p>
                            <h3 className="text-sm font-bold text-white mb-1">Weekly Reflection</h3>
                            <div className="flex items-center gap-2">
                                <span className="text-[11px] text-gray-400 font-mono bg-black/40 px-1.5 py-0.5 rounded border border-white/5">
                                    {formatCountdown(timeLeft)}
                                </span>
                                <span className="text-[11px] text-gray-500">with Dr. Chen</span>
                            </div>
                        </div>
                </div>

                <button className="relative z-10 mr-4 w-10 h-10 rounded-full bg-white/10 border border-white/5 flex items-center justify-center text-white hover:bg-white/20 active:bg-white/30 transition-all shrink-0">
                        <Bell className="w-5 h-5" />
                </button>
            </div>
            
            {/* Left Column */}
            <div className="flex flex-col gap-4">
                
                {/* Card: Morning Walks (Square) */}
                <button 
                    onClick={() => onSelectCommunity('comm-walk')}
                    className="bg-white p-4 rounded-[28px] shadow-sm active:scale-[0.98] transition-transform relative overflow-hidden group"
                >
                    {/* Live Badge */}
                    <div className="absolute top-4 right-4 bg-white/90 backdrop-blur-md px-2 py-1 rounded-full shadow-sm z-10 flex items-center gap-1.5 border border-gray-100">
                        <div className="relative">
                           <div className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
                           <div className="absolute inset-0 bg-green-500 rounded-full animate-ping opacity-20" />
                        </div>
                        <span className="text-[9px] font-bold text-green-700">Sarah posted</span>
                    </div>

                    <div className="aspect-square rounded-2xl overflow-hidden mb-3 relative">
                         <img 
                            src="https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&q=80&w=400" 
                            className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-110"
                         />
                         <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent" />
                         <div className="absolute bottom-2 left-2 text-white">
                             <ImageIcon className="w-4 h-4" />
                         </div>
                    </div>
                    
                    <div className="text-left">
                        <h3 className="text-[17px] font-bold text-gray-900 leading-tight">Morning Walks</h3>
                        <p className="text-[12px] text-gray-500 mt-1">Share your views</p>
                        <div className="mt-3">
                            {renderAvatarPile(9)}
                        </div>
                    </div>
                </button>

                {/* Card: Book & News (Square) */}
                <button 
                    onClick={() => onSelectCommunity('comm-book')}
                    className="bg-white p-4 rounded-[28px] shadow-sm active:scale-[0.98] transition-transform text-left group"
                >
                    <div className="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center text-blue-600 mb-3 group-hover:bg-blue-100 transition-colors">
                        <BookOpen className="w-5 h-5" />
                    </div>
                    <h3 className="text-[17px] font-bold text-gray-900">Book Club</h3>
                    <p className="text-[12px] text-gray-500 mt-1 mb-3">Reading "The Alchemist"</p>
                    <div className="flex items-center gap-2">
                        <div className="bg-blue-50 text-blue-700 px-2 py-1 rounded-md text-[10px] font-bold">
                            Ch. 4 Discussion
                        </div>
                    </div>
                </button>
            </div>

            {/* Right Column */}
            <div className="flex flex-col gap-4">
                
                {/* Card: Prayer Circle (Tall Vertical) */}
                <button 
                    onClick={() => onSelectCommunity('comm-pray')}
                    className="h-full bg-white rounded-[28px] shadow-sm active:scale-[0.98] transition-transform relative overflow-hidden group flex flex-col min-h-[260px]"
                >
                    {/* Background Image Full */}
                    <div className="absolute inset-0">
                        <img 
                            src="https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&q=80&w=400" 
                            className="w-full h-full object-cover opacity-90 transition-transform duration-1000 group-hover:scale-110"
                        />
                        <div className="absolute inset-0 bg-gradient-to-b from-black/10 via-transparent to-black/80" />
                    </div>

                    {/* Badge */}
                    <div className="absolute top-4 left-4 bg-rose-500/90 backdrop-blur-md text-white px-2.5 py-1 rounded-full text-[10px] font-bold shadow-lg flex items-center gap-1">
                        <Zap className="w-3 h-3 fill-current" />
                        <span>Live Now</span>
                    </div>

                    <div className="absolute bottom-0 left-0 right-0 p-5 text-left z-10 group-active:translate-y-[-2px] transition-transform">
                         <div className="w-10 h-10 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-white mb-3 border border-white/20">
                             <Heart className="w-5 h-5 fill-current" />
                         </div>
                         <h3 className="text-[20px] font-bold text-white leading-tight">Prayer Circle</h3>
                         <p className="text-white/80 text-[13px] mt-1 mb-4 line-clamp-2">Join 8 others in silent reflection.</p>
                         
                         <div className="flex items-center justify-between">
                             {renderAvatarPile(5)}
                             <div className="w-8 h-8 rounded-full bg-white text-rose-600 flex items-center justify-center shadow-md">
                                 <ArrowRight className="w-4 h-4" />
                             </div>
                         </div>
                    </div>
                </button>

            </div>
        </div>

        {/* Footer Note */}
        <div className="mt-8 px-4 text-center mb-8">
             <p className="text-[11px] text-gray-400 font-medium bg-gray-200/50 py-2 px-4 rounded-full inline-flex items-center gap-2">
                <ShieldCheck className="w-3 h-3" />
                Verified & Moderated Community
             </p>
        </div>
      </div>
    </div>
  );
};