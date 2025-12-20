import React, { useEffect, useState, useRef } from 'react';
import { Activity, MapPin, Mic, Phone, ChevronRight, AlertTriangle, ShieldCheck, X, CreditCard, Ambulance } from 'lucide-react';

interface SOSModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const SOSModal: React.FC<SOSModalProps> = ({ isOpen, onClose }) => {
  const [timer, setTimer] = useState(0);
  const [statusStep, setStatusStep] = useState(0); // 0: Sending, 1: Notified, 2: Services
  const [sliderValue, setSliderValue] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const [medicalIdSent, setMedicalIdSent] = useState(false);
  const [showCancelConfirmation, setShowCancelConfirmation] = useState(false);
  
  const sliderRef = useRef<HTMLDivElement>(null);
  const startXRef = useRef(0);
  const [transcript, setTranscript] = useState<string[]>([]);

  useEffect(() => {
    if (isOpen) {
      setTimer(0);
      setStatusStep(0);
      setTranscript([]);
      setSliderValue(0);
      setMedicalIdSent(false);
      setShowCancelConfirmation(false);
      
      const interval = setInterval(() => setTimer(t => t + 1), 1000);
      
      // Simulate Status Progression
      setTimeout(() => setStatusStep(1), 2500); // Family notified
      setTimeout(() => setMedicalIdSent(true), 4000); // Medical ID Shared
      setTimeout(() => setStatusStep(2), 8000); // Emergency Services contacting

      // Simulate Transcription
      setTimeout(() => setTranscript(p => [...p, "I've fallen..."]), 2000);
      setTimeout(() => setTranscript(p => [...p, "My leg hurts."]), 5000);

      return () => clearInterval(interval);
    }
  }, [isOpen]);

  // Slider Logic
  const handleDragStart = (e: React.MouseEvent | React.TouchEvent) => {
    if (showCancelConfirmation) return;
    setIsDragging(true);
    startXRef.current = 'touches' in e ? e.touches[0].clientX : e.clientX;
  };

  const handleDragMove = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isDragging || !sliderRef.current || showCancelConfirmation) return;
    const currentX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const diff = currentX - startXRef.current;
    const maxDrag = sliderRef.current.clientWidth - 64; // Track width - Thumb width
    
    // Allow dragging only to the right
    const newValue = Math.max(0, Math.min(diff, maxDrag));
    setSliderValue(newValue);

    // Cancel Threshold (90%)
    if (newValue >= maxDrag * 0.9) {
        setIsDragging(false);
        setShowCancelConfirmation(true);
    }
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    if (!showCancelConfirmation) {
        setSliderValue(0);
    }
  };

  const formatTime = (seconds: number) => {
    const mins = Math.floor(seconds / 60);
    const secs = seconds % 60;
    return `${mins}:${secs.toString().padStart(2, '0')}`;
  };

  if (!isOpen) return null;

  return (
    <div className="fixed inset-0 z-[60] bg-[#1C1C1E] text-white flex flex-col safe-area-top safe-area-bottom overflow-hidden font-sans">
      <style>{`
        @keyframes shimmer {
          0% { background-position: -200% center; }
          100% { background-position: 200% center; }
        }
        .animate-shimmer {
          animation: shimmer 2.5s linear infinite;
        }
        @keyframes sonar {
          0% { transform: scale(1); opacity: 0.8; }
          100% { transform: scale(3); opacity: 0; }
        }
        .animate-sonar {
          animation: sonar 2s ease-out infinite;
        }
      `}</style>
      
      {/* 1. Ambient Glow Background */}
      <div className="absolute inset-0 z-0 pointer-events-none overflow-hidden">
           {/* Main Red Pulse */}
           <div className="absolute top-1/4 left-1/2 -translate-x-1/2 w-[500px] h-[500px] bg-red-600/20 rounded-full blur-[120px] animate-pulse-slow" />
           {/* Secondary darker accent */}
           <div className="absolute bottom-0 left-0 right-0 h-1/2 bg-gradient-to-t from-red-900/10 to-transparent" />
      </div>

      {/* Header Info (Top Bar) */}
      <div className="relative z-10 px-6 pt-6 flex justify-between items-center">
          <div className="flex items-center gap-2 bg-white/10 backdrop-blur-md px-3 py-1.5 rounded-full border border-white/5">
              <ShieldCheck className="w-4 h-4 text-green-400" />
              <span className="text-xs font-semibold text-gray-200">Active Monitoring</span>
          </div>
          <div className="flex items-center gap-2 text-gray-400 text-xs font-mono bg-black/20 px-2 py-1 rounded-lg">
              <span>{formatTime(timer)}</span>
              <div className="w-1.5 h-1.5 rounded-full bg-red-500 animate-pulse" />
          </div>
      </div>

      {/* 2. Live Status Tracker (Center) */}
      <div className="relative z-10 flex-1 flex flex-col items-center justify-center -mt-8">
          
          {/* 1. THE SONAR PULSE */}
          <div className="relative mb-10 flex items-center justify-center">
               {/* Expanding Rings */}
               <div className="absolute w-32 h-32 rounded-full border-2 border-red-500/50 animate-sonar" />
               <div className="absolute w-32 h-32 rounded-full border border-red-500/30 animate-sonar" style={{ animationDelay: '0.6s' }} />
               <div className="absolute w-32 h-32 rounded-full border border-red-500/10 animate-sonar" style={{ animationDelay: '1.2s' }} />
               
               {/* Main Icon */}
               <div className="w-32 h-32 bg-gradient-to-b from-red-500 to-red-700 rounded-full flex items-center justify-center shadow-[0_0_50px_rgba(239,68,68,0.5)] border-4 border-[#1C1C1E] relative z-10">
                    <Phone className="w-14 h-14 text-white fill-current animate-tada" />
               </div>
          </div>

          {/* Status Text */}
          <h2 className="text-2xl font-bold text-center tracking-tight mb-2">
              {statusStep === 0 && "Contacting Caregiver..."}
              {statusStep === 1 && "Sarah Notified"}
              {statusStep === 2 && "Emergency Services"}
          </h2>
          <p className="text-white/60 text-sm font-medium animate-pulse flex items-center gap-2">
              {statusStep < 2 ? <Activity className="w-4 h-4 text-red-400" /> : <Ambulance className="w-4 h-4 text-red-400" />}
              {statusStep < 2 ? "Transmitting vitals..." : "Connecting line..."}
          </p>

          {/* Horizontal Step Tracker */}
          <div className="flex items-center gap-3 mt-8">
              {[0, 1, 2].map((step) => (
                  <div key={step} className={`h-1.5 rounded-full transition-all duration-700 
                      ${statusStep >= step ? 'w-8 bg-white shadow-[0_0_10px_rgba(255,255,255,0.5)]' : 'w-2 bg-white/20'}
                  `} />
              ))}
          </div>
      </div>

      {/* 3. Glass Bento Grids (Data) */}
      <div className="relative z-10 px-6 mb-8">
          <div className="grid grid-cols-2 gap-3">
              
              {/* Heart Rate Glass Card */}
              <div className="bg-white/5 backdrop-blur-xl border border-white/10 rounded-[24px] p-4 h-32 overflow-hidden relative group">
                  <div className="flex items-center gap-2">
                      <Activity className="w-4 h-4 text-red-400" />
                      <span className="text-[11px] font-bold text-gray-400 uppercase">Heart Rate</span>
                  </div>
                  
                  {/* Value moved to left and down */}
                  <div className="absolute top-12 left-4 flex items-end">
                      <span className="text-xl font-bold text-white tracking-tight leading-none">112</span>
                      <span className="text-[10px] text-red-300 ml-1 font-medium mb-0.5">BPM</span>
                  </div>

                  <div className="absolute bottom-0 left-0 right-0 h-16 opacity-40 pointer-events-none">
                      <svg viewBox="0 0 100 40" preserveAspectRatio="none" className="w-full h-full stroke-red-500 fill-none stroke-[2px]">
                          <path d="M0 20 L10 20 L15 10 L20 30 L25 20 L35 20 L40 5 L45 35 L50 20 L60 20 L65 15 L70 25 L75 20 L100 20" vectorEffect="non-scaling-stroke" />
                      </svg>
                  </div>
              </div>

              {/* 4. 3D Perspective Map */}
              <div className="bg-[#2c2c2e] border border-white/10 rounded-[24px] h-32 relative overflow-hidden flex flex-col perspective-container">
                   {/* 3D Tilted Map Layer */}
                   <div className="absolute inset-[-60%] bg-[#1a1a1a] origin-bottom transform-gpu" style={{ transform: 'perspective(500px) rotateX(40deg) scale(1.4)' }}>
                        {/* Grid/Streets */}
                        <div className="absolute top-0 bottom-0 left-1/4 w-4 bg-[#333]" />
                        <div className="absolute top-0 bottom-0 right-1/3 w-6 bg-[#333]" />
                        <div className="absolute top-1/3 left-0 right-0 h-4 bg-[#333]" />
                        <div className="absolute bottom-1/4 left-0 right-0 h-3 bg-[#333]" />
                   </div>
                   
                   {/* 3D Floating Pin */}
                   <div className="absolute top-[45%] left-1/2 -translate-x-1/2 -translate-y-1/2 z-10">
                       <div className="relative">
                           <div className="w-3 h-3 bg-red-500 rounded-full shadow-[0_0_15px_rgba(239,68,68,1)] animate-pulse relative z-20" />
                           <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-8 h-8 bg-red-500/30 rounded-full animate-ping" />
                           {/* Pin Stalk effect */}
                           <div className="absolute top-2 left-1/2 -translate-x-1/2 w-0.5 h-4 bg-red-500/50 blur-[1px]" />
                       </div>
                   </div>

                   {/* Overlay Text */}
                   <div className="mt-auto p-3 relative z-20 bg-gradient-to-t from-black/90 via-black/50 to-transparent pt-6">
                       <div className="flex items-center gap-1 text-[10px] font-bold text-gray-300 uppercase">
                           <MapPin className="w-3 h-3" /> Location
                       </div>
                       <div className="text-xs font-semibold text-white truncate">124 Maple Ave</div>
                   </div>
              </div>

              {/* Waveform Transcript - Always Visible */}
              <div className="col-span-2 bg-white/5 backdrop-blur-xl border border-white/10 rounded-[24px] p-4 flex items-center justify-between gap-4 h-20">
                   <div className="flex items-center gap-4">
                       <div className="w-10 h-10 rounded-full bg-white/10 flex items-center justify-center shrink-0">
                           <Mic className="w-5 h-5 text-white" />
                       </div>
                       <div className="flex items-center gap-0.5 h-6">
                           {[...Array(12)].map((_, i) => (
                               <div 
                                    key={i} 
                                    className="w-1 bg-red-400 rounded-full animate-pulse"
                                    style={{ 
                                        height: `${Math.random() * 100}%`,
                                        animationDelay: `${i * 0.05}s`,
                                        opacity: 0.6 + Math.random() * 0.4
                                    }}
                               />
                           ))}
                       </div>
                   </div>
                   
                   {/* Transcript Text */}
                   <span className="text-sm font-medium text-white/70 italic pr-2 animate-in fade-in">
                        {transcript.length > 0 ? `"${transcript[transcript.length - 1]}"` : "Listening..."}
                   </span>
              </div>

              {/* 3. Medical ID Badge (Appears dynamically below transcript) */}
              {medicalIdSent && (
                  <div className="col-span-2 bg-gradient-to-r from-amber-500/20 to-yellow-600/20 backdrop-blur-xl border border-amber-500/30 rounded-2xl p-3 flex items-center justify-between animate-in slide-in-from-bottom-2 fade-in">
                      <div className="flex items-center gap-3">
                          <div className="w-8 h-8 rounded-full bg-amber-500 flex items-center justify-center shadow-lg shadow-amber-900/50">
                              <CreditCard className="w-4 h-4 text-amber-950" />
                          </div>
                          <div>
                              <p className="text-xs font-bold text-amber-100 uppercase tracking-wide">Medical ID</p>
                              <p className="text-sm font-semibold text-white">Allergies & Blood Type Shared</p>
                          </div>
                      </div>
                      <ShieldCheck className="w-5 h-5 text-amber-400" />
                  </div>
              )}
          </div>
      </div>

      {/* 4. Frosted Track Slider (Footer) */}
      <div className="px-6 pb-10 relative z-20">
           <div 
              ref={sliderRef}
              className="relative w-full h-16 bg-white/15 backdrop-blur-md rounded-full flex items-center overflow-hidden border border-white/10 shadow-[inset_0_2px_10px_rgba(0,0,0,0.2)]"
           >
               {/* Shimmer Text */}
               <div className={`absolute inset-0 flex items-center justify-center pointer-events-none transition-opacity duration-300 ${isDragging ? 'opacity-0' : 'opacity-100'}`}>
                   <span className="text-white/30 font-semibold tracking-widest text-[13px] uppercase ml-10 bg-gradient-to-r from-white/30 via-white to-white/30 bg-clip-text text-transparent bg-[length:200%_100%] animate-shimmer">
                       Slide to Cancel
                   </span>
                   <ChevronRight className="w-4 h-4 text-white/30 ml-1" />
               </div>

               {/* Thumb */}
               <div 
                  className="absolute top-1.5 bottom-1.5 w-[52px] bg-white rounded-full shadow-[0_2px_15px_rgba(255,255,255,0.4)] flex items-center justify-center cursor-grab active:cursor-grabbing z-20 transition-transform duration-75 hover:scale-105"
                  style={{ transform: `translateX(${sliderValue + 6}px)` }}
                  onMouseDown={handleDragStart}
                  onTouchStart={handleDragStart}
               >
                   <X className="w-6 h-6 text-[#1C1C1E]" />
               </div>
           </div>
      </div>

      {/* Global Event Listeners for Drag */}
      {isDragging && (
        <div 
            className="fixed inset-0 z-[100] cursor-grabbing"
            onMouseMove={handleDragMove}
            onMouseUp={handleDragEnd}
            onTouchMove={handleDragMove}
            onTouchEnd={handleDragEnd}
        />
      )}
      
      {/* Confirmation Popup */}
      {showCancelConfirmation && (
        <div className="absolute inset-0 z-[100] bg-black/60 backdrop-blur-md flex items-center justify-center p-8 animate-in fade-in duration-200">
            <div className="bg-[#2C2C2E] w-full max-w-xs rounded-2xl shadow-2xl border border-white/10 overflow-hidden transform scale-100 animate-in zoom-in-95 duration-200">
                <div className="p-6 text-center">
                    <div className="w-12 h-12 bg-red-500/20 rounded-full flex items-center justify-center mx-auto mb-4">
                        <AlertTriangle className="w-6 h-6 text-red-500" />
                    </div>
                    <h3 className="text-xl font-bold text-white mb-2">Cancel Emergency?</h3>
                    <p className="text-white/60 text-sm leading-relaxed">
                        Monitoring will stop and emergency services will not be contacted.
                    </p>
                </div>
                <div className="grid grid-cols-2 border-t border-white/10 divide-x divide-white/10 bg-white/5">
                    <button 
                        onClick={() => {
                            setShowCancelConfirmation(false);
                            setSliderValue(0);
                        }}
                        className="py-4 text-center text-white font-medium active:bg-white/10 transition-colors"
                    >
                        Resume
                    </button>
                    <button 
                        onClick={onClose}
                        className="py-4 text-center text-red-500 font-bold active:bg-white/10 transition-colors"
                    >
                        End SOS
                    </button>
                </div>
            </div>
        </div>
      )}

    </div>
  );
};