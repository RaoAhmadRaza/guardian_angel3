
import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, Phone, Video, ChevronLeft, Paperclip, Check, FileText, HeartPulse } from 'lucide-react';

const DoctorChat: React.FC = () => {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<any[]>([
    { id: '1', sender: 'Doctor', text: "Hello, I've reviewed the latest vitals for Eleanor. The HRV is showing a positive trend.", timestamp: "Yesterday" },
    { id: '2', sender: 'Caregiver', text: "That's great news, Dr. Thorne. Should we adjust her walking schedule?", timestamp: "Yesterday" },
    { id: '3', sender: 'Doctor', text: "Let's keep it as is for another week. I'll send over the formal report shortly.", timestamp: "9:30 AM" }
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
        sender: 'Doctor',
        text: "I've just uploaded the Q3 Cardiac Screening report to the Reports section. Please review when you can.",
        timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
      }]);
    }, 2500);
  };

  return (
    <div className="h-full flex flex-col bg-white overflow-hidden animate-in slide-in-from-right-4 duration-500">
      {/* Header */}
      <header className="px-8 py-6 border-b border-[#F2F2F7] flex items-center justify-between bg-white/95 backdrop-blur-xl sticky top-0 z-20">
        <div className="flex items-center gap-5">
          <button 
            onClick={() => navigate('/chat')}
            className="p-2 -ml-2 text-[#FF2D55] hover:bg-rose-50 rounded-full transition-all active:scale-90"
          >
            <ChevronLeft size={28} strokeWidth={2.5} />
          </button>
          <div className="flex items-center gap-4">
            <div className="p-3 bg-rose-50 text-[#FF2D55] rounded-2xl shadow-sm">
              <HeartPulse size={24} />
            </div>
            <div className="flex flex-col">
              <h3 className="font-bold text-black text-xl leading-tight tracking-tight">Dr. Aris Thorne</h3>
              <span className="text-[11px] font-bold text-[#8E8E93] uppercase tracking-[0.1em] mt-0.5">Cardiologist</span>
            </div>
          </div>
        </div>
        <div className="flex gap-2">
          <button className="w-12 h-12 flex items-center justify-center text-[#FF2D55] hover:bg-rose-50 rounded-full transition-all active:scale-90"><Phone size={24} strokeWidth={2.2} /></button>
          <button className="w-12 h-12 flex items-center justify-center text-[#FF2D55] hover:bg-rose-50 rounded-full transition-all active:scale-90"><Video size={24} strokeWidth={2.2} /></button>
        </div>
      </header>

      {/* Message Stream */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-10 space-y-12 bg-slate-50/30 hide-scrollbar"
      >
        <div className="ios-card bg-rose-50/50 p-6 border border-rose-100 flex items-start gap-4 mb-8">
           <FileText className="text-[#FF2D55] mt-1" size={20} />
           <div>
              <p className="font-bold text-rose-900 text-sm">Professional Consultation</p>
              <p className="text-rose-700/70 text-[13px] font-medium mt-1 leading-relaxed">
                This channel is strictly for medical consultation. For technical support, please contact Guardian AI.
              </p>
           </div>
        </div>

        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.sender === 'Caregiver' ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2 duration-400`}>
            <div className={`max-w-[75%] ${msg.sender === 'Caregiver' ? 'items-end' : 'items-start'} flex flex-col`}>
              <div className={`px-6 py-4 rounded-[28px] text-[16px] font-medium leading-[1.6] shadow-sm tracking-tight ${
                msg.sender === 'Caregiver' 
                  ? 'bg-black text-white rounded-tr-lg' 
                  : 'bg-white text-black border border-black/5 rounded-tl-lg'
              }`}>
                {msg.text}
              </div>
              <div className={`flex items-center gap-2 mt-2 px-2 opacity-50 ${msg.sender === 'Caregiver' ? 'flex-row-reverse' : 'flex-row'}`}>
                <span className="text-[10px] font-bold text-[#8E8E93] uppercase tracking-widest">{msg.timestamp}</span>
                {msg.sender === 'Caregiver' && <Check size={12} strokeWidth={3} className="text-black" />}
              </div>
            </div>
          </div>
        ))}

        {isTyping && (
          <div className="flex justify-start">
            <div className="bg-white px-6 py-4 rounded-[24px] shadow-sm flex items-center gap-1.5 border border-black/5">
              <div className="w-1.5 h-1.5 bg-[#FF2D55] rounded-full animate-bounce"></div>
              <div className="w-1.5 h-1.5 bg-[#FF2D55] rounded-full animate-bounce [animation-delay:0.2s]"></div>
              <div className="w-1.5 h-1.5 bg-[#FF2D55] rounded-full animate-bounce [animation-delay:0.4s]"></div>
            </div>
          </div>
        )}
      </div>

      {/* Input area */}
      <div className="px-8 py-8 bg-white/95 backdrop-blur-xl border-t border-[#F2F2F7] flex items-center gap-5">
        <button className="w-12 h-12 flex items-center justify-center text-[#8E8E93] hover:text-[#FF2D55] hover:bg-rose-50 rounded-full transition-all active:scale-90"><Paperclip size={24} /></button>
        <div className="flex-1 relative">
          <input 
            type="text" 
            value={inputText}
            onChange={(e) => setInputText(e.target.value)}
            onKeyDown={(e) => e.key === 'Enter' && handleSend()}
            placeholder="Type your medical query..."
            className="w-full bg-[#F2F2F7] border border-slate-200/50 px-8 py-4 rounded-full outline-none focus:ring-4 focus:ring-rose-100 transition-all font-medium text-black text-lg placeholder:text-slate-400 shadow-inner"
          />
        </div>
        <button 
          onClick={handleSend}
          disabled={!inputText.trim()}
          className={`w-14 h-14 flex items-center justify-center rounded-full transition-all shadow-xl active:scale-90 ${
            inputText.trim() ? 'bg-black text-white shadow-slate-200' : 'bg-slate-100 text-slate-400 shadow-none'
          }`}
        >
          <Send size={24} strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
};

export default DoctorChat;
