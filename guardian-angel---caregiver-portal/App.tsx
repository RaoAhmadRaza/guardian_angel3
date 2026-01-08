import React, { useState } from 'react';
import { HashRouter as Router, Routes, Route, useNavigate, useLocation } from 'react-router-dom';
import Dashboard from './components/Dashboard';
import PatientOverview from './components/PatientOverview';
import AlertsList from './components/Alerts';
import CareTasks from './components/CareTasks';
import ReportsData from './components/Reports';
import CommunicationHub from './components/Communication';
import PatientChat from './components/PatientChat';
import DoctorChat from './components/DoctorChat';
import AIChat from './components/AIChat';
import SettingsView from './components/Settings';
import CallScreen from './components/CallScreen';
import { NAVIGATION_ITEMS } from './constants';

const Sidebar = () => {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <div className="hidden lg:flex flex-col w-72 h-screen sticky top-0 p-6">
      <div className="mb-10 flex items-center gap-3 px-3">
        <div className="w-9 h-9 bg-[#007AFF] rounded-xl flex items-center justify-center shadow-lg shadow-blue-200/50">
          <div className="w-3 h-3 bg-white rounded-full"></div>
        </div>
        <h1 className="text-xl font-semibold text-black tracking-tight">
          Guardian
        </h1>
      </div>
      
      <nav className="flex-1 space-y-1">
        {NAVIGATION_ITEMS.map((item) => {
          const isActive = (location.pathname === `/${item.id}`) || (location.pathname === '/' && item.id === 'dashboard');
          return (
            <button
              key={item.id}
              onClick={() => navigate(`/${item.id}`)}
              className={`w-full flex items-center gap-3.5 px-4 py-3 rounded-xl transition-all duration-200 group ${
                isActive 
                  ? 'bg-white shadow-sm font-semibold text-[#007AFF]' 
                  : 'text-[#8E8E93] hover:bg-white/50 hover:text-black'
              }`}
            >
              <item.icon size={20} className={isActive ? 'text-[#007AFF]' : 'text-[#8E8E93] group-hover:text-black'} strokeWidth={isActive ? 2.5 : 2} />
              <span className="text-[15px]">{item.label}</span>
            </button>
          );
        })}
      </nav>

      <div className="mt-auto pt-6 border-t border-black/5">
        <div className="flex items-center gap-3 px-2">
          <img src="https://picsum.photos/id/177/100/100" alt="Sarah J." className="w-10 h-10 rounded-full object-cover ring-2 ring-white shadow-sm" />
          <div className="flex flex-col">
            <p className="text-sm font-semibold text-black leading-tight">Sarah Jenkins</p>
            <p className="text-[12px] text-[#8E8E93] font-medium uppercase tracking-tight">Primary Caregiver</p>
          </div>
        </div>
      </div>
    </div>
  );
};

const MobileNav = () => {
  const navigate = useNavigate();
  const location = useLocation();

  return (
    <div className="lg:hidden fixed bottom-0 left-0 right-0 glass border-t border-black/5 px-6 pt-3 pb-8 flex justify-around items-center z-50">
      {NAVIGATION_ITEMS.slice(0, 5).map((item) => {
        const isActive = location.pathname.startsWith(`/${item.id}`) || (location.pathname === '/' && item.id === 'dashboard');
        return (
          <button
            key={item.id}
            onClick={() => navigate(`/${item.id}`)}
            className={`flex flex-col items-center gap-1 transition-all ${
              isActive ? 'text-[#007AFF]' : 'text-[#8E8E93]'
            }`}
          >
            <item.icon size={24} strokeWidth={isActive ? 2.5 : 2} />
            <span className="text-[10px] font-medium">{item.label}</span>
          </button>
        );
      })}
    </div>
  );
};

export const CallContext = React.createContext<{ startCall: () => void }>({ startCall: () => {} });

// Fixed: Change children to be optional to resolve the 'missing property' error in line 119
const LayoutWrapper = ({ children }: { children?: React.ReactNode }) => {
  const location = useLocation();
  const isChatScreen = location.pathname.startsWith('/chat/patient') || 
                       location.pathname.startsWith('/chat/doctor') || 
                       location.pathname.startsWith('/chat/ai');

  return (
    <div className="flex min-h-screen bg-[#F2F2F7]">
      {!isChatScreen && <Sidebar />}
      <main className={`flex-1 w-full ${isChatScreen ? 'p-0 h-screen' : 'p-6 md:p-10 lg:p-12 pb-32 lg:pb-12 max-w-screen-xl mx-auto'}`}>
        {children}
      </main>
      {!isChatScreen && <MobileNav />}
    </div>
  );
};

// Removed React.FC explicit type to prevent strict children requirement in certain TS/React environments
const App = () => {
  const [isCalling, setIsCalling] = useState(false);

  const startCall = () => setIsCalling(true);
  const endCall = () => setIsCalling(false);

  return (
    <CallContext.Provider value={{ startCall }}>
      <Router>
        {isCalling && <CallScreen onEndCall={endCall} />}
        <LayoutWrapper>
          <Routes>
            <Route path="/" element={<Dashboard />} />
            <Route path="/dashboard" element={<Dashboard />} />
            <Route path="/patient" element={<PatientOverview />} />
            <Route path="/alerts" element={<AlertsList />} />
            <Route path="/tasks" element={<CareTasks />} />
            <Route path="/reports" element={<ReportsData />} />
            <Route path="/chat" element={<CommunicationHub />} />
            <Route path="/chat/patient" element={<PatientChat />} />
            <Route path="/chat/doctor" element={<DoctorChat />} />
            <Route path="/chat/ai" element={<AIChat />} />
            <Route path="/settings" element={<SettingsView />} />
          </Routes>
        </LayoutWrapper>
      </Router>
    </CallContext.Provider>
  );
};

export default App;