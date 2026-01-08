
import React, { useState, useRef, useEffect, useContext } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, Phone, Video, ChevronLeft, Paperclip, Check, Mic } from 'lucide-react';
import { MOCK_PATIENT } from '../constants';
import { CallContext } from '../App';

const PatientChat: React.FC = () => {
  const navigate = useNavigate();
  const { startCall } = useContext(CallContext);
  const [messages, setMessages] = useState<any[]>([
    { id: '1', sender: 'Patient', text: "Good morning! I just finished my breakfast.", timestamp: "8:45 AM" },
    { id: '2', sender: 'Caregiver', text: "Morning Eleanor! Glad to hear. Did you remember to take the red vitamin?", timestamp: "8:47 AM" },
    { id: '3', sender: 'Patient', text: "Yes, I just took it with my tea.", timestamp: "8:50 AM" }
  ]);
  const [inputText, setInputText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isTyping]);

  const handleSend = () => {
    if (!inputText.trim()) return;

    const userMsg = {
      id: Date.now().toString(),
      sender: 'Caregiver',
      text: inputText,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    };

    setMessages(prev => [...prev, userMsg]);
    setInputText('');

    setIsTyping(true);
    setTimeout(() => {
      setIsTyping(false);
      setMessages(prev => [...prev, {
        id: (Date.now() + 1).toString(),
        sender: 'Patient',
        text: "I think I'll go for a small walk in the garden now. The weather looks lovely.",
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }]);
    }, 2000);
  };

  return (
    <div className="h-full flex flex-col bg-white overflow-hidden animate-in slide-in-from-right-4 duration-500">
      {/* Header */}
      <header className="px-8 py-6 border-b border-[#F2F2F7] flex items-center justify-between bg-white/95 backdrop-blur-xl sticky top-0 z-20">
        <div className="flex items-center gap-5">
          <button 
            onClick={() => navigate('/chat')}
            className="p-2 -ml-2 text-[#007AFF] hover:bg-blue-50 rounded-full transition-all active:scale-90"
          >
            <ChevronLeft size={28} strokeWidth={2.5} />
          </button>
          <div className="flex items-center gap-4">
            <div className="relative">
              <img src={MOCK_PATIENT.photoUrl} className="w-12 h-12 rounded-full object-cover shadow-sm" alt="" />
              <div className="absolute -bottom-0.5 -right-0.5 w-3.5 h-3.5 bg-[#34C759] border-2 border-white rounded-full"></div>
            </div>
            <div className="flex flex-col">
              <h3 className="font-bold text-black text-xl leading-tight tracking-tight">{MOCK_PATIENT.name}</h3>
              <span className="text-[11px] font-bold text-[#34C759] uppercase tracking-[0.1em] mt-0.5">Online</span>
            </div>
          </div>
        </div>
        <div className="flex gap-2">
          <button onClick={startCall} className="w-12 h-12 flex items-center justify-center text-[#007AFF] hover:bg-blue-50 rounded-full transition-all active:scale-90"><Phone size={24} strokeWidth={2.2} /></button>
          <button className="w-12 h-12 flex items-center justify-center text-[#007AFF] hover:bg-blue-50 rounded-full transition-all active:scale-90"><Video size={24} strokeWidth={2.2} /></button>
        </div>
      </header>

      {/* Message Stream */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-10 space-y-12 bg-[#F2F2F7]/30 hide-scrollbar"
      >
        <div className="text-center py-6">
          <p className="text-[11px] font-black uppercase tracking-[0.2em] text-[#8E8E93]">Today</p>
        </div>

        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.sender === 'Caregiver' ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2 duration-400`}>
            <div className={`max-w-[75%] ${msg.sender === 'Caregiver' ? 'items-end' : 'items-start'} flex flex-col`}>
              <div className={`px-6 py-4 rounded-[28px] text-[16px] font-medium leading-[1.6] shadow-sm tracking-tight ${
                msg.sender === 'Caregiver' 
                  ? 'bg-[#007AFF] text-white rounded-tr-lg' 
                  : 'bg-white text-black border border-black/5 rounded-tl-lg'
              }`}>
                {msg.text}
              </div>
              <div className={`flex items-center gap-2 mt-2 px-2 opacity-50 ${msg.sender === 'Caregiver' ? 'flex-row-reverse' : 'flex-row'}`}>
                <span className="text-[10px] font-bold text-[#8E8E93] uppercase tracking-widest">{msg.timestamp}</span>
                {msg.sender === 'Caregiver' && <Check size={12} strokeWidth={3} className="text-[#007AFF]" />}
              </div>
            </div>
          </div>
        ))}

        {isTyping && (
          <div className="flex justify-start">
            <div className="bg-white px-6 py-4 rounded-[24px] shadow-sm flex items-center gap-1.5 border border-black/5">
              <div className="w-1.5 h-1.5 bg-[#007AFF] rounded-full animate-bounce"></div>
              <div className="w-1.5 h-1.5 bg-[#007AFF] rounded-full animate-bounce [animation-delay:0.2s]"></div>
              <div className="w-1.5 h-1.5 bg-[#007AFF] rounded-full animate-bounce [animation-delay:0.4s]"></div>
            </div>
          </div>
        )}
      </div>

      {/* Input area */}
      <div className="px-8 py-8 bg-white/95 backdrop-blur-xl border-t border-[#F2F2F7] flex items-center gap-5">
        <button className="w-12 h-12 flex items-center justify-center text-[#8E8E93] hover:text-[#007AFF] hover:bg-blue-50 rounded-full transition-all active:scale-90"><Paperclip size={24} /></button>
        <div className="flex-1 relative">
          <input 
            type="text" 
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="iMessage"
            className="w-full bg-[#F2F2F7] border border-slate-200/50 px-8 py-4 rounded-full outline-none focus:ring-4 focus:ring-blue-100 transition-all font-medium text-black text-lg placeholder:text-slate-400 shadow-inner"
          />
          <button className="absolute right-4 top-1/2 -translate-y-1/2 p-2 text-[#007AFF]"><Mic size={20} /></button>
        </div>
        <button 
          onClick={handleSend}
          disabled={!inputText.trim()}
          className={`w-14 h-14 flex items-center justify-center rounded-full transition-all shadow-xl active:scale-90 ${
            inputText.trim() ? 'bg-[#007AFF] text-white shadow-blue-200' : 'bg-slate-100 text-slate-400 shadow-none'
          }`}
        >
          <Send size={24} strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
};

export default PatientChat;
