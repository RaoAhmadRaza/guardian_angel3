import React, { useState, useEffect } from 'react';
import { Mic, Send, Heart, Paperclip, Image as ImageIcon, FileText, X, Keyboard, Plus, Camera, Activity, MapPin, ArrowUp, Moon, Video, Clock, Frown, Phone } from 'lucide-react';

interface InputBarProps {
  onSend: (text: string) => void;
  type: 'caregiver' | 'ai' | 'doctor' | 'system' | 'sos' | 'peace';
  placeholder?: string;
  isThinking?: boolean;
  isOnline?: boolean;
  onHeartTrigger?: () => void;
}

export const InputBar: React.FC<InputBarProps> = ({ onSend, type, placeholder = "Type a message...", isThinking, isOnline = true, onHeartTrigger }) => {
  const [text, setText] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [showHeartAnimation, setShowHeartAnimation] = useState(false);
  const [isMenuOpen, setIsMenuOpen] = useState(false);
  
  // New State for AI Modes: 'voice' (waveform) or 'text' (input field)
  const [inputMode, setInputMode] = useState<'voice' | 'text'>('voice');

  const handleSend = () => {
    if (text.trim()) {
      onSend(text);
      setText('');
      // Optionally switch back to voice mode after sending, or stay in text.
      // Staying in text mode might be better flow if they are typing.
    }
  };

  const handleKeyPress = (e: React.KeyboardEvent) => {
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      handleSend();
    }
  };

  const toggleListening = () => {
    setIsListening(!isListening);
    // Simulation of voice input
    if (!isListening) {
      setTimeout(() => {
        setText((prev) => prev + "I'm feeling a bit tired today. ");
        setIsListening(false);
        setInputMode('text'); // Switch to text to show the result
      }, 2000);
    }
  };

  const handleHeartClick = () => {
      // If parent provided a trigger for screen effect, use it
      if (onHeartTrigger) {
          onHeartTrigger();
      } else {
        setShowHeartAnimation(true);
        setTimeout(() => setShowHeartAnimation(false), 2000);
      }
  };

  const isSOS = type === 'sos';
  const isAI = type === 'ai';
  const isDoctor = type === 'doctor';
  const isSystem = type === 'system';
  const isPeace = type === 'peace';
  const isCaregiver = type === 'caregiver';

  // Clinic Mode Logic
  const isClinicOffline = isDoctor && !isOnline;

  // Customized Placeholder logic
  let inputPlaceholder = placeholder;
  if (isSystem) inputPlaceholder = "You don't need to reply here";
  if (isPeace) inputPlaceholder = "You don't need to reply";
  if (isListening) {
      inputPlaceholder = isDoctor ? "Recording for Dr. Chen..." : "Listening...";
  }

  // --- ACCESSORY MENU OVERLAY (Blur) ---
  const renderAccessoryMenu = () => (
      <div 
        className="fixed inset-0 z-50 bg-white/80 backdrop-blur-2xl flex flex-col justify-end pb-32 px-6 animate-in fade-in duration-300"
        onClick={() => setIsMenuOpen(false)}
      >
         <div className="grid grid-cols-3 gap-y-8 gap-x-4 mb-8" onClick={e => e.stopPropagation()}>
            {/* Menu Items with spring animation */}
            {[
                { icon: Camera, label: 'Camera', color: 'bg-gray-100 text-gray-900', delay: '0ms' },
                { icon: ImageIcon, label: 'Photos', color: 'bg-gray-100 text-gray-900', delay: '50ms' },
                { icon: Activity, label: 'Vitals', color: 'bg-red-50 text-red-600', delay: '100ms' },
                { icon: MapPin, label: 'Location', color: 'bg-green-50 text-green-600', delay: '150ms' },
                { icon: FileText, label: 'Report', color: 'bg-blue-50 text-blue-600', delay: '200ms' },
            ].map((item, i) => (
                <button 
                    key={i} 
                    className="flex flex-col items-center gap-3 group animate-in slide-in-from-bottom-8 fill-mode-backwards"
                    style={{ animationDelay: item.delay }}
                    onClick={() => setIsMenuOpen(false)}
                >
                    <div className={`w-16 h-16 rounded-full ${item.color} shadow-sm group-active:scale-90 transition-transform flex items-center justify-center`}>
                        <item.icon className="w-8 h-8" />
                    </div>
                    <span className="text-xs font-semibold text-gray-600 tracking-wide">{item.label}</span>
                </button>
            ))}
         </div>
         
         <button 
            className="w-12 h-12 rounded-full bg-gray-200/50 self-center flex items-center justify-center hover:bg-gray-300 transition-colors"
            onClick={() => setIsMenuOpen(false)}
         >
            <X className="w-6 h-6 text-gray-500" />
         </button>
      </div>
  );

  // --- SYSTEM / MEDICATION TRACKER STYLE ---
  if (isSystem) {
      return (
          <div className="p-4 bg-gray-50 safe-area-bottom relative z-20 border-t border-gray-200/50">
              <div className="flex gap-4">
                  <button className="flex-1 bg-white border border-gray-200 shadow-sm rounded-2xl py-3 px-4 flex items-center justify-center gap-2 active:scale-95 transition-transform">
                      <Frown className="w-5 h-5 text-amber-500" />
                      <span className="text-[15px] font-semibold text-gray-700">Log Side Effect</span>
                  </button>
                  <button className="flex-1 bg-white border border-gray-200 shadow-sm rounded-2xl py-3 px-4 flex items-center justify-center gap-2 active:scale-95 transition-transform">
                      <Phone className="w-5 h-5 text-blue-500" />
                      <span className="text-[15px] font-semibold text-gray-700">Contact Dr. Emily</span>
                  </button>
              </div>
          </div>
      );
  }

  // --- DOCTOR / TELEHEALTH STYLE ---
  if (isDoctor) {
      return (
        <>
        {isMenuOpen && renderAccessoryMenu()}
        <div className="p-3 bg-gray-50 safe-area-bottom relative z-20 border-t border-gray-200/50">
             <div className="flex items-center gap-3">
                 {/* 1. Accessory Button */}
                 <button 
                    onClick={() => setIsMenuOpen(true)}
                    className="w-10 h-10 rounded-full bg-white border border-gray-200 text-gray-500 flex items-center justify-center active:scale-90 transition-transform flex-shrink-0 shadow-sm"
                 >
                     <Plus className="w-6 h-6" />
                 </button>

                 {/* 2. Unified Composer Pill */}
                 <div className="flex-1 min-h-[44px] bg-white border border-gray-200 rounded-full px-4 py-2 flex items-center shadow-sm focus-within:ring-2 focus-within:ring-blue-100 transition-shadow">
                     <input
                        type="text"
                        className="flex-1 bg-transparent border-none outline-none text-[16px] text-gray-900 placeholder-gray-400"
                        placeholder={inputPlaceholder}
                        value={text}
                        onChange={(e) => setText(e.target.value)}
                        onKeyDown={handleKeyPress}
                     />
                 </div>

                 {/* 3. Action Button (Send or Video/Clock) */}
                 {text ? (
                    <button 
                        onClick={handleSend}
                        className="w-10 h-10 rounded-full bg-blue-600 text-white flex items-center justify-center active:scale-90 transition-transform shadow-md flex-shrink-0"
                    >
                        <ArrowUp className="w-5 h-5 stroke-[3px]" />
                    </button>
                 ) : (
                    <div className="relative">
                         <button 
                            disabled={isClinicOffline}
                            className={`w-10 h-10 rounded-full flex items-center justify-center transition-all flex-shrink-0
                                ${isClinicOffline 
                                    ? 'bg-gray-200 text-gray-400 cursor-not-allowed' 
                                    : 'bg-green-500 text-white shadow-md active:scale-90'
                                }
                            `}
                        >
                            <Video className="w-5 h-5 fill-current" />
                        </button>
                        {isClinicOffline && (
                            <div className="absolute -top-1 -right-1 bg-white rounded-full p-0.5 border border-gray-200">
                                <Clock className="w-3 h-3 text-orange-500" />
                            </div>
                        )}
                    </div>
                 )}
             </div>
        </div>
        </>
      )
  }

  // --- CAREGIVER / PREMIUM IOS STYLE ---
  if (isCaregiver) {
      return (
        <>
        {isMenuOpen && renderAccessoryMenu()}
        <div className="p-3 bg-[#F2F1ED] safe-area-bottom relative z-20">
             <div className="flex items-end gap-3">
                 {/* 1. Accessory Button */}
                 <button 
                    onClick={() => setIsMenuOpen(true)}
                    className="w-9 h-9 rounded-full bg-gray-300 text-white flex items-center justify-center mb-1 active:scale-90 transition-transform flex-shrink-0"
                 >
                     <Plus className="w-5 h-5" />
                 </button>

                 {/* 2. Unified Composer Pill */}
                 <div className="flex-1 min-h-[40px] bg-white border border-gray-200/50 rounded-[20px] px-3 py-1 flex items-center shadow-sm">
                     <input
                        type="text"
                        className="flex-1 bg-transparent border-none outline-none text-[16px] text-gray-900 placeholder-gray-400 py-1"
                        placeholder={inputPlaceholder}
                        value={text}
                        onChange={(e) => setText(e.target.value)}
                        onKeyDown={handleKeyPress}
                     />
                     {/* Mic Inside Input */}
                     {!text && (
                         <button onClick={toggleListening} className="ml-2 text-gray-400 active:text-gray-600">
                             <Mic className="w-5 h-5" />
                         </button>
                     )}
                 </div>

                 {/* 3. Action Button (Heart or Send) */}
                 {text ? (
                    <button 
                        onClick={handleSend}
                        className="w-9 h-9 rounded-full bg-blue-500 text-white flex items-center justify-center mb-1 active:scale-90 transition-transform shadow-sm flex-shrink-0"
                    >
                        <ArrowUp className="w-5 h-5 stroke-[3px]" />
                    </button>
                 ) : (
                    <button 
                        onClick={handleHeartClick}
                        className="w-9 h-9 rounded-full bg-pink-50 text-pink-500 flex items-center justify-center mb-1 active:scale-75 transition-transform flex-shrink-0"
                    >
                        <Heart className="w-6 h-6 fill-current" />
                    </button>
                 )}
             </div>
        </div>
        </>
      )
  }

  // --- AI PREMIUM FLOATING CAPSULE STYLE ---
  if (isAI) {
      return (
        <>
        {isMenuOpen && renderAccessoryMenu()}
        
        <div className="fixed bottom-0 left-0 right-0 p-5 z-40 safe-area-bottom pointer-events-none">
            <div className="max-w-3xl mx-auto pointer-events-auto flex items-end gap-3">
                
                {/* 3. ACCESSORY (+) BUTTON */}
                <button 
                    onClick={() => setIsMenuOpen(true)}
                    className="w-12 h-12 rounded-full bg-gray-200/50 backdrop-blur-md flex items-center justify-center text-gray-600 shadow-sm active:scale-90 transition-transform hover:bg-gray-300/50"
                >
                    <Plus className="w-6 h-6" />
                </button>

                {/* Unified Input Capsule */}
                <div className={`flex-1 relative flex items-center bg-white/80 backdrop-blur-xl shadow-[0_8px_40px_rgba(0,0,0,0.12)] border border-white/60 rounded-[32px] p-2 transition-all duration-500
                    ${isListening ? 'ring-2 ring-purple-200 shadow-[0_12px_50px_rgba(168,85,247,0.25)]' : ''}
                    ${isThinking ? 'ring-2 ring-indigo-300 shadow-[0_0_30px_rgba(99,102,241,0.4)] animate-pulse' : ''}
                `}>
                    
                    {/* Left Action: Toggle Mode */}
                    <button
                        onClick={() => setInputMode(prev => prev === 'voice' ? 'text' : 'voice')}
                        className="w-10 h-10 rounded-full flex items-center justify-center text-gray-500 hover:bg-black/5 transition-colors shrink-0"
                    >
                        {inputMode === 'voice' ? <Keyboard className="w-6 h-6" /> : <Mic className="w-6 h-6" />}
                    </button>

                    {/* Center Area: Dynamic Waveform OR Text Input */}
                    <div className="flex-1 mx-2 h-12 flex items-center justify-center relative">
                        
                        {/* 3. DYNAMIC WAVEFORM VISUALIZATION */}
                        {inputMode === 'voice' && (
                            <button 
                                onClick={toggleListening}
                                className="w-full h-full flex items-center justify-center gap-1 cursor-pointer group"
                            >
                                {isListening ? (
                                    // Active Listening Animation
                                    <>
                                        {[...Array(5)].map((_, i) => (
                                            <div 
                                                key={i} 
                                                className="w-1.5 bg-gradient-to-t from-indigo-500 via-purple-500 to-pink-500 rounded-full animate-bounce"
                                                style={{ 
                                                    height: `${Math.random() * 20 + 15}px`,
                                                    animationDuration: `${0.5 + Math.random() * 0.5}s`,
                                                    animationDelay: `${i * 0.1}s`
                                                }}
                                            />
                                        ))}
                                    </>
                                ) : (
                                    // Idle Waveform (Flowing Line)
                                    <>
                                       {!isThinking && <div className="text-gray-400 font-medium mr-2 text-[15px] animate-pulse">Tap to speak</div>}
                                       {isThinking && <div className="text-indigo-500 font-medium mr-2 text-[15px] animate-pulse">Thinking...</div>}
                                       
                                       {/* Simulated static waveform */}
                                       <div className="flex items-center gap-0.5 opacity-40">
                                            {[3, 6, 4, 8, 5, 10, 4, 7, 3, 5, 8, 4, 6, 3, 7, 4, 8, 5, 3].map((h, i) => (
                                                <div 
                                                    key={i} 
                                                    className={`w-0.5 rounded-full transition-all group-hover:bg-purple-600 group-hover:h-3 ${isThinking ? 'bg-indigo-400 h-4 animate-bounce' : 'bg-gray-800'}`}
                                                    style={{ height: isThinking ? undefined : `${h}px`, animationDelay: `${i * 0.05}s` }} 
                                                />
                                            ))}
                                       </div>
                                    </>
                                )}
                            </button>
                        )}

                        {/* Text Input Mode */}
                        {inputMode === 'text' && (
                            <input
                                type="text"
                                className="w-full h-full bg-transparent border-none outline-none text-[17px] text-gray-800 placeholder-gray-400 font-medium"
                                placeholder="Type a message..."
                                value={text}
                                onChange={(e) => setText(e.target.value)}
                                onKeyDown={handleKeyPress}
                                autoFocus
                            />
                        )}
                    </div>

                    {/* Right Action: Send or Mic Status */}
                    <button
                        onClick={inputMode === 'text' && text ? handleSend : toggleListening}
                        className={`w-12 h-12 rounded-full flex items-center justify-center transition-all duration-300 shrink-0
                            ${(text && inputMode === 'text')
                                ? 'bg-indigo-600 text-white shadow-md scale-100' 
                                : isListening 
                                    ? 'bg-red-500 text-white animate-pulse scale-110' 
                                    : 'bg-black/5 hover:bg-black/10 text-gray-400'}
                        `}
                    >
                        {(text && inputMode === 'text') ? <Send className="w-5 h-5 ml-0.5 fill-current" /> : (isListening ? <div className="w-4 h-4 bg-white rounded-sm" /> : <div className="w-3 h-3 bg-red-500 rounded-full" />)}
                    </button>
                </div>
            </div>
        </div>
        </>
      );
  }

  // --- STANDARD STYLE FOR OTHER VIEWS ---
  
  return (
    <div className={`p-4 relative ${isSOS ? 'bg-red-50 border-t border-red-100' : 'bg-white border-t border-gray-200'} safe-area-bottom`}>
      
      {/* Heart Sent Feedback Overlay */}
      {showHeartAnimation && (
          <div className="absolute bottom-20 left-1/2 -translate-x-1/2 bg-black/70 backdrop-blur-md text-white px-4 py-2 rounded-full flex items-center gap-2 animate-in zoom-in slide-in-from-bottom-4 duration-300 pointer-events-none whitespace-nowrap z-50">
              <Heart className="w-5 h-5 fill-pink-500 text-pink-500" />
              <span className="font-bold text-sm">
                  {isPeace ? "Logged peaceful moment" : "Sends reassurance"}
              </span>
          </div>
      )}

      <div className="flex items-end gap-3 max-w-2xl mx-auto relative z-20">
        {/* Voice Button */}
        <button
          onClick={toggleListening}
          className={`flex-shrink-0 flex items-center justify-center rounded-full transition-all duration-300 relative
            ${isListening 
                ? 'scale-110 ring-4 ring-blue-100 bg-gradient-to-tr from-blue-500 via-indigo-500 to-purple-500 text-white' 
                : 'hover:bg-opacity-90 active:scale-95 bg-blue-500 text-white'}
            ${!isListening && isAI ? 'animate-pulse-slow' : ''} 
            ${isSOS ? 'w-16 h-16 bg-red-600 text-white shadow-lg' : 'w-12 h-12 shadow-sm'}
            ${isPeace && !isListening ? 'bg-teal-500/80' : ''}
            `}
        >
          {isListening && <span className="absolute inset-0 rounded-full border-2 border-white opacity-40 animate-ping" />}
          <Mic className={isSOS ? "w-8 h-8" : "w-6 h-6 relative z-10"} />
        </button>

        {/* Text Field */}
        <div 
            className={`flex-1 rounded-2xl px-4 py-2 min-h-[48px] flex items-center focus-within:ring-2 focus-within:ring-blue-200 transition-all 
                bg-gray-100 
                ${isPeace ? 'bg-transparent border-none' : ''}
            `}
        >
          <input
            type="text"
            className={`w-full bg-transparent outline-none text-lg placeholder-gray-400 text-gray-900
                ${isPeace ? 'text-gray-500 placeholder-gray-300' : ''}
                `}
            placeholder={inputPlaceholder}
            value={text}
            onChange={(e) => setText(e.target.value)}
            onKeyDown={handleKeyPress}
            disabled={isListening}
          />
        </div>

        {/* Secondary Actions */}
        {!text && !isSOS && (
            <>
                 {(type === 'peace') && (
                    <button 
                        onClick={handleHeartClick}
                        className={`p-3 text-pink-500 bg-pink-50 rounded-full hover:bg-pink-100 active:scale-90 transition-all ${showHeartAnimation ? 'scale-125' : ''}`}
                    >
                        <Heart className={`w-6 h-6 fill-current ${showHeartAnimation ? 'animate-ping' : ''}`} />
                    </button>
                 )}
            </>
        )}

        {/* Send Button */}
        {text && (
            <button
            onClick={handleSend}
            className="p-3 text-blue-600 bg-blue-50 rounded-full hover:bg-blue-100 active:scale-95 transition-all"
            >
            <Send className="w-6 h-6 fill-current" />
            </button>
        )}
      </div>
    </div>
  );
};