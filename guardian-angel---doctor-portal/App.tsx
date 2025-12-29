import React, { useState } from 'react';
import { PatientList } from './screens/PatientList';
import { PatientOverview } from './screens/PatientOverview';
import { ReportsScreen } from './screens/ReportsScreen';
import { ChatScreen } from './screens/ChatScreen';
import { NotesScreen } from './screens/NotesScreen';
import { ScheduleScreen } from './screens/ScheduleScreen';
import { Patient } from './types';

type Screen = 'patients' | 'overview' | 'reports' | 'chat' | 'notes' | 'schedule';

const App: React.FC = () => {
  const [currentScreen, setCurrentScreen] = useState<Screen>('patients');
  const [selectedPatient, setSelectedPatient] = useState<Patient | null>(null);
  const [isConnectModalOpen, setIsConnectModalOpen] = useState(false);
  const [isDoctorModalOpen, setIsDoctorModalOpen] = useState(false);

  const navigateTo = (screen: Screen, patient?: Patient) => {
    if (patient) setSelectedPatient(patient);
    setCurrentScreen(screen);
    window.scrollTo(0, 0);
  };

  const renderScreen = () => {
    switch (currentScreen) {
      case 'patients':
        return <PatientList onSelectPatient={(p) => navigateTo('overview', p)} onConnectNew={() => setIsConnectModalOpen(true)} />;
      case 'overview':
        return selectedPatient ? (
          <PatientOverview 
            patient={selectedPatient} 
            onNavigate={(screen) => navigateTo(screen)}
          />
        ) : <PatientList onSelectPatient={(p) => navigateTo('overview', p)} onConnectNew={() => setIsConnectModalOpen(true)} />;
      case 'reports':
        return <ReportsScreen patient={selectedPatient} />;
      case 'chat':
        return <ChatScreen patient={selectedPatient} onBack={() => navigateTo('overview')} />;
      case 'notes':
        return <NotesScreen patient={selectedPatient} />;
      case 'schedule':
        return <ScheduleScreen patient={selectedPatient} />;
      default:
        return <PatientList onSelectPatient={(p) => navigateTo('overview', p)} onConnectNew={() => setIsConnectModalOpen(true)} />;
    }
  };

  const isDetailView = ['overview', 'reports', 'chat', 'notes', 'schedule'].includes(currentScreen);

  return (
    <div className="flex flex-col h-screen bg-[#F8FAFC] text-slate-900 font-sans select-none overflow-hidden">
      {/* Premium Header */}
      <header className="bg-white/70 backdrop-blur-2xl border-b border-slate-100 px-6 py-4 sticky top-0 z-30 flex justify-between items-center h-16 shrink-0 shadow-[0_1px_2px_rgba(0,0,0,0.02)]">
        <div className="flex items-center space-x-3">
          {isDetailView && (
            <button 
              onClick={() => navigateTo(currentScreen === 'overview' ? 'patients' : 'overview')}
              className="p-2 -ml-2 text-slate-900 active:bg-slate-100 rounded-full transition-colors"
            >
              <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="3" d="M15 19l-7-7 7-7" /></svg>
            </button>
          )}
          <h1 className="text-xl font-[800] tracking-tight text-slate-900">
            {currentScreen === 'patients' ? 'Welcome Doctor' : (selectedPatient?.name || 'Guardian')}
          </h1>
        </div>
        <div className="flex items-center space-x-3">
          <button className="relative p-2 text-slate-900 active:scale-95 transition-transform">
            <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.2" d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" /></svg>
            <span className="absolute top-2 right-2 w-2 h-2 bg-rose-500 rounded-full ring-2 ring-white"></span>
          </button>
          <button 
            onClick={() => setIsDoctorModalOpen(true)}
            className="active:scale-95 transition-transform"
          >
            <img src="https://picsum.photos/seed/doctor/40" className="w-8 h-8 rounded-xl shadow-sm ring-1 ring-slate-100" alt="Doctor" />
          </button>
        </div>
      </header>

      {/* Content Area */}
      <main className="flex-1 overflow-y-auto pb-8">
        {renderScreen()}
      </main>

      {/* Connect New Patient Modal */}
      {isConnectModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-slate-900/40 backdrop-blur-md animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-sm rounded-[32px] p-8 shadow-2xl animate-in zoom-in-95 duration-300">
            <div className="flex justify-between items-start mb-6">
              <div className="w-12 h-12 bg-blue-50 rounded-2xl flex items-center justify-center text-blue-600">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M18 9v3m0 0v3m0-3h3m-3 0h-3m-2-5a4 4 0 11-8 0 4 4 0 018 0zM3 20a6 6 0 0112 0v1H3v-1z" /></svg>
              </div>
              <button onClick={() => setIsConnectModalOpen(false)} className="p-2 text-slate-300 hover:text-slate-500 transition-colors">
                <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
              </button>
            </div>
            
            <h2 className="text-2xl font-black text-slate-900 mb-2 leading-tight">Connect New Case</h2>
            <p className="text-sm text-slate-500 font-medium mb-8 leading-relaxed">
              Enter the unique Guardian ID provided by the primary caregiver to request clinical access.
            </p>

            <div className="space-y-6">
              <div>
                <label className="block text-[10px] font-black uppercase text-slate-400 mb-2 tracking-widest">Guardian ID / Access Code</label>
                <input 
                  type="text" 
                  placeholder="e.g. GA-8829-XP" 
                  className="w-full px-5 py-4 bg-slate-50 border border-slate-100 rounded-2xl text-lg font-bold placeholder:text-slate-300 focus:ring-4 focus:ring-blue-100 transition-all outline-none"
                />
              </div>

              <div className="bg-amber-50 rounded-2xl p-4 border border-amber-100">
                <div className="flex items-start space-x-3">
                  <svg className="w-5 h-5 text-amber-500 shrink-0 mt-0.5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M13 16h-1v-4h-1m1-4h.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" /></svg>
                  <p className="text-[11px] font-bold text-amber-700 leading-normal">
                    By initiating connection, you verify that you have received patient consent for shared clinical monitoring.
                  </p>
                </div>
              </div>

              <button 
                onClick={() => setIsConnectModalOpen(false)}
                className="w-full py-4 bg-blue-600 text-white rounded-[20px] font-bold shadow-xl shadow-blue-200 active:scale-95 transition-all"
              >
                Request Connection
              </button>
            </div>
          </div>
        </div>
      )}

      {/* Doctor Detail Modal */}
      {isDoctorModalOpen && (
        <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-slate-900/40 backdrop-blur-md animate-in fade-in duration-300">
          <div className="bg-white w-full max-w-sm rounded-[32px] overflow-hidden shadow-2xl animate-in zoom-in-95 duration-300 relative border border-white/50">
            {/* Subtle Top Accent Line */}
            <div className="h-1.5 w-full bg-gradient-to-r from-blue-500 via-indigo-600 to-purple-600"></div>
            
            <button 
              onClick={() => setIsDoctorModalOpen(false)} 
              className="absolute top-4 right-4 p-2 text-slate-300 hover:text-slate-500 active:scale-90 transition-all z-10"
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M6 18L18 6M6 6l12 12" /></svg>
            </button>
            
            <div className="px-8 pb-8 pt-10 flex flex-col items-center">
              <div className="relative mb-5">
                <img src="https://picsum.photos/seed/doctor/120" className="w-24 h-24 rounded-[32px] border-4 border-slate-50 shadow-md" alt="Doctor" />
                <div className="absolute -bottom-1 -right-1 w-6 h-6 bg-emerald-500 border-4 border-white rounded-full"></div>
              </div>

              <h2 className="text-2xl font-black text-slate-900 mb-0.5">Dr. Julian Smith</h2>
              <p className="text-xs font-black text-blue-600 uppercase tracking-widest mb-8">Chief of Geriatrics</p>
              
              <div className="w-full space-y-4 mb-10">
                <div className="bg-slate-50 p-4 rounded-2xl border border-slate-100 flex items-center space-x-4">
                  <div className="w-10 h-10 bg-white rounded-xl shadow-sm flex items-center justify-center text-slate-400">
                    <svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M19 21V5a2 2 0 00-2-2H7a2 2 0 00-2 2v16m14 0h2m-2 0h-5m-9 0H3m2 0h5M9 7h1m-1 4h1m4-4h1m-1 4h1m-5 10v-5a1 1 0 011-1h2a1 1 0 011 1v5m-4 0h4" /></svg>
                  </div>
                  <div>
                    <p className="text-[10px] font-black uppercase text-slate-400 tracking-widest leading-none mb-1">Affiliation</p>
                    <p className="text-sm font-bold text-slate-800 leading-none">Guardian Clinical Group</p>
                  </div>
                </div>
                
                <div className="flex space-x-3">
                   <div className="flex-1 bg-slate-50 p-4 rounded-2xl border border-slate-100 text-center">
                     <p className="text-[10px] font-black uppercase text-slate-400 mb-1 tracking-widest">Active Cases</p>
                     <p className="text-lg font-black text-slate-800">3</p>
                   </div>
                   <div className="flex-1 bg-slate-50 p-4 rounded-2xl border border-slate-100 text-center">
                     <p className="text-[10px] font-black uppercase text-slate-400 mb-1 tracking-widest">Pending</p>
                     <p className="text-lg font-black text-rose-500">1</p>
                   </div>
                </div>
              </div>

              <div className="w-full space-y-3">
                <button className="w-full py-4 bg-slate-900 text-white rounded-2xl font-bold text-sm shadow-xl shadow-slate-200 active:scale-95 transition-all">
                  Account Settings
                </button>
                <button 
                  onClick={() => setIsDoctorModalOpen(false)}
                  className="w-full py-4 bg-white text-rose-500 border border-rose-50 rounded-2xl font-bold text-sm hover:bg-rose-50/30 active:scale-95 transition-all"
                >
                  Sign Out
                </button>
              </div>
            </div>
          </div>
        </div>
      )}
    </div>
  );
};

export default App;