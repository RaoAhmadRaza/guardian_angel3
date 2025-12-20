import React, { useState } from 'react';
import { ChevronLeft, Search, MoreHorizontal, Phone, Video, MessageCircle, Stethoscope, Heart, ShieldCheck } from 'lucide-react';
import { ChatSession, ViewType } from '../types';

interface CareTeamListProps {
  sessions: ChatSession[];
  onBack: () => void;
  onSelectMember: (id: string) => void;
}

export const CareTeamList: React.FC<CareTeamListProps> = ({ sessions, onBack, onSelectMember }) => {
  const [searchQuery, setSearchQuery] = useState('');
  const [isScrolled, setIsScrolled] = useState(false);

  const careTeam = sessions.filter(s => s.type === ViewType.CAREGIVER || s.type === ViewType.DOCTOR);
  
  const filteredTeam = careTeam.filter(member => 
    member.name.toLowerCase().includes(searchQuery.toLowerCase()) ||
    (member.subtitle && member.subtitle.toLowerCase().includes(searchQuery.toLowerCase()))
  );

  const onScroll = (e: React.UIEvent<HTMLDivElement>) => {
    setIsScrolled(e.currentTarget.scrollTop > 40);
  };

  return (
    <div className="fixed inset-0 z-40 bg-[#f2f2f7] flex flex-col font-sans slide-in-right safe-area-top safe-area-bottom">
      
      {/* Dynamic Header */}
      <header className={`sticky top-0 z-50 transition-all duration-300 px-4 py-3 flex items-center justify-between
        ${isScrolled ? 'bg-white/80 backdrop-blur-xl border-b border-gray-200' : 'bg-transparent'}
      `}>
        <button 
          onClick={onBack}
          className="flex items-center gap-1 text-blue-600 active:opacity-50 transition-opacity"
        >
          <ChevronLeft className="w-8 h-8 -ml-2" />
          <span className="text-[17px] font-medium">Dashboard</span>
        </button>

        <h1 className={`text-[17px] font-bold text-gray-900 transition-opacity duration-300 ${isScrolled ? 'opacity-100' : 'opacity-0'}`}>
          Care Team
        </h1>

        <button className="w-10 h-10 rounded-full bg-gray-200/50 flex items-center justify-center text-gray-600">
          <MoreHorizontal className="w-5 h-5" />
        </button>
      </header>

      {/* Scrollable Content */}
      <div 
        className="flex-1 overflow-y-auto no-scrollbar"
        onScroll={onScroll}
      >
        {/* Page Title */}
        <div className="px-6 pb-4 pt-2">
          <h2 className="text-[34px] font-serif font-bold text-gray-900">Care Team</h2>
          <p className="text-gray-500 text-sm mt-1">Your trusted support circle</p>
        </div>

        {/* Search Bar */}
        <div className="px-5 mb-6">
          <div className="relative flex items-center bg-gray-200/50 rounded-xl px-3 py-2 border border-gray-300/20 focus-within:bg-white focus-within:ring-2 focus-within:ring-blue-100 transition-all">
            <Search className="w-4 h-4 text-gray-400 mr-2" />
            <input 
              type="text" 
              placeholder="Search by name or role..."
              className="bg-transparent border-none outline-none text-[15px] w-full placeholder-gray-400"
              value={searchQuery}
              onChange={(e) => setSearchQuery(e.target.value)}
            />
          </div>
        </div>

        {/* Categorized List */}
        <div className="px-5 space-y-8 pb-20">
          
          {/* Medical Professionals Group */}
          <div>
            <h3 className="text-[13px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-3">Medical Professionals</h3>
            <div className="bg-white rounded-[24px] overflow-hidden shadow-sm border border-white">
              {filteredTeam.filter(m => m.type === ViewType.DOCTOR).map((member, i, arr) => (
                <button 
                  key={member.id}
                  onClick={() => onSelectMember(member.id)}
                  className={`w-full flex items-center gap-4 p-4 active:bg-gray-50 transition-colors relative
                    ${i !== arr.length - 1 ? 'border-b border-gray-100' : ''}
                  `}
                >
                  <div className="relative">
                    <div className="w-14 h-14 rounded-full bg-blue-50 border border-blue-100 flex items-center justify-center overflow-hidden">
                      {member.id === 'doc-1' ? (
                         <img src="https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop" className="w-full h-full object-cover" />
                      ) : <Stethoscope className="w-7 h-7 text-blue-500" />}
                    </div>
                    {member.isOnline && (
                       <div className="absolute bottom-0 right-0 w-3.5 h-3.5 bg-green-500 border-2 border-white rounded-full" />
                    )}
                  </div>
                  
                  <div className="flex-1 text-left">
                    <div className="flex items-center gap-1.5">
                      <span className="font-bold text-gray-900">{member.name}</span>
                      <ShieldCheck className="w-3.5 h-3.5 text-blue-500" />
                    </div>
                    <p className="text-[13px] text-gray-500">{member.subtitle || 'Specialist'}</p>
                  </div>

                  <div className="flex gap-2">
                    <div className="w-9 h-9 rounded-full bg-gray-50 flex items-center justify-center text-blue-600">
                      <Phone className="w-4 h-4 fill-current" />
                    </div>
                    <div className="w-9 h-9 rounded-full bg-gray-50 flex items-center justify-center text-blue-600">
                      <Video className="w-4 h-4" />
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

          {/* Family & Caregivers Group */}
          <div>
            <h3 className="text-[13px] font-bold text-gray-400 uppercase tracking-widest px-1 mb-3">Family & Caregivers</h3>
            <div className="bg-white rounded-[24px] overflow-hidden shadow-sm border border-white">
              {filteredTeam.filter(m => m.type === ViewType.CAREGIVER).map((member, i, arr) => (
                <button 
                  key={member.id}
                  onClick={() => onSelectMember(member.id)}
                  className={`w-full flex items-center gap-4 p-4 active:bg-gray-50 transition-colors relative
                    ${i !== arr.length - 1 ? 'border-b border-gray-100' : ''}
                  `}
                >
                  <div className="relative">
                    <div className="w-14 h-14 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-xl">
                      {member.name.charAt(0)}
                    </div>
                    {member.isOnline && (
                       <div className="absolute bottom-0 right-0 w-3.5 h-3.5 bg-green-500 border-2 border-white rounded-full" />
                    )}
                    {member.unreadCount && member.unreadCount > 0 && (
                      <div className="absolute -top-1 -right-1 bg-blue-500 text-white text-[10px] font-bold w-5 h-5 rounded-full flex items-center justify-center border-2 border-white">
                        {member.unreadCount}
                      </div>
                    )}
                  </div>
                  
                  <div className="flex-1 text-left">
                    <span className="font-bold text-gray-900">{member.name}</span>
                    <p className="text-[13px] text-gray-500">{member.subtitle || 'Family'}</p>
                  </div>

                  <div className="flex gap-2 text-gray-400">
                    <div className="w-9 h-9 rounded-full bg-gray-50 flex items-center justify-center">
                      <Phone className="w-4 h-4" />
                    </div>
                    <div className="w-9 h-9 rounded-full bg-gray-50 flex items-center justify-center">
                      <MessageCircle className="w-4 h-4" />
                    </div>
                  </div>
                </button>
              ))}
            </div>
          </div>

        </div>
      </div>
    </div>
  );
};