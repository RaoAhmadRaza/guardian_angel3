
import React, { useState } from 'react';
import { Patient } from '../types';

export const ScheduleScreen: React.FC<{ patient: Patient | null }> = ({ patient }) => {
  const [selectedSlot, setSelectedSlot] = useState<string | null>(null);
  const slots = [
    { day: 'Mon', date: '30 Oct', times: ['09:00', '10:30', '14:00'] },
    { day: 'Tue', date: '31 Oct', times: ['11:00', '15:30', '16:00'] },
    { day: 'Wed', date: '1 Nov', times: ['08:30', '13:00'] },
  ];

  return (
    <div className="p-4 space-y-6">
      <div className="mb-2">
        <p className="text-xs font-black uppercase text-slate-400 tracking-widest mb-1">Consultation</p>
        <h2 className="text-2xl font-black text-slate-900">Schedule Session</h2>
      </div>

      <div className="bg-white rounded-[28px] p-5 shadow-sm border border-slate-100">
        <h3 className="font-bold text-slate-900 mb-4 flex justify-between items-center">
          Available Slots
          <span className="text-[9px] font-black text-blue-500 uppercase tracking-widest bg-blue-50 px-2 py-0.5 rounded-full">EST Zone</span>
        </h3>
        <div className="space-y-6">
          {slots.map((s, idx) => (
            <div key={idx}>
              <div className="flex items-center space-x-2 mb-3">
                <span className="text-sm font-black text-slate-900">{s.day}</span>
                <span className="text-xs font-bold text-slate-300 uppercase tracking-widest">{s.date}</span>
              </div>
              <div className="grid grid-cols-3 gap-2">
                {s.times.map((t, i) => (
                  <button 
                    key={i} 
                    onClick={() => setSelectedSlot(`${s.day}-${t}`)}
                    className={`py-3 rounded-[16px] text-xs font-black transition-all ${
                      selectedSlot === `${s.day}-${t}`
                      ? 'bg-blue-600 text-white shadow-lg shadow-blue-100 scale-105'
                      : 'bg-slate-50 text-slate-500 hover:bg-slate-100 border border-slate-100'
                    }`}
                  >
                    {t}
                  </button>
                ))}
              </div>
            </div>
          ))}
        </div>
      </div>

      <div className="bg-slate-900 rounded-[28px] p-6 shadow-xl text-white">
        <h3 className="font-bold mb-4">Session Details</h3>
        <div className="space-y-5">
          <div className="grid grid-cols-3 gap-2">
            <button className="flex flex-col items-center p-3 bg-white/10 rounded-2xl border border-white/20 ring-2 ring-blue-500/50">
              <svg className="w-6 h-6 mb-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 10l4.553-2.276A1 1 0 0121 8.618v6.764a1 1 0 01-1.447.894L15 14M5 18h8a2 2 0 002-2V8a2 2 0 00-2-2H5a2 2 0 00-2 2v8a2 2 0 002 2z" /></svg>
              <span className="text-[10px] font-black uppercase">Video</span>
            </button>
            <button className="flex flex-col items-center p-3 bg-white/5 hover:bg-white/10 rounded-2xl border border-white/10">
              <svg className="w-6 h-6 mb-1 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg>
              <span className="text-[10px] font-black uppercase opacity-50">Audio</span>
            </button>
            <button className="flex flex-col items-center p-3 bg-white/5 hover:bg-white/10 rounded-2xl border border-white/10">
              <svg className="w-6 h-6 mb-1 opacity-50" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" /></svg>
              <span className="text-[10px] font-black uppercase opacity-50">Chat</span>
            </button>
          </div>
          <button className="w-full py-4 bg-blue-600 text-white rounded-[20px] font-bold shadow-lg shadow-blue-500/20 active:scale-95 transition-all">
            Propose Consultation
          </button>
        </div>
      </div>
    </div>
  );
};
