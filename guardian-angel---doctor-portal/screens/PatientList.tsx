
import React from 'react';
import { patients } from '../mockData';
import { Patient, PatientStatus } from '../types';

interface PatientListProps {
  onSelectPatient: (patient: Patient) => void;
  onConnectNew: () => void;
}

export const PatientList: React.FC<PatientListProps> = ({ onSelectPatient, onConnectNew }) => {
  return (
    <div className="p-4 space-y-4">
      {/* Header Clinical Summary */}
      <div className="flex justify-between items-center px-1 mb-2">
        <div className="text-[10px] font-black uppercase text-slate-400 tracking-widest">
          Active Monitoring: {patients.length}
        </div>
        <div className="text-[10px] font-black uppercase text-rose-500 flex items-center">
          <span className="w-1.5 h-1.5 bg-rose-500 rounded-full mr-1.5 animate-pulse"></span>
          1 Attention Required
        </div>
      </div>

      {/* Search Bar */}
      <div className="relative group">
        <input 
          type="text" 
          placeholder="Search by name, ID, or condition..." 
          className="w-full pl-11 pr-4 py-3.5 bg-white border border-slate-200 rounded-[20px] text-sm font-medium focus:outline-none focus:ring-4 focus:ring-blue-100 transition-all shadow-sm group-hover:shadow-md"
        />
        <svg className="w-5 h-5 absolute left-4 top-4 text-slate-400 group-focus-within:text-blue-500 transition-colors" fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M21 21l-6-6m2-5a7 7 0 11-14 0 7 7 0 0114 0z" />
        </svg>
      </div>

      {/* Connection Glass Widget */}
      <div 
        onClick={onConnectNew}
        className="bg-blue-50/50 backdrop-blur-md border border-blue-100/50 rounded-2xl p-4 flex items-center justify-between mb-4 active:scale-[0.98] transition-all cursor-pointer hover:bg-blue-100/40"
      >
        <div className="flex items-center space-x-3">
          <div className="w-9 h-9 bg-blue-600 rounded-xl flex items-center justify-center text-white shadow-lg shadow-blue-200">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" /></svg>
          </div>
          <span className="text-sm font-black text-blue-700">Connect New Patient</span>
        </div>
        <div className="bg-blue-600/10 px-2 py-1 rounded-lg text-[10px] font-black text-blue-600 uppercase tracking-tighter">Enter Code</div>
      </div>

      {/* Patient Grid */}
      <div className="space-y-3 pb-4">
        {patients.map((patient) => (
          <div 
            key={patient.id} 
            onClick={() => onSelectPatient(patient)}
            className="bg-white border border-slate-100 rounded-[24px] p-5 shadow-sm active:shadow-inner active:scale-[0.99] transition-all relative overflow-hidden group"
          >
            <div className="flex items-start space-x-4">
              {/* Vital Ring Avatar */}
              <div className="relative shrink-0">
                <div className={`w-16 h-16 rounded-[22px] p-1 ${
                  patient.status === PatientStatus.STABLE 
                  ? 'bg-emerald-500/10' 
                  : 'bg-rose-500/10 animate-pulse-ring'
                }`}>
                  <img src={patient.photo} alt={patient.name} className="w-full h-full rounded-[18px] object-cover ring-2 ring-white" />
                </div>
                <div className={`absolute -top-1 -right-1 w-4 h-4 rounded-full border-2 border-white ${
                  patient.status === PatientStatus.STABLE ? 'bg-emerald-500' : 'bg-rose-500'
                }`}></div>
              </div>
              
              <div className="flex-1 min-w-0">
                <div className="flex justify-between items-start">
                  <div>
                    <h3 className="text-[17px] font-black text-slate-900 group-hover:text-blue-600 transition-colors leading-tight">{patient.name}</h3>
                    <p className="text-xs text-slate-400 font-bold mb-2 uppercase tracking-tight">{patient.age} Yrs • GA-{(Math.random()*100).toFixed(0)}</p>
                  </div>
                  <span className="text-[10px] font-black text-slate-300 uppercase tracking-widest">{patient.lastUpdate}</span>
                </div>

                {/* Micro-pills for conditions */}
                <div className="flex flex-wrap gap-1.5 mb-3">
                  {patient.conditions?.map((c, i) => (
                    <span key={i} className="px-2 py-0.5 bg-slate-50 border border-slate-100 rounded-md text-[9px] font-black uppercase text-slate-500 tracking-tighter">
                      {c}
                    </span>
                  ))}
                </div>

                {/* Bottom Row Info */}
                <div className="flex justify-between items-center pt-2 border-t border-slate-50">
                  <div className="flex items-center space-x-1.5">
                    <div className="w-4 h-4 bg-blue-50 rounded-full flex items-center justify-center">
                      <svg className="w-2.5 h-2.5 text-blue-500" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M16 7a4 4 0 11-8 0 4 4 0 018 0zM12 14a7 7 0 00-7 7h14a7 7 0 00-7-7z" /></svg>
                    </div>
                    <span className="text-[11px] font-bold text-slate-400">{patient.caregiverName}</span>
                  </div>
                  
                  <div className="flex items-center space-x-1">
                    <span className="text-[10px] font-black uppercase text-blue-600 bg-blue-50 px-2 py-0.5 rounded-full">View Hub</span>
                    <svg className="w-4 h-4 text-blue-200" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M9 5l7 7-7 7" /></svg>
                  </div>
                </div>
              </div>
            </div>
          </div>
        ))}
      </div>
    </div>
  );
};
