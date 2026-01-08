
import React from 'react';
import { FileText, Download, Share2, Calendar, TrendingUp, Archive, Search, ChevronRight, Filter } from 'lucide-react';

const ReportsData: React.FC = () => {
  const reports = [
    { id: 1, name: 'Q3 Cardiac Screening', date: 'Oct 24, 2024', size: '2.4 MB', type: 'LAB' },
    { id: 2, name: 'Daily Activity Summary', date: 'Oct 20, 2024', size: '840 KB', type: 'PDF' },
    { id: 3, name: 'Prescription Renewal', date: 'Oct 15, 2024', size: '1.2 MB', type: 'DOC' },
  ];

  return (
    <div className="max-w-4xl mx-auto space-y-10 animate-in fade-in duration-700">
      <header className="px-4 flex items-center justify-between">
        <div>
          <h2 className="text-4xl font-bold text-black tracking-tight">Reports</h2>
          <p className="text-[#8E8E93] text-lg font-medium">Medical documents & health trends</p>
        </div>
        <div className="flex gap-2">
           <button className="p-3 bg-white rounded-full shadow-sm text-black"><Search size={20} /></button>
           <button className="p-3 bg-white rounded-full shadow-sm text-black"><Filter size={20} /></button>
        </div>
      </header>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-8 px-4">
        {/* Main Document List */}
        <section className="md:col-span-2 space-y-4">
          <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest px-2">Document Library</h3>
          <div className="ios-card bg-white shadow-sm overflow-hidden">
            {reports.map((report, idx) => (
              <div key={report.id} className="p-6 flex items-center gap-5 border-b border-[#F2F2F7] last:border-0 hover:bg-slate-50 transition-colors group cursor-pointer">
                <div className="w-14 h-14 bg-slate-50 text-[#8E8E93] rounded-2xl flex items-center justify-center group-hover:bg-blue-50 group-hover:text-[#007AFF] transition-all">
                  <FileText size={26} />
                </div>
                <div className="flex-1">
                  <h5 className="text-lg font-bold text-black">{report.name}</h5>
                  <p className="text-xs text-[#8E8E93] font-medium uppercase tracking-tight">
                    {report.date} • {report.size} • {report.type}
                  </p>
                </div>
                <div className="flex gap-2">
                  <button className="p-2.5 bg-slate-50 text-[#8E8E93] rounded-xl hover:bg-blue-50 hover:text-[#007AFF] transition-all"><Download size={18} /></button>
                  <button className="p-2.5 bg-slate-50 text-[#8E8E93] rounded-xl hover:bg-blue-50 hover:text-[#007AFF] transition-all"><Share2 size={18} /></button>
                </div>
              </div>
            ))}
            <button className="w-full py-5 text-[#007AFF] font-bold text-sm bg-slate-50/50 hover:bg-slate-100 transition-colors">
              Request Lab Data
            </button>
          </div>
        </section>

        {/* AI Trends Summary */}
        <section className="space-y-4">
          <h3 className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest px-2">AI Summary</h3>
          <div className="ios-card bg-white shadow-sm p-8 space-y-8">
            <div className="space-y-3">
              <div className="flex items-center gap-2 text-[#34C759]">
                 <TrendingUp size={18} strokeWidth={2.5} />
                 <span className="text-[10px] font-black uppercase tracking-widest">Positive Trend</span>
              </div>
              <p className="text-lg font-bold text-black leading-tight">Sleep recovery is up 15% this month.</p>
              <p className="text-sm text-[#8E8E93] font-medium">Eleanor's average deep sleep cycle has lengthened to 1.8 hours per night.</p>
            </div>
            
            <div className="pt-6 border-t border-[#F2F2F7] space-y-4">
               <button className="w-full bg-[#007AFF] text-white py-4 rounded-2xl font-bold text-sm shadow-md active:scale-95 transition-all">
                  Export PDF Report
               </button>
               <button className="w-full bg-[#F2F2F7] text-black py-4 rounded-2xl font-bold text-sm hover:bg-slate-200 transition-colors">
                  Archive All Docs
               </button>
            </div>
          </div>
        </section>
      </div>
    </div>
  );
};

export default ReportsData;
