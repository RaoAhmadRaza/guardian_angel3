
import React, { useState, useRef, useEffect } from 'react';
import { useNavigate } from 'react-router-dom';
import { Send, ChevronLeft, Paperclip, Sparkles, ShieldCheck, Check } from 'lucide-react';
import { getAIResponse } from '../services/geminiService';

const AIChat: React.FC = () => {
  const navigate = useNavigate();
  const [messages, setMessages] = useState<any[]>([
    { id: '1', sender: 'AI Guardian', text: "Welcome to your AI Guardian interface. I am monitoring Eleanor's vitals in real-time. How can I assist you today?", timestamp: "Now" }
  ]);
  const [inputText, setInputText] = useState('');
  const [isTyping, setIsTyping] = useState(false);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages, isTyping]);

  const handleSend = async () => {
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

    const history = messages.map(m => ({ 
      role: m.sender === 'Caregiver' ? 'user' : 'model', 
      text: m.text 
    }));
    
    const aiResponse = await getAIResponse(inputText, history);
    
    setIsTyping(false);
    setMessages(prev => [...prev, {
      id: (Date.now() + 1).toString(),
      sender: 'AI Guardian',
      text: aiResponse,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
    }]);
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
            <div className="p-3 bg-blue-50 text-[#007AFF] rounded-2xl shadow-inner">
              <ShieldCheck size={24} />
            </div>
            <div className="flex flex-col">
              <h3 className="font-bold text-black text-xl leading-tight tracking-tight">AI Guardian</h3>
              <div className="flex items-center gap-1.5 mt-0.5">
                <div className="w-2 h-2 rounded-full bg-[#34C759] animate-pulse"></div>
                <span className="text-[11px] font-bold text-[#8E8E93] uppercase tracking-[0.1em]">Ready</span>
              </div>
            </div>
          </div>
        </div>
        <div className="flex items-center gap-2 px-4 py-2 bg-blue-50 text-[#007AFF] rounded-full">
          <Sparkles size={16} />
          <span className="text-[10px] font-black uppercase tracking-widest">Enhanced Mode</span>
        </div>
      </header>

      {/* Message Stream */}
      <div 
        ref={scrollRef}
        className="flex-1 overflow-y-auto p-10 space-y-12 bg-blue-50/10 hide-scrollbar"
      >
        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.sender === 'Caregiver' ? 'justify-end' : 'justify-start'} animate-in slide-in-from-bottom-2 duration-400`}>
            <div className={`max-w-[80%] ${msg.sender === 'Caregiver' ? 'items-end' : 'items-start'} flex flex-col`}>
              <div className={`px-6 py-4 rounded-[28px] text-[16px] font-medium leading-[1.6] shadow-sm tracking-tight ${
                msg.sender === 'Caregiver' 
                  ? 'bg-blue-600 text-white rounded-tr-lg' 
                  : 'bg-white text-black border border-black/5 rounded-tl-lg'
              }`}>
                {msg.text}
              </div>
              <div className={`flex items-center gap-2 mt-2 px-2 opacity-50 ${msg.sender === 'Caregiver' ? 'flex-row-reverse' : 'flex-row'}`}>
                <span className="text-[10px] font-bold text-[#8E8E93] uppercase tracking-widest">{msg.timestamp}</span>
                {msg.sender === 'Caregiver' && <Check size={12} strokeWidth={3} className="text-blue-600" />}
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
            placeholder="Ask AI Guardian..."
            className="w-full bg-[#F2F2F7] border border-slate-200/50 px-8 py-4 rounded-full outline-none focus:ring-4 focus:ring-blue-100 transition-all font-medium text-black text-lg placeholder:text-slate-400 shadow-inner"
          />
        </div>
        <button 
          onClick={handleSend}
          disabled={!inputText.trim() || isTyping}
          className={`w-14 h-14 flex items-center justify-center rounded-full transition-all shadow-xl active:scale-90 ${
            inputText.trim() ? 'bg-blue-600 text-white shadow-blue-200' : 'bg-slate-100 text-slate-400 shadow-none'
          }`}
        >
          <Send size={24} strokeWidth={2.5} />
        </button>
      </div>
    </div>
  );
};

export default AIChat;
