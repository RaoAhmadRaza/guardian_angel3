import React from 'react';
import { AreaChart, Area, XAxis, YAxis, CartesianGrid, Tooltip, ResponsiveContainer } from 'recharts';
import { Patient, PatientStatus } from '../types';
import { vitalsHistory, medications } from '../mockData';

interface PatientOverviewProps {
  patient: Patient;
  onNavigate: (screen: any) => void;
}

export const PatientOverview: React.FC<PatientOverviewProps> = ({ patient, onNavigate }) => {
  return (
    <div className="flex flex-col space-y-4 p-4">
      {/* Patient Hub Section */}
      <div className="bg-white rounded-[28px] p-5 border border-slate-100 shadow-sm flex flex-col items-center text-center">
        <img src={patient.photo} className="w-24 h-24 rounded-[32px] border-4 border-slate-50 shadow-sm mb-4" alt={patient.name} />
        <h2 className="text-2xl font-black text-slate-900 leading-tight">{patient.name}</h2>
        <p className="text-slate-500 font-semibold text-sm mb-4">{patient.age} Yrs • GA-{(Math.random()*1000).toFixed(0)}</p>
        
        {/* Updated Clinical Action Grid */}
        <div className="grid grid-cols-2 gap-3 w-full">
          <button 
            onClick={() => onNavigate('chat')}
            className="flex items-center justify-center space-x-2 bg-blue-600 text-white py-3.5 rounded-2xl font-bold shadow-lg shadow-blue-100 active:scale-95 transition-all"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" d="M8 12h.01M12 12h.01M16 12h.01M21 12c0 4.418-4.03 8-9 8a9.863 9.863 0 01-4.255-.949L3 20l1.395-3.72C3.512 15.042 3 13.574 3 12c0-4.418 4.03-8 9-8s9 3.582 9 8z" /></svg>
            <span className="text-sm">Message</span>
          </button>
          <button 
            onClick={() => onNavigate('schedule')}
            className="flex items-center justify-center space-x-2 bg-slate-900 text-white py-3.5 rounded-2xl font-bold shadow-lg shadow-slate-200 active:scale-95 transition-all"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" d="M8 7V3m8 4V3m-9 8h10M5 21h14a2 2 0 002-2V7a2 2 0 00-2-2H5a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
            <span className="text-sm">Schedule</span>
          </button>
          <button 
            onClick={() => onNavigate('reports')}
            className="flex items-center justify-center space-x-2 bg-indigo-600 text-white py-3.5 rounded-2xl font-bold shadow-lg shadow-indigo-100 active:scale-95 transition-all"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            <span className="text-sm">Reports</span>
          </button>
          <button 
            onClick={() => onNavigate('notes')}
            className="flex items-center justify-center space-x-2 bg-purple-600 text-white py-3.5 rounded-2xl font-bold shadow-lg shadow-purple-100 active:scale-95 transition-all"
          >
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" d="M11 5H6a2 2 0 00-2 2v11a2 2 0 002 2h11a2 2 0 002-2v-5m-1.414-9.414a2 2 0 112.828 2.828L11.828 15H9v-2.828l8.586-8.586z" /></svg>
            <span className="text-sm">Findings</span>
          </button>
        </div>
      </div>

      {/* Vitals Overview (Horizontal Scroll for small metrics) */}
      <div className="flex space-x-3 overflow-x-auto pb-2 scrollbar-hide px-0.5">
        <div className="bg-emerald-50 border border-emerald-100 p-4 rounded-3xl min-w-[120px] flex-1">
          <p className="text-[10px] font-black text-emerald-600 uppercase mb-1">Pulse</p>
          <p className="text-2xl font-black text-slate-900">76<span className="text-xs font-bold text-slate-400 ml-1">bpm</span></p>
        </div>
        <div className="bg-blue-50 border border-blue-100 p-4 rounded-3xl min-w-[120px] flex-1">
          <p className="text-[10px] font-black text-blue-600 uppercase mb-1">O2 Sat</p>
          <p className="text-2xl font-black text-slate-900">98<span className="text-xs font-bold text-slate-400 ml-1">%</span></p>
        </div>
        <div className="bg-amber-50 border border-amber-100 p-4 rounded-3xl min-w-[120px] flex-1">
          <p className="text-[10px] font-black text-amber-600 uppercase mb-1">Sleep</p>
          <p className="text-2xl font-black text-slate-900">8.2<span className="text-xs font-bold text-slate-400 ml-1">h</span></p>
        </div>
      </div>

      {/* Vitals Chart Card */}
      <div className="bg-white p-5 rounded-[28px] border border-slate-100 shadow-sm">
        <div className="flex justify-between items-center mb-6">
          <h3 className="font-bold text-slate-900">Heart Rate Trend</h3>
          <span className="text-[10px] font-black uppercase text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">24h View</span>
        </div>
        <div className="h-48 w-full -ml-4">
          <ResponsiveContainer width="100%" height="100%">
            <AreaChart data={vitalsHistory}>
              <defs>
                <linearGradient id="mobileGrad" x1="0" y1="0" x2="0" y2="1">
                  <stop offset="5%" stopColor="#3B82F6" stopOpacity={0.15}/>
                  <stop offset="95%" stopColor="#3B82F6" stopOpacity={0}/>
                </linearGradient>
              </defs>
              <CartesianGrid strokeDasharray="3 3" vertical={false} stroke="#f8fafc" />
              <XAxis dataKey="time" hide />
              <YAxis hide domain={[60, 100]} />
              <Tooltip 
                contentStyle={{ borderRadius: '16px', border: 'none', boxShadow: '0 10px 15px -3px rgba(0,0,0,0.1)' }}
              />
              <Area type="monotone" dataKey="value" stroke="#3B82F6" strokeWidth={3} fillOpacity={1} fill="url(#mobileGrad)" />
            </AreaChart>
          </ResponsiveContainer>
        </div>
      </div>

      {/* Medications & Alerts Stack */}
      <div className="space-y-4">
        <div className="bg-white p-5 rounded-[28px] border border-slate-100 shadow-sm">
          <h3 className="font-bold text-slate-900 mb-4">Medications</h3>
          <div className="space-y-4">
            {medications.map((med, idx) => (
              <div key={idx} className="flex items-center justify-between pb-4 border-b border-slate-50 last:border-0 last:pb-0">
                <div>
                  <p className="text-[15px] font-bold text-slate-900">{med.name}</p>
                  <p className="text-xs text-slate-500 font-medium">{med.dosage} • {med.frequency}</p>
                </div>
                <div className="bg-slate-50 h-10 w-10 rounded-full flex items-center justify-center">
                   <span className="text-[10px] font-black text-blue-600">{med.adherence}%</span>
                </div>
              </div>
            ))}
          </div>
        </div>

        <div className="bg-rose-50/50 p-5 rounded-[28px] border border-rose-100/50 shadow-sm">
          <h3 className="font-bold text-rose-900 mb-4 flex items-center">
            <svg className="w-5 h-5 mr-2 text-rose-500" fill="currentColor" viewBox="0 0 20 20"><path fillRule="evenodd" d="M18 10a8 8 0 11-16 0 8 8 0 0116 0zm-7 4a1 1 0 11-2 0 1 1 0 012 0zm-1-9a1 1 0 00-1 1v4a1 1 0 102 0V6a1 1 0 00-1-1z" clipRule="evenodd" /></svg>
            Recent Alerts
          </h3>
          <div className="space-y-2">
            <div className="bg-white p-4 rounded-2xl shadow-sm border border-rose-100/30">
              <p className="text-sm font-bold text-slate-900">Irregular Rhythm Detected</p>
              <p className="text-[10px] text-slate-400 font-medium">Today at 04:32 AM</p>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
