
import React, { useState } from 'react';
import { reports } from '../mockData';
import { Patient } from '../types';
import { summarizeReport } from '../services/geminiService';

export const ReportsScreen: React.FC<{ patient: Patient | null }> = ({ patient }) => {
  const [selectedReportId, setSelectedReportId] = useState<string | null>(null);
  const [summary, setSummary] = useState<any>(null);
  const [loading, setLoading] = useState(false);

  const handleSummarize = async () => {
    setLoading(true);
    const mockContent = "Patient exhibits stable respiratory patterns. Labs indicate elevated glucose at 124 mg/dL. Cardiovascular rhythm is Sinus. Recommendation: Monitor glucose levels weekly.";
    const result = await summarizeReport(mockContent);
    setSummary(result);
    setLoading(false);
  };

  const selectedReport = reports.find(r => r.id === selectedReportId);

  if (selectedReportId) {
    return (
      <div className="flex flex-col p-4 space-y-4 animate-in slide-in-from-right duration-300">
        <button 
          onClick={() => { setSelectedReportId(null); setSummary(null); }}
          className="flex items-center text-blue-600 font-bold text-sm mb-2"
        >
          <svg className="w-4 h-4 mr-1" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M15 19l-7-7 7-7" /></svg>
          Back to List
        </button>

        <div className="bg-white rounded-[28px] p-6 shadow-sm border border-slate-100">
          <h2 className="text-xl font-black text-slate-900 mb-1">{selectedReport?.type}</h2>
          <p className="text-xs text-slate-400 font-bold uppercase tracking-widest mb-6">{selectedReport?.date} • {selectedReport?.source}</p>
          
          <div className="flex space-x-2 mb-8">
            <button 
              onClick={handleSummarize}
              disabled={loading}
              className="flex-1 bg-indigo-600 text-white py-3 rounded-2xl text-sm font-bold shadow-lg shadow-indigo-100 flex items-center justify-center disabled:opacity-50"
            >
              <svg className="w-4 h-4 mr-2" fill="currentColor" viewBox="0 0 20 20"><path d="M13 6a3 3 0 11-6 0 3 3 0 016 0zM18 8a2 2 0 11-4 0 2 2 0 014 0zM14 15a4 4 0 00-8 0v3h8v-3zM6 8a2 2 0 11-4 0 2 2 0 014 0zM16 18v-3a5.972 5.972 0 00-.75-2.906A3.005 3.005 0 0119 15v3h-3zM4.75 12.094A5.973 5.973 0 004 15v3H1v-3a3 3 0 013.75-2.906z" /></svg>
              {loading ? 'Analyzing...' : 'AI Summary'}
            </button>
            <button className="bg-slate-100 text-slate-600 px-5 rounded-2xl text-xs font-bold">Original</button>
          </div>

          {summary ? (
            <div className="space-y-6 animate-in fade-in zoom-in-95 duration-500">
              <div className="bg-indigo-50/50 p-5 rounded-3xl border border-indigo-100/50">
                 <p className="text-sm font-medium text-slate-800 leading-relaxed mb-4">{summary.summary}</p>
                 <div className="space-y-4">
                   <div>
                     <p className="text-[10px] font-black text-indigo-600 uppercase mb-2 tracking-widest">Findings</p>
                     <ul className="space-y-1.5">
                       {summary.keyFindings.map((f: string, i: number) => (
                         <li key={i} className="text-xs text-slate-600 flex items-start">
                           <span className="text-indigo-400 mr-2 font-bold">•</span> {f}
                         </li>
                       ))}
                     </ul>
                   </div>
                 </div>
              </div>
            </div>
          ) : (
            <div className="h-64 rounded-3xl bg-slate-50 border-2 border-dashed border-slate-100 flex flex-col items-center justify-center text-slate-400">
               <svg className="w-12 h-12 mb-2 opacity-30" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="1.5" d="M4 16l4.586-4.586a2 2 0 012.828 0L16 16m-2-2l1.586-1.586a2 2 0 012.828 0L20 14m-6-6h.01M6 20h12a2 2 0 002-2V6a2 2 0 00-2-2H6a2 2 0 00-2 2v12a2 2 0 002 2z" /></svg>
               <span className="text-xs font-bold">Document Preview Encrypted</span>
            </div>
          )}
        </div>
      </div>
    );
  }

  return (
    <div className="p-4 space-y-4">
      <div className="mb-2">
        <p className="text-xs font-black uppercase text-slate-400 tracking-widest mb-1">Clinical Vault</p>
        <h2 className="text-2xl font-black text-slate-900">Patient Reports</h2>
      </div>

      <div className="space-y-3">
        {reports.map((report) => (
          <div 
            key={report.id}
            onClick={() => setSelectedReportId(report.id)}
            className="bg-white p-4 rounded-[24px] border border-slate-100 shadow-sm flex items-center active:scale-[0.98] transition-all"
          >
            <div className="w-12 h-12 bg-blue-50 rounded-2xl flex items-center justify-center text-blue-600 mr-4">
               <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M9 12h6m-6 4h6m2 5H7a2 2 0 01-2-2V5a2 2 0 012-2h5.586a1 1 0 01.707.293l5.414 5.414a1 1 0 01.293.707V19a2 2 0 01-2 2z" /></svg>
            </div>
            <div className="flex-1 min-w-0">
               <h4 className="font-bold text-slate-900 truncate">{report.type}</h4>
               <p className="text-xs text-slate-400 font-medium">{report.date} • {report.source}</p>
            </div>
            <svg className="w-5 h-5 text-slate-300" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M9 5l7 7-7 7" /></svg>
          </div>
        ))}
      </div>
    </div>
  );
};
