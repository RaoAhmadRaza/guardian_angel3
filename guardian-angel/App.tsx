import React, { useState, useEffect } from 'react';
import { ViewType, ChatSession } from './types';
import { SOSModal } from './components/SOSModal';
import { ChatScreen } from './components/ChatScreen';
import { CommunityHome } from './components/CommunityHome';
import { AddMemberModal } from './components/AddMemberModal';
import { CareTeamList } from './components/CareTeamList';
import { 
  AlertTriangle, 
  ChevronRight, 
  Activity, 
  User, 
  Stethoscope, 
  Pill, 
  CloudSun,
  Heart,
  Users,
  ShieldCheck,
  CheckCircle2,
  Sparkles,
  BadgeCheck,
  Zap,
  Leaf
} from 'lucide-react';

// --- MOCK DATA ---
const INITIAL_SESSIONS: ChatSession[] = [
  {
    id: 'ai-1',
    type: ViewType.AI_COMPANION,
    name: 'Guardian Angel',
    subtitle: 'Monitoring quietly', 
    messages: [
        {
            id: 'welcome',
            text: "Hello. I'm here with you — whether you want to talk, check your health, or just share a moment.",
            sender: 'other',
            timestamp: new Date()
        }
    ]
  },
  {
    id: 'caregiver-1',
    type: ViewType.CAREGIVER,
    name: 'Sarah',
    subtitle: 'Active earlier',
    isOnline: true,
    unreadCount: 2,
    messages: [
        { id: '1', text: "Hi Mom! Did you remember to take your afternoon meds?", sender: 'other', timestamp: new Date(Date.now() - 1000 * 60 * 60), status: 'read' },
        { id: '2', text: "Yes dear, I took them with lunch.", sender: 'user', timestamp: new Date(Date.now() - 1000 * 60 * 55), status: 'read' },
        { 
            id: '3', 
            text: "Great! I'll bring some groceries over later.", 
            sender: 'other', 
            timestamp: new Date(Date.now() - 1000 * 60 * 10),
            reactions: [{ emoji: '❤️', fromMe: true }] 
        },
        { id: '4', text: "Do you need milk?", sender: 'other', timestamp: new Date(Date.now() - 1000 * 60 * 9) }
    ]
  },
  {
    id: 'doc-1',
    type: ViewType.DOCTOR,
    name: 'Dr. Emily',
    subtitle: 'Cardiologist',
    statusText: 'Replies during clinic hours',
    isOnline: false,
    nextAppointment: new Date(Date.now() + 1000 * 60 * 60 * 24 * 2), // 2 days from now
    messages: [
        { 
            id: 'd1', 
            text: "Your heart rate looks stable this week. Keep up the short walks.", 
            sender: 'other', 
            timestamp: new Date(Date.now() - 1000 * 60 * 60 * 24), 
            status: 'read',
            chartData: [68, 72, 70, 74, 71, 69, 72] // Mock heart rate data
        },
        {
            id: 'd2',
            text: "I've renewed your prescription. You can order the refill directly here.",
            sender: 'other',
            timestamp: new Date(Date.now() - 1000 * 60 * 60 * 2),
            status: 'read',
            prescription: {
                name: "Lisinopril",
                dosage: "10mg",
                instructions: "Take one tablet daily"
            }
        }
    ]
  },
  {
    id: 'sys-1',
    type: ViewType.SYSTEM,
    name: 'Medication',
    subtitle: 'On track',
    medicationProgress: 66, // 2 of 3 taken
    unreadCount: 0,
    messages: [
        { 
            id: 's1', 
            text: "Scheduled for 2:00 PM", 
            sender: 'system', 
            timestamp: new Date(),
            medication: {
                name: "Metoprolol",
                dosage: "50 mg",
                context: "Take with food",
                pillType: 'round',
                pillColor: 'bg-rose-100',
                inventory: {
                    remaining: 5,
                    total: 30,
                    status: 'low'
                },
                sideEffects: ["Mild dizziness", "Tiredness"],
                doctorNotes: "Monitor blood pressure if you feel lightheaded.",
                streakDays: 12,
                nextDose: {
                    name: "Atorvastatin",
                    time: "8:00 PM"
                }
            }
        }
    ]
  },
  {
    id: 'peace-1',
    type: ViewType.PEACE_OF_MIND,
    name: 'Daily Peace',
    subtitle: 'Mindfulness', 
    messages: [
        { id: 'p1', text: "Good morning. Take a deep breath. What is one small thing that made you smile yesterday?", sender: 'other', timestamp: new Date() }
    ]
  },
  {
    id: 'comm-walk',
    type: ViewType.COMMUNITY,
    name: 'Morning Walks',
    subtitle: '3 gentle moments',
    coverImage: "https://images.unsplash.com/photo-1476480862126-209bfaa8edc8?auto=format&fit=crop&q=80&w=1200",
    dailyPrompt: "What was the most beautiful thing you saw on your walk today?",
    goalProgress: 65,
    messages: [
        { id: 'cw1', text: "The sunrise was beautiful today!", sender: 'other', timestamp: new Date() }
    ]
  },
  {
    id: 'comm-grat',
    type: ViewType.COMMUNITY,
    name: 'Daily Gratitude',
    subtitle: 'Reflecting together',
    coverImage: "https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&q=80&w=1200",
    dailyPrompt: "What made you smile this morning?",
    goalProgress: 88,
    messages: [
        { id: 'cg1', text: "Grateful for a good night's sleep.", sender: 'other', timestamp: new Date() }
    ]
  },
  {
    id: 'comm-book',
    type: ViewType.COMMUNITY,
    name: 'Book Club',
    subtitle: 'Reading together',
    coverImage: "https://images.unsplash.com/photo-1524995997946-a1c2e315a42f?auto=format&fit=crop&q=80&w=1200",
    dailyPrompt: "Which character in 'The Alchemist' do you relate to most?",
    goalProgress: 42,
    messages: [
        { id: 'cb1', text: "Just finished chapter 4, wow!", sender: 'other', timestamp: new Date() }
    ]
  },
  {
    id: 'comm-pray',
    type: ViewType.COMMUNITY,
    name: 'Prayer Circle',
    subtitle: 'Silent reflection',
    coverImage: "https://images.unsplash.com/photo-1519681393784-d120267933ba?auto=format&fit=crop&q=80&w=1200",
    dailyPrompt: "How can we support you in prayer today?",
    goalProgress: 95,
    messages: [
        { id: 'cp1', text: "Praying for peace and health for everyone.", sender: 'other', timestamp: new Date() }
    ]
  }
];

// --- PROGRESS RING COMPONENT ---
const ProgressRing = ({ progress, color, size = 48, stroke = 4, icon: Icon }: { progress: number, color: string, size?: number, stroke?: number, icon?: React.ElementType }) => {
    const radius = size / 2;
    const normalizedRadius = radius - stroke * 2;
    const circumference = normalizedRadius * 2 * Math.PI;
    const strokeDashoffset = circumference - (progress / 100) * circumference;
  
    return (
      <div className="relative flex items-center justify-center" style={{ width: size, height: size }}>
          <svg height={size} width={size} className="rotate-[-90deg] absolute">
              <circle
                  stroke="currentColor"
                  strokeOpacity="0.1"
                  strokeWidth={stroke}
                  fill="transparent"
                  r={normalizedRadius}
                  cx={radius}
                  cy={radius}
                  className="text-gray-400"
              />
              <circle
                  stroke={color}
                  strokeWidth={stroke}
                  strokeDasharray={circumference + ' ' + circumference}
                  style={{ strokeDashoffset, transition: 'stroke-dashoffset 0.5s ease-in-out' }}
                  strokeLinecap="round"
                  fill="transparent"
                  r={normalizedRadius}
                  cx={radius}
                  cy={radius}
              />
          </svg>
          {Icon && <Icon className="w-5 h-5 absolute" style={{ color }} />}
      </div>
    );
};

const App: React.FC = () => {
  const [activeSessionId, setActiveSessionId] = useState<string | null>(null);
  const [sessions, setSessions] = useState<ChatSession[]>(INITIAL_SESSIONS);
  const [isSOSOpen, setIsSOSOpen] = useState(false);
  const [isAddMemberOpen, setIsAddMemberOpen] = useState(false);
  const [currentView, setCurrentView] = useState<'HUB' | 'COMMUNITY' | 'CARE_TEAM'>('HUB');
  const [isScrolled, setIsScrolled] = useState(false);
  const [greeting, setGreeting] = useState("Good Afternoon");

  const activeSession = sessions.find(s => s.id === activeSessionId);

  useEffect(() => {
      const hour = new Date().getHours();
      if (hour < 12) setGreeting("Good Morning");
      else if (hour < 18) setGreeting("Good Afternoon");
      else setGreeting("Good Evening");
  }, []);

  const handleSendMessage = (sessionId: string, text: string, imageUrl?: string) => {
    setSessions(prev => prev.map(s => {
      if (s.id === sessionId) {
        return {
          ...s,
          unreadCount: 0, 
          messages: [...s.messages, {
            id: Date.now().toString(),
            text,
            sender: 'user',
            timestamp: new Date(),
            status: 'sending',
            imageUrl: imageUrl
          }]
        };
      }
      return s;
    }));
  };

  const handleOpenSession = (id: string) => {
      setActiveSessionId(id);
      setCurrentView('HUB'); 
      setSessions(prev => prev.map(s => s.id === id ? { ...s, unreadCount: 0 } : s));
  };

  const handleSOS = () => {
      setIsSOSOpen(true);
      setCurrentView('HUB'); 
  };

  const onScroll = (e: React.UIEvent<HTMLDivElement>) => {
    const scrollTop = e.currentTarget.scrollTop;
    setIsScrolled(scrollTop > 40);
  };

  const handleAddMember = (memberData: Partial<ChatSession>) => {
    const newId = `member-${Date.now()}`;
    const newSession: ChatSession = {
        id: newId,
        type: memberData.type || ViewType.CAREGIVER,
        name: memberData.name || 'New Member',
        subtitle: memberData.subtitle,
        isOnline: true,
        messages: [],
        ...memberData
    };
    setSessions(prev => [newSession, ...prev]);
  };

  // --- RENDERING HELPERS ---

  const renderDynamicIsland = () => {
      const aiSession = sessions.find(s => s.type === ViewType.AI_COMPANION);
      if (!aiSession) return null;

      return (
        <button 
            onClick={() => handleOpenSession(aiSession.id)}
            className="mx-auto mt-2 mb-6 bg-black/90 backdrop-blur-xl rounded-full px-5 py-2.5 flex items-center gap-3 shadow-2xl active:scale-95 transition-transform max-w-[90%] z-10"
        >
            <div className="relative">
                <div className="w-2 h-2 rounded-full bg-green-400 animate-pulse shadow-[0_0_10px_rgba(74,222,128,0.5)]" />
            </div>
            <div className="flex flex-col items-start">
                 <span className="text-white text-[13px] font-medium leading-none flex items-center gap-1.5">
                    Guardian Angel
                    <Sparkles className="w-3 h-3 text-purple-300" />
                 </span>
            </div>
             <ChevronRight className="w-3 h-3 text-white/50 ml-1" />
        </button>
      );
  };

  const renderCareTeamRail = () => (
      <div className="mb-8">
          <div className="px-5 mb-3 flex items-center justify-between">
              <h3 className="text-[15px] font-bold text-gray-900">Care Team</h3>
              <button 
                onClick={() => setCurrentView('CARE_TEAM')}
                className="text-blue-600 text-[13px] font-medium active:opacity-50"
              >
                See All
              </button>
          </div>
          
          <div className="flex gap-4 overflow-x-auto px-5 pb-4 no-scrollbar snap-x">
             {sessions.filter(s => s.type === ViewType.CAREGIVER || s.type === ViewType.DOCTOR).map((session) => (
                 <button 
                    key={session.id}
                    onClick={() => handleOpenSession(session.id)}
                    className="flex flex-col items-center gap-2 snap-center group min-w-[72px]"
                 >
                     <div className="relative">
                         <div className={`w-[72px] h-[72px] rounded-full flex items-center justify-center text-xl font-bold border-2 transition-all group-active:scale-95 shadow-sm
                             ${session.type === ViewType.DOCTOR 
                                ? 'bg-blue-50 text-blue-600 border-blue-100' 
                                : 'bg-gray-100 text-gray-500 border-white'
                             }
                         `}>
                             {session.type === ViewType.DOCTOR ? (
                               <div className="w-full h-full overflow-hidden rounded-full">
                                 <img src="https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop" className="w-full h-full object-cover" />
                               </div>
                             ) : session.name.charAt(0)}
                         </div>
                         
                         {session.isOnline && (
                             <div className="absolute inset-0 rounded-full border-[3px] border-green-400/30 animate-pulse" />
                         )}
                         {session.unreadCount && session.unreadCount > 0 && (
                             <div className="absolute top-0 right-0 bg-blue-500 text-white text-[10px] font-bold h-5 min-w-[20px] px-1 rounded-full flex items-center justify-center border-2 border-[#f2f2f7]">
                                 {session.unreadCount}
                             </div>
                         )}
                     </div>
                     <span className="text-[12px] font-medium text-gray-600 truncate max-w-[80px]">
                        {session.name.split(' ')[0]}
                     </span>
                 </button>
             ))}
             
             <button 
                onClick={() => setIsAddMemberOpen(true)}
                className="flex flex-col items-center gap-2 min-w-[72px] group"
             >
                 <div className="w-[72px] h-[72px] rounded-full bg-gray-200/50 flex items-center justify-center text-gray-400 border-2 border-dashed border-gray-300 group-active:scale-95 transition-transform">
                     <span className="text-2xl font-light">+</span>
                 </div>
                 <span className="text-[12px] font-medium text-gray-400">Add</span>
             </button>
          </div>
      </div>
  );

  const renderBentoGrid = () => {
      const medSession = sessions.find(s => s.type === ViewType.SYSTEM);
      const peaceSession = sessions.find(s => s.type === ViewType.PEACE_OF_MIND);

      return (
          <div className="px-5 pb-24">
              <div className="px-1 mb-3">
                  <h3 className="text-[15px] font-bold text-gray-900">Wellness & Community</h3>
              </div>
              <div className="grid grid-cols-2 gap-4">
                  <button 
                    onClick={() => medSession && handleOpenSession(medSession.id)}
                    className="bg-white rounded-[24px] p-5 flex flex-col items-center justify-between aspect-square shadow-sm active:scale-[0.98] transition-transform relative overflow-hidden"
                  >
                      <div className="absolute top-0 left-0 w-full h-1 bg-gray-100" />
                      <div className="w-full flex justify-between items-start">
                          <div className="p-1.5 bg-gray-50 rounded-full">
                              <Pill className="w-4 h-4 text-gray-500" />
                          </div>
                          <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wide pr-1">Today</span>
                      </div>
                      
                      <div className="flex-1 flex items-center justify-center">
                           <ProgressRing progress={80} color="#10B981" icon={CheckCircle2} size={52} />
                      </div>

                      <div className="text-center pb-1">
                          <p className="text-[14px] font-bold text-gray-900 leading-tight">Medication</p>
                          <p className="text-[11px] text-gray-400 font-medium">On track</p>
                      </div>
                  </button>

                  <button 
                     onClick={() => peaceSession && handleOpenSession(peaceSession.id)}
                     className="bg-white rounded-[24px] p-5 flex flex-col items-center justify-between aspect-square shadow-sm active:scale-[0.98] transition-transform relative overflow-hidden"
                  >
                      <div className="w-full flex justify-between items-start">
                          <div className="p-1.5 bg-teal-50 rounded-full">
                              <Leaf className="w-4 h-4 text-teal-600" />
                          </div>
                          <span className="text-[10px] font-bold text-teal-600/60 uppercase tracking-wide pr-1">Mind</span>
                      </div>
                      
                      <div className="flex-1 flex items-center justify-center">
                           <ProgressRing progress={45} color="#0D9488" icon={Zap} size={52} />
                      </div>

                      <div className="text-center pb-1">
                          <p className="text-[14px] font-bold text-gray-900 leading-tight">Daily Peace</p>
                          <p className="text-[11px] text-gray-400 font-medium">2 mins left</p>
                      </div>
                  </button>

                  <button 
                    onClick={() => !isSOSOpen && setCurrentView('COMMUNITY')}
                    disabled={isSOSOpen}
                    className="col-span-2 bg-white rounded-[24px] p-5 flex items-center justify-between shadow-sm active:scale-[0.98] transition-transform"
                  >
                      <div className="flex items-center gap-4">
                          <div className="w-12 h-12 rounded-2xl bg-orange-50 flex items-center justify-center text-orange-600">
                              <Users className="w-6 h-6" />
                          </div>
                          <div className="text-left">
                              <p className="text-[16px] font-bold text-gray-900">Community Groups</p>
                              <div className="flex items-center gap-1.5 mt-0.5">
                                  <div className="flex -space-x-1">
                                      <div className="w-4 h-4 rounded-full bg-gray-200 border border-white" />
                                      <div className="w-4 h-4 rounded-full bg-gray-300 border border-white" />
                                      <div className="w-4 h-4 rounded-full bg-gray-400 border border-white" />
                                  </div>
                                  <span className="text-[13px] text-gray-500">Discover support groups</span>
                              </div>
                          </div>
                      </div>
                      <ChevronRight className="w-5 h-5 text-gray-300" />
                  </button>
              </div>
          </div>
      );
  };

  const renderChatsView = () => (
    <div 
        className="flex-1 overflow-y-auto no-scrollbar bg-[#f2f2f7]" 
        onScroll={onScroll}
    >
        <div className="h-2" />
        <div className="px-6 py-4 flex justify-between items-end">
             <div>
                 <p className="text-[13px] text-gray-500 font-bold uppercase tracking-widest mb-1">{new Date().toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' })}</p>
                 <h1 className="text-[34px] font-serif text-gray-900 leading-tight">
                    {greeting}
                 </h1>
             </div>
             <button className="w-10 h-10 rounded-full bg-gray-200/50 flex items-center justify-center text-gray-600 mb-1">
                 <User className="w-5 h-5" />
             </button>
        </div>

        {renderDynamicIsland()}
        
        <div className="mx-5 mb-8">
            <button 
                onClick={handleSOS}
                className={`w-full rounded-2xl p-4 flex items-center gap-4 active:scale-[0.98] transition-all relative overflow-hidden
                    ${isSOSOpen 
                        ? 'bg-red-600 shadow-xl' 
                        : 'bg-white shadow-sm border border-red-100/50' 
                    }
                `}
            >
                <div className={`w-10 h-10 rounded-full flex items-center justify-center shrink-0
                    ${isSOSOpen ? 'bg-white text-red-600 animate-pulse' : 'bg-red-50 text-red-500'}
                `}>
                    <AlertTriangle className="w-5 h-5 fill-current" />
                </div>
                <div className="flex-1 text-left">
                     <h3 className={`text-[16px] font-bold ${isSOSOpen ? 'text-white' : 'text-gray-900'}`}>
                        Emergency SOS
                     </h3>
                     <p className={`text-[13px] ${isSOSOpen ? 'text-red-100' : 'text-gray-500'}`}>
                        Tap for immediate help
                     </p>
                </div>
            </button>
        </div>

        {renderCareTeamRail()}
        {renderBentoGrid()}
    </div>
  );

  return (
    <div className={`h-full flex flex-col safe-area-top safe-area-bottom transition-colors duration-500 ${isSOSOpen ? 'bg-gray-200' : 'bg-[#f2f2f7]'}`}>
      
      {currentView === 'HUB' && (
          <header className={`px-5 py-3 flex justify-between items-center transition-all duration-500 sticky top-0 z-20
             ${isScrolled 
                ? 'bg-[#f2f2f7]/80 backdrop-blur-xl border-b border-gray-200/50 pt-3 pb-3' 
                : 'bg-transparent pt-4 pb-2'
             }
          `}>
            <h1 className={`text-[17px] font-semibold text-black transition-opacity duration-500 ${isScrolled ? 'opacity-100' : 'opacity-0'}`}>
                {greeting}
            </h1>
          </header>
      )}
      
      {currentView === 'COMMUNITY' && (
          <CommunityHome 
            isEmergency={isSOSOpen} 
            onSelectCommunity={handleOpenSession}
            onBack={() => setCurrentView('HUB')}
          />
      )}

      {currentView === 'CARE_TEAM' && (
        <CareTeamList 
          sessions={sessions}
          onBack={() => setCurrentView('HUB')}
          onSelectMember={handleOpenSession}
        />
      )}
      
      {currentView === 'HUB' && renderChatsView()}

      {activeSession && (
        <ChatScreen 
            session={activeSession} 
            onBack={() => setActiveSessionId(null)}
            onSendMessage={handleSendMessage}
            onSOS={handleSOS}
        />
      )}

      <SOSModal isOpen={isSOSOpen} onClose={() => setIsSOSOpen(false)} />

      <AddMemberModal 
        isOpen={isAddMemberOpen} 
        onClose={() => setIsAddMemberOpen(false)} 
        onAdd={handleAddMember}
      />
    </div>
  );
};

export default App;