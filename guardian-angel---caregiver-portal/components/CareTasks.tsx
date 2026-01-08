
import React, { useState } from 'react';
import { Plus, CheckCircle2, Clock, Info, ChevronRight } from 'lucide-react';

const CareTasks: React.FC = () => {
  const [activeTab, setActiveTab] = useState<'Pending' | 'Completed'>('Pending');

  const tasks = [
    { id: '1', title: 'Upload Blood Lab Results', time: 'By 5:00 PM', status: 'Pending', type: 'Report' },
    { id: '2', title: 'Schedule Eye Appointment', time: 'This Week', status: 'Pending', type: 'Appointment' },
    { id: '3', title: 'Refill Heart Medication', time: 'Tomorrow', status: 'Pending', type: 'Medication' },
    { id: '4', title: 'Morning Walk recorded', time: 'Done', status: 'Completed', type: 'Activity' },
    { id: '5', title: 'Weekly weight log', time: 'Done', status: 'Completed', type: 'Health' },
  ];

  const filteredTasks = tasks.filter(t => t.status === activeTab);

  return (
    <div className="max-w-2xl mx-auto space-y-8 animate-in fade-in duration-700">
      <header className="px-4 flex items-center justify-between">
        <div>
          <h2 className="text-4xl font-bold text-black tracking-tight">Tasks</h2>
          <p className="text-[#8E8E93] text-lg font-medium">{tasks.filter(t => t.status === 'Pending').length} actions required</p>
        </div>
        <button className="w-12 h-12 bg-black text-white rounded-full shadow-lg flex items-center justify-center hover:scale-105 active:scale-95 transition-all">
          <Plus size={24} strokeWidth={2.5} />
        </button>
      </header>

      {/* iOS Segmented Control */}
      <div className="px-4">
        <div className="bg-[#E3E3E8] p-1 rounded-2xl flex relative h-12 shadow-inner">
          <div 
            className={`absolute top-1 bottom-1 w-[calc(50%-4px)] bg-white rounded-xl shadow-sm transition-all duration-300 ease-out ${
              activeTab === 'Completed' ? 'translate-x-[calc(100%+4px)]' : 'translate-x-0'
            }`}
          />
          <button
            onClick={() => setActiveTab('Pending')}
            className={`flex-1 relative z-10 font-bold text-sm transition-colors duration-200 ${
              activeTab === 'Pending' ? 'text-black' : 'text-[#8E8E93]'
            }`}
          >
            Pending
          </button>
          <button
            onClick={() => setActiveTab('Completed')}
            className={`flex-1 relative z-10 font-bold text-sm transition-colors duration-200 ${
              activeTab === 'Completed' ? 'text-black' : 'text-[#8E8E93]'
            }`}
          >
            Completed
          </button>
        </div>
      </div>

      <div className="space-y-3 px-4">
        {filteredTasks.length > 0 ? (
          filteredTasks.map((task) => (
            <div 
              key={task.id} 
              className="ios-card p-5 bg-white shadow-sm flex items-center gap-5 hover:bg-slate-50 transition-colors group cursor-pointer active:scale-[0.98]"
            >
              <div className={`w-12 h-12 rounded-[18px] flex items-center justify-center flex-shrink-0 transition-all ${
                activeTab === 'Completed' ? 'bg-emerald-50 text-[#34C759]' : 'bg-blue-50 text-[#007AFF] group-hover:bg-[#007AFF] group-hover:text-white'
              }`}>
                <CheckCircle2 size={24} strokeWidth={2.5} />
              </div>
              <div className="flex-1">
                <h4 className={`text-lg font-bold leading-tight ${activeTab === 'Completed' ? 'text-[#C7C7CC] line-through' : 'text-black'}`}>
                  {task.title}
                </h4>
                <div className="flex items-center gap-3 mt-1">
                  <span className="text-[10px] font-black uppercase tracking-widest text-[#8E8E93]">{task.type}</span>
                  <span className="w-1 h-1 bg-slate-200 rounded-full"></span>
                  <span className="text-[10px] font-bold text-[#8E8E93]">{task.time}</span>
                </div>
              </div>
              <ChevronRight size={18} className="text-[#C7C7CC] group-hover:translate-x-1 transition-transform" />
            </div>
          ))
        ) : (
          <div className="py-20 text-center">
             <div className="p-8 bg-white rounded-full shadow-sm inline-block text-slate-100 mb-4">
                <CheckCircle2 size={40} />
             </div>
             <p className="text-[#8E8E93] font-bold text-xs uppercase tracking-widest">All caught up!</p>
          </div>
        )}
      </div>
    </div>
  );
};

export default CareTasks;
