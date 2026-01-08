
import React, { useEffect, useState } from 'react';
import { PhoneOff, MicOff, Volume2, Video, Grid, UserPlus, MessageCircle } from 'lucide-react';
import { MOCK_PATIENT } from '../constants';

interface CallScreenProps {
  onEndCall: () => void;
  callerName?: string;
  callerPhoto?: string;
  isIncoming?: boolean;
}

const CallScreen: React.FC<CallScreenProps> = ({ onEndCall, callerName = MOCK_PATIENT.name, callerPhoto = MOCK_PATIENT.photoUrl }) => {
  const [callTime, setCallTime] = useState(0);

  useEffect(() => {
    const timer = setInterval(() => {
      setCallTime((prev) => prev + 1);
    }, 1000);
    return () => clearInterval(timer);
  }, []);

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  return (
    <div className="fixed inset-0 z-[100] bg-black flex flex-col items-center justify-between py-24 px-8 overflow-hidden">
      {/* Blurred Background */}
      <div className="absolute inset-0 opacity-40">
        <img src={callerPhoto} className="w-full h-full object-cover blur-3xl scale-150" alt="" />
      </div>

      {/* Caller Info */}
      <div className="relative z-10 flex flex-col items-center space-y-4">
        <div className="w-32 h-32 rounded-full overflow-hidden border-4 border-white/20 shadow-2xl ios-float">
          <img src={callerPhoto} className="w-full h-full object-cover" alt={callerName} />
        </div>
        <div className="text-center">
          <h2 className="text-3xl font-bold text-white tracking-tight">{callerName}</h2>
          <p className="text-white/60 font-medium text-lg mt-1 tracking-widest">{formatTime(callTime)}</p>
        </div>
      </div>

      {/* Call Controls - iOS Style Grid */}
      <div className="relative z-10 w-full max-w-xs space-y-8">
        <div className="grid grid-cols-3 gap-y-8 gap-x-4">
          {[
            { icon: MicOff, label: 'mute' },
            { icon: Grid, label: 'keypad' },
            { icon: Volume2, label: 'speaker' },
            { icon: UserPlus, label: 'add call' },
            { icon: Video, label: 'FaceTime' },
            { icon: MessageCircle, label: 'contacts' },
          ].map((item, idx) => (
            <div key={idx} className="flex flex-col items-center space-y-2">
              <button className="w-16 h-16 rounded-full bg-white/10 backdrop-blur-md flex items-center justify-center text-white hover:bg-white/20 transition-all active:scale-90 border border-white/5">
                <item.icon size={28} />
              </button>
              <span className="text-[11px] font-bold text-white/70 uppercase tracking-widest">{item.label}</span>
            </div>
          ))}
        </div>

        {/* End Call Button */}
        <div className="flex justify-center pt-8">
          <button 
            onClick={onEndCall}
            className="w-20 h-20 rounded-full bg-[#FF3B30] flex items-center justify-center text-white shadow-2xl shadow-rose-900/40 active:scale-95 transition-transform"
          >
            <PhoneOff size={32} strokeWidth={2.5} />
          </button>
        </div>
      </div>
    </div>
  );
};

export default CallScreen;
