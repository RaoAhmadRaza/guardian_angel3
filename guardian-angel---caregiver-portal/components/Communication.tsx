
import React, { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { ShieldCheck, HeartPulse, Phone, Info, ChevronRight, MessageSquare, Search } from 'lucide-react';
import { MOCK_PATIENT } from '../constants';

const CommunicationHub: React.FC = () => {
  const navigate = useNavigate();
  const [activeTab, setActiveTab] = useState<'Messages' | 'Calls'>('Messages');

  const callHistory = [
    { name: MOCK_PATIENT.name, type: 'Outgoing', time: 'Yesterday', status: 'missed', duration: '0:00' },
    { name: 'Dr. Aris Thorne', type: 'Incoming', time: 'Tue', status: 'answered', duration: '4:12' },
    { name: MOCK_PATIENT.name, type: 'FaceTime', time: 'Monday', status: 'answered', duration: '12:05' },
  ];

  return (
    <div className="max-w-2xl mx-auto space-y-10 animate-in fade-in duration-700">
      <header className="px-4">
        <h2 className="text-4xl font-bold text-black tracking-tight mb-8">Messages</h2>
        
        <div className="bg-[#E3E3E8] p-1.5 rounded-2xl flex relative h-12 shadow-inner">
          <div 
            className={`absolute top-1.5 bottom-1.5 w-[calc(50%-6px)] bg-white rounded-xl shadow-md transition-all duration-400 ease-[cubic-bezier(0.16,1,0.3,1)] ${
              activeTab === 'Calls' ? 'translate-x-[calc(100%+6px)]' : 'translate-x-0'
            }`}
          />
          <button
            onClick={() => setActiveTab('Messages')}
            className={`flex-1 relative z-10 font-bold text-sm transition-colors duration-200 ${
              activeTab === 'Messages' ? 'text-black' : 'text-[#8E8E93]'
            }`}
          >
            Messages
          </button>
          <button
            onClick={() => setActiveTab('Calls')}
            className={`flex-1 relative z-10 font-bold text-sm transition-colors duration-200 ${
              activeTab === 'Calls' ? 'text-black' : 'text-[#8E8E93]'
            }`}
          >
            Calls
          </button>
        </div>
      </header>

      <div className="px-4 space-y-4">
        {activeTab === 'Messages' ? (
          <div className="space-y-4">
            {/* AI Guardian Thread */}
            <button 
              onClick={() => navigate('/chat/ai')}
              className="w-full ios-card p-6 flex items-center gap-6 bg-white hover:bg-slate-50 transition-all group shadow-sm active:scale-[0.98]"
            >
              <div className="p-4 bg-blue-50 text-[#007AFF] rounded-2xl group-hover:bg-[#007AFF] group-hover:text-white transition-all">
                <ShieldCheck size={28} />
              </div>
              <div className="text-left flex-1 min-w-0">
                <div className="flex justify-between items-center">
                  <p className="font-bold text-[17px] text-black">AI Guardian</p>
                  <span className="text-xs text-[#8E8E93] font-medium">Now</span>
                </div>
                <p className="text-[15px] font-medium text-[#8E8E93] truncate mt-1">Analysis complete: Eleanor's vitals are stable.</p>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </button>

            {/* Patient Thread */}
            <button 
              onClick={() => navigate('/chat/patient')}
              className="w-full ios-card p-6 flex items-center gap-6 bg-white hover:bg-slate-50 transition-all group shadow-sm active:scale-[0.98]"
            >
              <div className="relative flex-shrink-0">
                <img src={MOCK_PATIENT.photoUrl} className="w-16 h-16 rounded-full object-cover shadow-md" alt="" />
                <div className="absolute -bottom-1 -right-1 w-5 h-5 bg-[#34C759] border-4 border-white rounded-full"></div>
              </div>
              <div className="text-left flex-1 min-w-0">
                <div className="flex justify-between items-center">
                  <p className="font-bold text-[17px] text-black">{MOCK_PATIENT.name}</p>
                  <span className="text-xs text-[#8E8E93] font-medium">12m ago</span>
                </div>
                <p className="text-[15px] font-medium text-[#8E8E93] truncate mt-1">I'm feeling much better after my tea, thank you.</p>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </button>

            {/* Doctor Thread */}
            <button 
              onClick={() => navigate('/chat/doctor')}
              className="w-full ios-card p-6 flex items-center gap-6 bg-white hover:bg-slate-50 transition-all group shadow-sm active:scale-[0.98]"
            >
              <div className="p-4 bg-rose-50 text-[#FF2D55] rounded-2xl group-hover:bg-[#FF2D55] group-hover:text-white transition-all">
                <HeartPulse size={28} />
              </div>
              <div className="text-left flex-1 min-w-0">
                <div className="flex justify-between items-center">
                  <p className="font-bold text-[17px] text-black">Dr. Aris Thorne</p>
                  <span className="text-xs text-[#8E8E93] font-medium">Tue</span>
                </div>
                <p className="text-[15px] font-medium text-[#8E8E93] truncate mt-1">The latest lab results look promising. Let's discuss.</p>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </button>
          </div>
        ) : (
          <div className="space-y-2">
            {callHistory.map((call, i) => (
              <div key={i} className="p-6 ios-card bg-white flex items-center justify-between hover:bg-slate-50 transition-all cursor-pointer group shadow-sm active:scale-[0.98]">
                <div className="flex items-center gap-5">
                  <div className={`w-10 h-10 flex items-center justify-center rounded-full ${call.status === 'missed' ? 'bg-rose-50 text-rose-500' : 'bg-slate-50 text-slate-300'}`}>
                    {call.status === 'missed' ? '!' : <Phone size={18} />}
                  </div>
                  <div>
                    <p className={`font-bold text-[17px] ${call.status === 'missed' ? 'text-rose-500' : 'text-black'}`}>{call.name}</p>
                    <p className="text-[11px] font-bold text-[#8E8E93] uppercase tracking-[0.1em] mt-1">{call.type} • {call.duration}</p>
                  </div>
                </div>
                <div className="flex items-center gap-4">
                  <span className="text-xs text-[#8E8E93] font-bold">{call.time}</span>
                  <Info size={20} className="text-[#007AFF]" />
                </div>
              </div>
            ))}
          </div>
        )}
      </div>

      <div className="py-12 text-center">
        <p className="text-[13px] text-[#8E8E93] font-medium uppercase tracking-[0.2em]">End-to-end Encrypted</p>
      </div>
    </div>
  );
};

export default CommunicationHub;
