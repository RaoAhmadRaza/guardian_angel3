
import React, { useState } from 'react';
import { MOCK_ALERTS } from '../constants';
import { ShieldAlert, Activity, MapPin, Pill, Check, Phone, MessageSquare, Bell, MoreHorizontal } from 'lucide-react';

const AlertsList: React.FC = () => {
  const [alerts, setAlerts] = useState([...MOCK_ALERTS]);

  const toggleResolved = (id: string) => {
    setAlerts(prev => prev.map(a => a.id === id ? { ...a, resolved: !a.resolved } : a));
  };

  const getIcon = (type: string) => {
    switch (type) {
      case 'SOS': return <ShieldAlert size={22} strokeWidth={2.5} />;
      case 'Fall': return <Activity size={22} strokeWidth={2.5} />;
      case 'Geo-Fence': return <MapPin size={22} strokeWidth={2.5} />;
      case 'Medication': return <Pill size={22} strokeWidth={2.5} />;
      default: return <Bell size={22} strokeWidth={2.5} />;
    }
  };

  const getColorStyles = (type: string, resolved: boolean) => {
    if (resolved) return 'bg-white opacity-60';
    switch (type) {
      case 'SOS': return 'bg-white ring-2 ring-[#FF3B30] shadow-xl shadow-rose-100';
      case 'Fall': return 'bg-white ring-2 ring-[#FF9500] shadow-xl shadow-orange-100';
      case 'Geo-Fence': return 'bg-white shadow-sm';
      default: return 'bg-white shadow-sm';
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-8 animate-in fade-in duration-700">
      <header className="px-4 flex items-center justify-between">
        <div>
          <h2 className="text-4xl font-bold text-black tracking-tight">Alerts</h2>
          <p className="text-[#8E8E93] text-lg font-medium">You have {alerts.filter(a => !a.resolved).length} active notifications</p>
        </div>
        <button className="p-2 bg-white rounded-full shadow-sm text-black">
          <MoreHorizontal size={20} />
        </button>
      </header>

      <div className="space-y-4 px-2">
        {alerts.map((alert) => (
          <div 
            key={alert.id} 
            className={`ios-card p-6 transition-all duration-300 ${getColorStyles(alert.type, alert.resolved)}`}
          >
            <div className="flex gap-5">
              <div className={`w-14 h-14 rounded-[22px] flex items-center justify-center flex-shrink-0 ${
                alert.resolved ? 'bg-slate-100 text-slate-400' : 
                alert.type === 'SOS' ? 'bg-rose-50 text-[#FF3B30]' : 
                alert.type === 'Fall' ? 'bg-orange-50 text-[#FF9500]' : 
                'bg-blue-50 text-[#007AFF]'
              }`}>
                {getIcon(alert.type)}
              </div>
              
              <div className="flex-1 space-y-1">
                <div className="flex items-center justify-between">
                  <span className={`text-xs font-black uppercase tracking-widest ${
                    alert.resolved ? 'text-slate-400' : 'text-black'
                  }`}>{alert.type} Alert</span>
                  <span className="text-[11px] font-bold text-[#8E8E93]">{alert.timestamp}</span>
                </div>
                <p className={`text-lg font-semibold leading-tight ${alert.resolved ? 'text-slate-500' : 'text-black'}`}>
                  {alert.description}
                </p>
                
                {!alert.resolved && (
                  <div className="flex gap-3 pt-4">
                    <button className="flex-1 bg-[#007AFF] text-white py-3 rounded-xl font-bold text-sm shadow-md active:scale-95 transition-all flex items-center justify-center gap-2">
                      <Phone size={14} fill="white" /> Call
                    </button>
                    <button 
                      onClick={() => toggleResolved(alert.id)}
                      className="flex-1 bg-[#F2F2F7] text-black py-3 rounded-xl font-bold text-sm hover:bg-slate-200 transition-colors flex items-center justify-center gap-2"
                    >
                      <Check size={14} strokeWidth={3} /> Clear
                    </button>
                  </div>
                )}
                {alert.resolved && (
                  <div className="flex items-center gap-2 text-[#34C759] pt-2">
                    <Check size={14} strokeWidth={3} />
                    <span className="text-xs font-bold uppercase tracking-widest">Resolved</span>
                  </div>
                )}
              </div>
            </div>
          </div>
        ))}
      </div>
      
      {alerts.length === 0 && (
        <div className="py-20 text-center space-y-4">
           <div className="w-20 h-20 bg-white rounded-full shadow-sm flex items-center justify-center mx-auto text-slate-200">
              <Bell size={40} />
           </div>
           <p className="text-[#8E8E93] font-bold uppercase tracking-widest text-xs">No active alerts</p>
        </div>
      )}
    </div>
  );
};

export default AlertsList;
