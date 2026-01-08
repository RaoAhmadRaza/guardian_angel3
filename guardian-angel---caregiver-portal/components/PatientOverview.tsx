
import React, { useContext } from 'react';
import { MOCK_PATIENT } from '../constants';
import { Heart, Pill, Map, Brain, ExternalLink, MapPin, ChevronRight, Phone, MessageCircle } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { CallContext } from '../App';

const PatientOverview: React.FC = () => {
  const navigate = useNavigate();
  const { startCall } = useContext(CallContext);

  const handleChatClick = () => {
    // Navigate to the specific patient chat route
    navigate('/chat/patient');
  };

  return (
    <div className="max-w-4xl mx-auto space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-12">
      {/* Premium Profile Header */}
      <header className="flex flex-col items-center text-center space-y-4 pt-4">
        <div className="relative">
          <img src={MOCK_PATIENT.photoUrl} alt="" className="w-32 h-32 rounded-[40px] object-cover shadow-2xl ring-4 ring-white" />
          <div className="absolute bottom-1 right-1 w-8 h-8 bg-[#34C759] border-4 border-white rounded-full"></div>
        </div>
        <div>
          <h2 className="text-3xl font-bold text-black tracking-tight">{MOCK_PATIENT.name}</h2>
          <p className="text-[#8E8E93] font-medium">78 Years Old • Patient #GA-8829</p>
          <div className="flex gap-2 justify-center mt-3">
            <span className="bg-[#34C759]/10 text-[#34C759] px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider">Stable</span>
            <span className="bg-[#007AFF]/10 text-[#007AFF] px-4 py-1.5 rounded-full text-xs font-bold uppercase tracking-wider">Active Monitor</span>
          </div>
        </div>
        <div className="flex gap-3 w-full max-w-sm pt-4">
          <button 
            onClick={startCall}
            className="flex-1 bg-[#007AFF] text-white py-3.5 rounded-2xl font-bold flex items-center justify-center gap-2 shadow-lg shadow-blue-200 hover:bg-blue-600 transition-colors active:scale-95"
          >
            <Phone size={18} strokeWidth={2.5} /> Call
          </button>
          <button 
            onClick={handleChatClick}
            className="flex-1 bg-white text-black py-3.5 rounded-2xl font-bold flex items-center justify-center gap-2 shadow-sm border border-black/5 hover:bg-slate-50 transition-colors active:scale-95"
          >
            <MessageCircle size={18} strokeWidth={2.5} /> Chat
          </button>
        </div>
      </header>

      {/* Sections - iOS Grouped List Style */}
      <div className="space-y-8">
        {/* Health Insights */}
        <section>
          <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest px-6 mb-3">Health Insights</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden">
            <div className="p-6 flex items-center justify-between border-b border-[#F2F2F7] hover:bg-slate-50 cursor-pointer group">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-rose-50 text-[#FF2D55] rounded-2xl"><Heart size={20} /></div>
                <div>
                  <p className="font-bold text-black">Average Heart Rate</p>
                  <p className="text-sm text-[#8E8E93] font-medium">Consistency: High</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-lg font-bold">74 bpm</span>
                <ChevronRight size={16} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
              </div>
            </div>
            <div className="p-6 flex items-center justify-between border-b border-[#F2F2F7] hover:bg-slate-50 cursor-pointer group">
              <div className="flex items-center gap-4">
                <div className="p-3 bg-blue-50 text-[#007AFF] rounded-2xl"><Brain size={20} /></div>
                <div>
                  <p className="font-bold text-black">Cognitive Focus Score</p>
                  <p className="text-sm text-[#8E8E93] font-medium">Daily Reflection: Complete</p>
                </div>
              </div>
              <div className="flex items-center gap-2">
                <span className="text-lg font-bold">88%</span>
                <ChevronRight size={16} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
              </div>
            </div>
          </div>
        </section>

        {/* Safety & Location */}
        <section>
          <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest px-6 mb-3">Location & Mobility</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden p-2">
             <div className="relative aspect-video rounded-2xl overflow-hidden mb-2">
                <img src="https://picsum.photos/id/10/1200/600" className="w-full h-full object-cover opacity-60 grayscale-[50%]" alt="Map" />
                <div className="absolute inset-0 bg-gradient-to-t from-white/80 to-transparent flex flex-col items-center justify-center">
                   <div className="bg-white p-4 rounded-full shadow-xl text-[#007AFF] mb-3"><MapPin size={32} strokeWidth={2.5} /></div>
                   <p className="text-xl font-bold text-black">Eleanor is at Home</p>
                   <p className="text-sm font-semibold text-[#8E8E93]">Last movement: 12m ago</p>
                </div>
             </div>
             <button className="w-full py-4 text-[#007AFF] font-bold text-sm hover:bg-slate-50 rounded-xl transition-colors">
                Open in Apple Maps
             </button>
          </div>
        </section>

        {/* Medication */}
        <section>
          <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest px-6 mb-3">Medication Adherence</h3>
          <div className="ios-card bg-white shadow-sm p-8 flex flex-col items-center text-center space-y-6">
            <div className="relative w-32 h-32 flex items-center justify-center">
              <svg className="w-full h-full transform -rotate-90">
                <circle cx="64" cy="64" r="58" stroke="currentColor" strokeWidth="10" fill="transparent" className="text-[#F2F2F7]" />
                <circle cx="64" cy="64" r="58" stroke="currentColor" strokeWidth="10" fill="transparent" strokeDasharray="364.4" strokeDashoffset="123.9" className="text-[#007AFF] transition-all duration-1000" />
              </svg>
              <div className="absolute inset-0 flex flex-col items-center justify-center">
                <p className="text-2xl font-bold">66%</p>
                <p className="text-[10px] font-bold text-[#8E8E93] uppercase">Complete</p>
              </div>
            </div>
            <div>
              <p className="text-lg font-bold text-black">2 of 3 doses taken</p>
              <p className="text-sm text-[#8E8E93] font-medium">Next dose: Lisinopril at 6:00 PM</p>
            </div>
            <button className="text-[#007AFF] font-bold text-sm">View Schedule</button>
          </div>
        </section>

        <button className="w-full bg-[#FF3B30] text-white py-5 rounded-3xl font-bold text-lg shadow-xl shadow-rose-100 active:scale-95 transition-all">
          Trigger Emergency Alert
        </button>
      </div>
    </div>
  );
};

export default PatientOverview;
