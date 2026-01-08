
import React, { useContext } from 'react';
import { MOCK_PATIENT } from '../constants';
import { ShieldAlert, MapPin, Activity, CheckCircle, Heart, Wind, Moon, Phone, UserPlus, FileSearch, ArrowRight, BellRing, ChevronRight, MessageSquare } from 'lucide-react';
import { useNavigate } from 'react-router-dom';
import { CallContext } from '../App';

const Dashboard: React.FC = () => {
  const navigate = useNavigate();
  const { startCall } = useContext(CallContext);

  return (
    <div className="space-y-10 animate-in fade-in slide-in-from-bottom-4 duration-700 max-w-5xl mx-auto">
      {/* Header Section */}
      <header className="flex flex-col md:flex-row md:items-end justify-between gap-6 px-2">
        <div>
          <h2 className="text-4xl font-bold tracking-tight text-black">Today's Overview</h2>
          <p className="text-[#8E8E93] text-lg font-medium mt-1">Everything is stable. Eleanor is currently at home.</p>
        </div>
        <div 
          onClick={() => navigate('/patient')}
          className="flex items-center gap-3 bg-white p-3 pr-6 ios-card cursor-pointer hover:bg-slate-50 transition-all active:scale-95 shadow-sm"
        >
          <img 
            src={MOCK_PATIENT.photoUrl} 
            alt="" 
            className="w-12 h-12 rounded-full object-cover"
          />
          <div>
            <p className="font-semibold text-[15px]">{MOCK_PATIENT.name}</p>
            <div className="flex items-center gap-1.5">
              <span className="w-2 h-2 rounded-full bg-[#34C759]"></span>
              <span className="text-[11px] font-bold text-[#34C759] uppercase tracking-wider">Online</span>
            </div>
          </div>
          <ChevronRight size={16} className="text-[#C7C7CC] ml-4" />
        </div>
      </header>

      {/* Main Stats Cluster */}
      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        {/* Safety Hero - SOS & Location */}
        <div className="md:col-span-2 ios-card p-8 flex flex-col justify-between min-h-[220px] shadow-sm relative overflow-hidden group">
          <div className="absolute top-0 right-0 p-8 opacity-[0.03] group-hover:opacity-[0.06] transition-opacity">
            <ShieldAlert size={140} className="text-[#007AFF]" />
          </div>
          <div className="relative z-10">
            <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest mb-4">Safety Status</h3>
            <div className="flex items-center gap-4">
              <div className="p-4 bg-blue-50 text-[#007AFF] rounded-2xl">
                <MapPin size={32} />
              </div>
              <div>
                <p className="text-2xl font-bold text-black">Safe Zone: Home</p>
                <p className="text-[#8E8E93] font-medium">Entered 45 mins ago</p>
              </div>
            </div>
          </div>
          <div className="flex gap-4 relative z-10 mt-6">
            <button className="flex-1 bg-[#F2F2F7] text-black px-6 py-3.5 rounded-2xl font-semibold hover:bg-slate-200 transition-colors">
              View History
            </button>
            <button className="flex-1 bg-[#F2F2F7] text-black px-6 py-3.5 rounded-2xl font-semibold hover:bg-slate-200 transition-colors">
              Zone Settings
            </button>
          </div>
        </div>

        {/* SOS Quick Block */}
        <div 
          onClick={() => navigate('/alerts')}
          className="ios-card p-8 bg-white shadow-sm flex flex-col justify-between hover:bg-rose-50 transition-colors cursor-pointer group"
        >
          <div className="p-4 bg-rose-50 text-[#FF3B30] w-fit rounded-2xl group-hover:bg-[#FF3B30] group-hover:text-white transition-all">
            <ShieldAlert size={32} />
          </div>
          <div>
            <h4 className="text-xl font-bold text-black">SOS Alert</h4>
            <p className="text-[#8E8E93] font-medium text-sm mt-1">Ready for emergency</p>
          </div>
          <div className="flex items-center text-[#FF3B30] font-bold text-sm">
            Check Status <ArrowRight size={16} className="ml-2" />
          </div>
        </div>
      </div>

      {/* Health Vitals Section */}
      <section className="space-y-4">
        <div className="flex items-center justify-between px-2">
          <h3 className="text-xl font-bold text-black">Vitals</h3>
          <button className="text-[#007AFF] font-semibold text-sm">View Trends</button>
        </div>
        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          {[
            { label: 'Heart Rate', value: '72', unit: 'bpm', icon: Heart, color: '#FF2D55', bg: 'bg-rose-50' },
            { label: 'Oxygen', value: '98', unit: '%', icon: Wind, color: '#007AFF', bg: 'bg-blue-50' },
            { label: 'Sleep', value: '7.4', unit: 'hrs', icon: Moon, color: '#5856D6', bg: 'bg-indigo-50' },
            { label: 'Steps', value: '3.2k', unit: 'steps', icon: Activity, color: '#34C759', bg: 'bg-emerald-50' }
          ].map((vital, i) => (
            <div key={i} className="ios-card p-6 shadow-sm flex flex-col items-center text-center space-y-3">
              <div className={`p-3 ${vital.bg} rounded-2xl`} style={{ color: vital.color }}>
                <vital.icon size={24} />
              </div>
              <div>
                <p className="text-2xl font-bold text-black">{vital.value}<span className="text-xs font-medium text-[#8E8E93] ml-1">{vital.unit}</span></p>
                <p className="text-[11px] font-bold text-[#8E8E93] uppercase tracking-wider">{vital.label}</p>
              </div>
            </div>
          ))}
        </div>
      </section>

      {/* Tasks & Communication */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-8">
        <section className="space-y-4">
          <h3 className="text-xl font-bold text-black px-2">Daily Tasks</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden">
            {[
              { title: 'Morning Meds', time: '8:30 AM', status: 'Missed', color: '#FF3B30' },
              { title: 'Physiotherapy', time: '2:00 PM', status: 'Upcoming', color: '#007AFF' }
            ].map((task, idx) => (
              <div key={idx} className="p-6 flex items-center justify-between border-b border-[#F2F2F7] last:border-0 hover:bg-slate-50 transition-colors cursor-pointer">
                <div className="flex items-center gap-4">
                  <div className="w-2.5 h-2.5 rounded-full" style={{ backgroundColor: task.color }}></div>
                  <div>
                    <p className="font-bold text-black">{task.title}</p>
                    <p className="text-xs text-[#8E8E93] font-medium">{task.time}</p>
                  </div>
                </div>
                <div className="text-xs font-bold px-3 py-1 rounded-full uppercase tracking-wider" style={{ backgroundColor: `${task.color}15`, color: task.color }}>
                  {task.status}
                </div>
              </div>
            ))}
            <button 
              onClick={() => navigate('/tasks')}
              className="w-full py-5 text-center text-[#007AFF] font-bold text-sm bg-slate-50/50 hover:bg-slate-100 transition-colors"
            >
              See All Tasks
            </button>
          </div>
        </section>

        <section className="space-y-4">
          <h3 className="text-xl font-bold text-black px-2">Connectivity</h3>
          <div className="grid grid-cols-1 gap-4">
            <button 
              onClick={startCall}
              className="flex items-center justify-between bg-white p-6 ios-card shadow-sm hover:bg-slate-50 transition-all group"
            >
              <div className="flex items-center gap-4">
                <div className="p-3 bg-blue-50 text-[#007AFF] rounded-2xl">
                  <Phone size={24} />
                </div>
                <div className="text-left">
                  <p className="font-bold text-black">Call Eleanor</p>
                  <p className="text-xs text-[#8E8E93] font-medium">Native HD Audio</p>
                </div>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </button>
            <button 
              onClick={() => navigate('/chat/ai')}
              className="flex items-center justify-between bg-white p-6 ios-card shadow-sm hover:bg-slate-50 transition-all group"
            >
              <div className="flex items-center gap-4">
                <div className="p-3 bg-emerald-50 text-[#34C759] rounded-2xl">
                  <MessageSquare size={24} />
                </div>
                <div className="text-left">
                  <p className="font-bold text-black">Message AI Guardian</p>
                  <p className="text-xs text-[#8E8E93] font-medium">Smart Assistant Online</p>
                </div>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </button>
          </div>
        </section>
      </div>
    </div>
  );
};

export default Dashboard;
