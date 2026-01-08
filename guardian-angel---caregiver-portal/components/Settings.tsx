
import React, { useState } from 'react';
import { ToggleLeft as Toggle, Bell, Eye, Users, Lock, Shield, ChevronRight } from 'lucide-react';

const SettingsView: React.FC = () => {
  const [switches, setSwitches] = useState({
    vitals: true,
    mood: true,
    exercises: false,
    autoReports: true,
    emergency: true,
    quietHours: false,
    priority: true
  });

  const toggleSwitch = (key: keyof typeof switches) => {
    setSwitches(prev => ({ ...prev, [key]: !prev[key] }));
  };

  const iOSSwitch = (key: keyof typeof switches) => (
    <button 
      onClick={() => toggleSwitch(key)}
      className={`w-[51px] h-[31px] rounded-full p-0.5 transition-colors duration-200 relative ${switches[key] ? 'bg-[#34C759]' : 'bg-[#E9E9EB]'}`}
    >
      <div className={`w-[27px] h-[27px] bg-white rounded-full shadow-md transition-transform duration-200 ease-in-out ${switches[key] ? 'translate-x-[20px]' : 'translate-x-0'}`} />
    </button>
  );

  return (
    <div className="max-w-2xl mx-auto space-y-10 animate-in fade-in duration-700 pb-20">
      <header className="px-4">
        <h2 className="text-4xl font-bold text-black tracking-tight">Settings</h2>
      </header>

      <div className="space-y-10 px-4">
        {/* Patient Permissions Section */}
        <section className="space-y-2">
          <h3 className="text-[#8E8E93] font-bold text-[13px] uppercase tracking-widest px-4 mb-2">Patient Permissions</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b border-[#F2F2F7]">
               <div className="flex items-center gap-4">
                  <div className="p-2 bg-blue-50 text-[#007AFF] rounded-lg"><Eye size={20} /></div>
                  <span className="text-[17px] font-medium text-black">Real-time Vitals Streaming</span>
               </div>
               {iOSSwitch('vitals')}
            </div>
            <div className="flex items-center justify-between p-5 border-b border-[#F2F2F7]">
               <div className="flex items-center gap-4">
                  <div className="p-2 bg-indigo-50 text-[#5856D6] rounded-lg"><Bell size={20} /></div>
                  <span className="text-[17px] font-medium text-black">Mood Log Visibility</span>
               </div>
               {iOSSwitch('mood')}
            </div>
            <div className="flex items-center justify-between p-5 hover:bg-slate-50 transition-colors cursor-pointer group">
               <div className="flex items-center gap-4">
                  <div className="p-2 bg-slate-50 text-slate-400 rounded-lg"><Lock size={20} /></div>
                  <span className="text-[17px] font-medium text-black">Access Tokens</span>
               </div>
               <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </div>
          </div>
          <p className="px-4 text-[13px] text-[#8E8E93] leading-snug">
            Control which health indicators are visible to delegated caregivers.
          </p>
        </section>

        {/* Doctor & Support Section */}
        <section className="space-y-2">
          <h3 className="text-[#8E8E93] font-bold text-[13px] uppercase tracking-widest px-4 mb-2">Doctor & Support</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden">
            <div className="flex items-center justify-between p-5 border-b border-[#F2F2F7]">
               <div className="flex items-center gap-4">
                  <div className="p-2 bg-emerald-50 text-[#34C759] rounded-lg"><Users size={20} /></div>
                  <span className="text-[17px] font-medium text-black">Allow Automated Reports</span>
               </div>
               {iOSSwitch('autoReports')}
            </div>
            <div className="flex items-center justify-between p-5">
               <div className="flex items-center gap-4">
                  <div className="p-2 bg-rose-50 text-[#FF3B30] rounded-lg"><Shield size={20} /></div>
                  <span className="text-[17px] font-medium text-black">Direct Emergency Call</span>
               </div>
               {iOSSwitch('emergency')}
            </div>
          </div>
        </section>

        {/* App Info */}
        <section className="text-center pt-8 space-y-4">
           <div className="w-20 h-20 bg-white rounded-[24px] shadow-xl shadow-blue-50 flex items-center justify-center mx-auto mb-4 border border-black/5">
              <div className="w-8 h-8 bg-[#007AFF] rounded-full"></div>
           </div>
           <div>
              <p className="text-lg font-bold text-black tracking-tight">Guardian Angel</p>
              <p className="text-sm text-[#8E8E93] font-medium">Version 3.4.2 Gold</p>
           </div>
           <button className="text-[#FF3B30] font-bold text-[17px] py-4">Sign Out</button>
        </section>
      </div>
    </div>
  );
};

export default SettingsView;
