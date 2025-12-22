import React, { useState, useRef, useEffect } from 'react';
import { ChevronLeft, Heart, MessageCircle, Share, MoreHorizontal, Users, Camera, Sparkles, ShieldCheck, MapPin, Play, Plus, Target, Mic, Send, ArrowUp } from 'lucide-react';
import { ChatSession, Message } from '../types';
import { ShareMomentModal } from './ShareMomentModal';

interface CommunityFeedProps {
  session: ChatSession;
  onBack: () => void;
  onSendMessage: (sessionId: string, text: string, imageUrl?: string) => void;
}

type TabType = 'feed' | 'chat';

export const CommunityFeed: React.FC<CommunityFeedProps> = ({ session, onBack, onSendMessage }) => {
  const [activeTab, setActiveTab] = useState<TabType>('feed');
  const [isScrolled, setIsScrolled] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);
  const chatScrollRef = useRef<HTMLDivElement>(null);
  const [likedPosts, setLikedPosts] = useState<Record<string, boolean>>({});
  const [inputText, setInputText] = useState('');
  const [isShareModalOpen, setIsShareModalOpen] = useState(false);

  // Auto-scroll chat to bottom
  useEffect(() => {
    if (activeTab === 'chat' && chatScrollRef.current) {
        chatScrollRef.current.scrollTop = chatScrollRef.current.scrollHeight;
    }
  }, [activeTab, session.messages]);

  const onScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const scrollTop = e.currentTarget.scrollTop;
    setIsScrolled(scrollTop > 200);
  };

  const handleLike = (msgId: string) => {
      setLikedPosts(prev => ({ ...prev, [msgId]: !prev[msgId] }));
  };

  const handleSendChat = () => {
      if (inputText.trim()) {
          onSendMessage(session.id, inputText);
          setInputText('');
      }
  };

  const handleShareMoment = (caption: string, imageUrl: string) => {
    onSendMessage(session.id, caption || "Shared a moment", imageUrl);
    setActiveTab('feed');
    // Scroll to top of feed to see new post
    if (scrollRef.current) {
        scrollRef.current.scrollTo({ top: 300, behavior: 'smooth' });
    }
  };

  const getPostImage = (msg: Message, index: number) => {
      if (msg.imageUrl) return msg.imageUrl;
      
      const images = [
          "https://images.unsplash.com/photo-1501854140884-074cf2a1a746?auto=format&fit=crop&q=80&w=600",
          "https://images.unsplash.com/photo-1447752875215-b2761acb3c5d?auto=format&fit=crop&q=80&w=600",
          "https://images.unsplash.com/photo-1470252649378-9c29740c9fa8?auto=format&fit=crop&q=80&w=600",
          "https://images.unsplash.com/photo-1490730141103-6cac27aaab94?auto=format&fit=crop&q=80&w=600"
      ];
      return images[index % images.length];
  };

  const DEFAULT_COVER = "https://images.unsplash.com/photo-1511632765486-a01980e01a18?auto=format&fit=crop&q=80&w=1200";

  return (
    <div className="fixed inset-0 z-30 bg-[#f2f2f7] safe-area-top safe-area-bottom flex flex-col font-sans slide-in-right">
      
      <ShareMomentModal 
        isOpen={isShareModalOpen} 
        onClose={() => setIsShareModalOpen(false)} 
        onShare={handleShareMoment} 
      />

      {/* 1. Dynamic Header */}
      <header className={`fixed top-0 left-0 right-0 z-40 transition-all duration-300 safe-area-top
          ${isScrolled ? 'bg-white/90 backdrop-blur-xl border-b border-gray-200/50 shadow-sm py-2' : 'bg-transparent py-4'}
      `}>
          <div className="px-4 flex items-center justify-between">
              <button 
                onClick={onBack} 
                className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors
                    ${isScrolled ? 'text-gray-900 hover:bg-gray-100' : 'text-white bg-black/20 backdrop-blur-md hover:bg-black/30'}
                `}
              >
                  <ChevronLeft className="w-6 h-6" />
              </button>
              
              <div className={`flex flex-col items-center transition-opacity duration-300 ${isScrolled ? 'opacity-100' : 'opacity-0'}`}>
                  <h1 className="text-[17px] font-bold text-gray-900">{session.name}</h1>
                  <span className="text-[11px] text-gray-500 font-medium">Community Hub</span>
              </div>

              <button className={`w-10 h-10 rounded-full flex items-center justify-center transition-colors
                   ${isScrolled ? 'text-gray-900 hover:bg-gray-100' : 'text-white bg-black/20 backdrop-blur-md hover:bg-black/30'}
              `}>
                  <MoreHorizontal className="w-6 h-6" />
              </button>
          </div>

          {/* iOS Segmented Control (Tabs) */}
          <div className={`px-12 mt-2 transition-all duration-300 ${isScrolled ? 'opacity-100 scale-100 h-10' : 'opacity-0 scale-95 h-0 overflow-hidden'}`}>
                <div className="bg-gray-100/80 backdrop-blur-sm p-1 rounded-xl flex items-center relative">
                    <div 
                        className="absolute top-1 bottom-1 w-[calc(50%-4px)] bg-white rounded-lg shadow-sm transition-transform duration-300 ease-out"
                        style={{ transform: `translateX(${activeTab === 'feed' ? '0' : '100%'})` }}
                    />
                    <button 
                        onClick={() => setActiveTab('feed')}
                        className={`flex-1 relative z-10 py-1 text-[13px] font-bold transition-colors ${activeTab === 'feed' ? 'text-gray-900' : 'text-gray-500'}`}
                    >
                        Feed
                    </button>
                    <button 
                        onClick={() => setActiveTab('chat')}
                        className={`flex-1 relative z-10 py-1 text-[13px] font-bold transition-colors ${activeTab === 'chat' ? 'text-gray-900' : 'text-gray-500'}`}
                    >
                        Chat Room
                    </button>
                </div>
          </div>
      </header>

      {/* Main Content Area */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto no-scrollbar pb-32"
        onScroll={onScroll}
      >
          {/* 1. Immersive Hero */}
          <div className="relative h-[420px] w-full -mt-20">
              <img 
                src={session.coverImage || DEFAULT_COVER} 
                className="w-full h-full object-cover"
                alt="Community Cover"
              />
              <div className="absolute inset-0 bg-gradient-to-b from-black/30 via-transparent to-[#f2f2f7]" />
              
              <div className="absolute top-28 right-6 flex items-center -space-x-3 animate-in fade-in zoom-in duration-700">
                    {[1,2,3].map(i => (
                        <div key={i} className="w-9 h-9 rounded-full border-[2px] border-white/30 overflow-hidden relative">
                            <img src={`https://i.pravatar.cc/100?img=${i + 15}`} className="w-full h-full object-cover" />
                        </div>
                    ))}
                    <div className="w-9 h-9 rounded-full bg-white/20 backdrop-blur-md flex items-center justify-center text-[10px] font-bold text-white border-[2px] border-white/30">
                        +24
                    </div>
              </div>

              {/* Shared Goal Progress Bar (Generic) */}
              <div className="absolute bottom-32 left-6 right-6 animate-in slide-in-from-bottom-4 duration-700 delay-100">
                  <div className="bg-black/30 backdrop-blur-md rounded-2xl p-3 border border-white/10 shadow-lg w-full max-w-sm">
                      <div className="flex justify-between items-center mb-2">
                          <div className="flex items-center gap-2 text-white">
                              <div className="p-1 bg-green-500/20 rounded-full backdrop-blur-sm">
                                <Target className="w-3.5 h-3.5 text-green-400" />
                              </div>
                              <span className="text-[12px] font-bold tracking-wide uppercase opacity-90">Community Goal</span>
                          </div>
                          <span className="text-xs font-bold text-green-400">{session.goalProgress || 0}%</span>
                      </div>
                      <div className="relative h-1.5 bg-white/20 rounded-full overflow-hidden">
                          <div 
                            className="absolute left-0 top-0 bottom-0 bg-gradient-to-r from-green-400 to-emerald-500 rounded-full shadow-[0_0_10px_rgba(52,211,153,0.5)] transition-all duration-1000" 
                            style={{ width: `${session.goalProgress || 0}%` }}
                          />
                      </div>
                  </div>
              </div>

              <div className="absolute bottom-12 left-6 right-6">
                  <div className="flex items-center gap-2 mb-2">
                       <span className="px-2.5 py-1 rounded-full bg-white/20 backdrop-blur-md border border-white/20 text-white text-[11px] font-bold uppercase tracking-wider flex items-center gap-1.5 shadow-sm">
                          <ShieldCheck className="w-3 h-3" /> Verified Group
                       </span>
                  </div>
                  <h1 className="text-[40px] font-bold text-white mb-2 leading-none drop-shadow-md tracking-tight">{session.name}</h1>
                  <div className="flex items-center gap-2">
                      <div className="relative">
                          <div className="w-2.5 h-2.5 bg-green-400 rounded-full animate-pulse" />
                          <div className="absolute inset-0 bg-green-400 rounded-full animate-ping opacity-40" />
                      </div>
                      <p className="text-white/90 font-medium text-[15px] drop-shadow-sm">Member activity is high</p>
                  </div>
              </div>
          </div>

          {/* Tabs Control */}
          <div className="px-6 mb-6 -mt-4 relative z-10">
                <div className="bg-white/60 backdrop-blur-xl p-1.5 rounded-[22px] flex items-center shadow-sm border border-white/80">
                    <button 
                        onClick={() => setActiveTab('feed')}
                        className={`flex-1 py-3 px-4 rounded-[16px] text-[15px] font-bold transition-all flex items-center justify-center gap-2 ${activeTab === 'feed' ? 'bg-white shadow-md text-gray-900 scale-[1.02]' : 'text-gray-500 hover:text-gray-700'}`}
                    >
                        <Sparkles className={`w-4 h-4 ${activeTab === 'feed' ? 'text-amber-500' : 'text-gray-400'}`} />
                        Social Feed
                    </button>
                    <button 
                        onClick={() => setActiveTab('chat')}
                        className={`flex-1 py-3 px-4 rounded-[16px] text-[15px] font-bold transition-all flex items-center justify-center gap-2 ${activeTab === 'chat' ? 'bg-white shadow-md text-gray-900 scale-[1.02]' : 'text-gray-500 hover:text-gray-700'}`}
                    >
                        <MessageCircle className={`w-4 h-4 ${activeTab === 'chat' ? 'text-blue-500' : 'text-gray-400'}`} />
                        Chat Room
                    </button>
                </div>
          </div>

          {/* View Container */}
          <div className="px-5 space-y-6 relative z-10 min-h-[400px]">
               {activeTab === 'feed' ? (
                   <>
                        {/* Daily Prompt - Now Dynamic */}
                        <div className="mb-8">
                            <div className="bg-gradient-to-br from-blue-50 to-indigo-50 rounded-[32px] p-6 border border-blue-100/30 shadow-sm relative overflow-visible group">
                                <div className="absolute top-0 right-0 w-32 h-32 bg-blue-200/20 rounded-full blur-3xl -translate-y-1/2 translate-x-1/2" />
                                <div className="relative z-10">
                                    <div className="flex items-center gap-2 mb-3">
                                        <Sparkles className="w-4 h-4 text-blue-500" />
                                        <h3 className="text-[13px] font-bold text-gray-400 uppercase tracking-wide">Daily Prompt</h3>
                                    </div>
                                    <h4 className="text-xl font-serif text-gray-900 mb-2 leading-snug">
                                        "{session.dailyPrompt || "How is your heart feeling today?"}"
                                    </h4>
                                    <p className="text-sm text-gray-500 mb-4">Posted by Community Lead • Today</p>
                                </div>
                                <button 
                                    onClick={() => setIsShareModalOpen(true)}
                                    className="absolute -bottom-5 right-6 flex flex-col items-center gap-1 z-20 hover:scale-105 transition-transform"
                                >
                                    <div className="w-14 h-14 rounded-full bg-white border-[3px] border-dashed border-blue-300 flex items-center justify-center shadow-lg active:scale-95 transition-transform">
                                        <Camera className="w-6 h-6 text-blue-500 fill-blue-500/20" />
                                        <div className="absolute -top-1 -right-1 w-5 h-5 bg-green-500 rounded-full flex items-center justify-center border-2 border-white shadow-sm">
                                            <Plus className="w-3 h-3 text-white" />
                                        </div>
                                    </div>
                                    <span className="text-[10px] font-bold text-blue-600 bg-white/90 backdrop-blur-sm px-2 py-0.5 rounded-full shadow-sm border border-blue-100">Add Yours</span>
                                </button>
                            </div>
                        </div>

                        {/* Social Moments Feed */}
                        <div className="space-y-8 pb-10">
                            {session.messages.filter(m => m.sender !== 'system').map((msg, index) => {
                                const isMe = msg.sender === 'user';
                                const likes = likedPosts[msg.id] ? 6 : 5;
                                return (
                                    <div key={msg.id} className="bg-white rounded-[32px] p-3 shadow-sm border border-white/60 relative group animate-in slide-in-from-bottom-6 fill-mode-backwards" style={{ animationDelay: `${index * 100}ms` }}>
                                        <div className="relative rounded-[24px] overflow-hidden aspect-[4/5] bg-gray-100 mb-3">
                                            <img src={getPostImage(msg, index)} className="w-full h-full object-cover transform transition-transform duration-700 group-hover:scale-105" />
                                            <div className="absolute top-4 left-4 flex items-center gap-2 bg-black/40 backdrop-blur-md pl-1 pr-3 py-1 rounded-full border border-white/10 shadow-sm">
                                                <div className="w-7 h-7 rounded-full bg-white border border-white/20 overflow-hidden">
                                                    <img src={`https://i.pravatar.cc/100?img=${index + 25}`} className="w-full h-full object-cover" />
                                                </div>
                                                <span className="text-xs font-bold text-white tracking-wide">{isMe ? 'You' : 'Member'}</span>
                                            </div>
                                            <button onClick={() => handleLike(msg.id)} className={`absolute bottom-4 right-4 w-11 h-11 rounded-full backdrop-blur-md border border-white/20 flex items-center justify-center transition-all ${likedPosts[msg.id] ? 'bg-pink-500/90 text-white shadow-lg' : 'bg-black/30 text-white'}`}>
                                                <Heart className={`w-5 h-5 ${likedPosts[msg.id] ? 'fill-current' : ''}`} />
                                            </button>
                                        </div>
                                        <div className="px-2 pb-2">
                                            <p className="text-[16px] font-medium text-gray-900 leading-snug">{msg.text}</p>
                                        </div>
                                    </div>
                                );
                            })}
                        </div>
                   </>
               ) : (
                   /* Chat Room View */
                   <div className="space-y-4 pb-20 animate-in fade-in duration-500">
                        {session.messages.map((msg, index) => {
                            const isMe = msg.sender === 'user';
                            return (
                                <div key={msg.id} className={`flex ${isMe ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2`}>
                                    <div className={`flex items-end gap-2 max-w-[85%] ${isMe ? 'flex-row-reverse' : ''}`}>
                                        {!isMe && (
                                            <div className="w-8 h-8 rounded-full bg-gray-200 overflow-hidden shrink-0 mb-1 shadow-sm border border-white">
                                                <img src={`https://i.pravatar.cc/100?img=${index + 30}`} className="w-full h-full object-cover" />
                                            </div>
                                        )}
                                        <div className={`relative px-4 py-2.5 rounded-[22px] text-[16px] shadow-sm whitespace-pre-wrap
                                            ${isMe 
                                                ? 'bg-gradient-to-br from-blue-500 to-indigo-600 text-white rounded-br-sm' 
                                                : 'bg-white/80 backdrop-blur-md text-gray-900 border border-white/50 rounded-bl-sm'
                                            }
                                        `}>
                                            {msg.text}
                                            <div className={`text-[10px] mt-1 text-right font-medium opacity-60 ${isMe ? 'text-blue-50' : 'text-gray-400'}`}>
                                                {msg.timestamp.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
                                            </div>
                                        </div>
                                    </div>
                                </div>
                            );
                        })}
                   </div>
               )}
          </div>
      </div>

      {/* Footer Interaction Bar */}
      <div className="absolute bottom-0 left-0 right-0 z-50 p-6 pb-8 bg-gradient-to-t from-[#f2f2f7] via-[#f2f2f7]/80 to-transparent pt-12">
           <div className="max-w-xl mx-auto flex justify-center items-center">
               {activeTab === 'feed' ? (
                   <button 
                      onClick={() => setIsShareModalOpen(true)}
                      className="group relative flex items-center gap-3 bg-white/90 backdrop-blur-xl border border-white/60 pl-2 pr-6 py-2 rounded-full shadow-[0_8px_30px_rgba(0,0,0,0.12)] active:scale-95 transition-all hover:shadow-xl pointer-events-auto"
                   >
                       <div className="w-14 h-14 rounded-full bg-gradient-to-tr from-blue-400 to-indigo-500 flex items-center justify-center text-white shadow-lg shadow-blue-500/30 group-hover:scale-105 transition-transform">
                           <Camera className="w-6 h-6 stroke-[2.5px]" />
                       </div>
                       <div className="flex flex-col items-start">
                           <span className="text-[15px] font-bold text-gray-800 leading-tight">Share Moment</span>
                           <span className="text-[10px] font-medium text-blue-600 uppercase tracking-wider">Tap to capture</span>
                       </div>
                       <div className="absolute -top-1 -right-1 w-5 h-5 bg-white rounded-full flex items-center justify-center shadow-sm">
                           <Plus className="w-3 h-3 text-blue-500" />
                       </div>
                   </button>
               ) : (
                   <div className="w-full flex items-center gap-3 pointer-events-auto bg-white/70 backdrop-blur-xl p-2 rounded-[28px] shadow-lg border border-white/60 animate-in slide-in-from-bottom-8">
                        <button className="w-10 h-10 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 hover:bg-gray-200 transition-colors">
                            <Plus className="w-5 h-5" />
                        </button>
                        <input 
                            type="text" 
                            placeholder={`Message ${session.name}...`}
                            className="flex-1 bg-transparent text-[16px] text-gray-900 placeholder-gray-400 outline-none px-2"
                            value={inputText}
                            onChange={(e) => setInputText(e.target.value)}
                            onKeyDown={(e) => e.key === 'Enter' && handleSendChat()}
                        />
                        <button 
                            onClick={handleSendChat}
                            className={`w-10 h-10 rounded-full flex items-center justify-center transition-all ${inputText.trim() ? 'bg-blue-600 text-white shadow-md scale-100' : 'bg-gray-100 text-gray-400 scale-95 opacity-50'}`}
                        >
                            <ArrowUp className="w-5 h-5 stroke-[3px]" />
                        </button>
                   </div>
               )}
           </div>
      </div>
    </div>
  );
};