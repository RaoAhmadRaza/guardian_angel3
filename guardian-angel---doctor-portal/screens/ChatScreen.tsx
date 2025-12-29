
import React, { useState, useEffect, useRef } from 'react';
import { initialMessages } from '../mockData';
import { Patient, MessageTag, ChatMessage } from '../types';

export const ChatScreen: React.FC<{ patient: Patient | null, onBack?: () => void }> = ({ patient, onBack }) => {
  const [messages, setMessages] = useState<ChatMessage[]>(initialMessages as any);
  const [inputValue, setInputValue] = useState('');
  const [selectedTag, setSelectedTag] = useState<MessageTag | undefined>(undefined);
  const scrollRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (scrollRef.current) {
      scrollRef.current.scrollTop = scrollRef.current.scrollHeight;
    }
  }, [messages]);

  const sendMessage = () => {
    if (!inputValue.trim()) return;

    const newMessage: ChatMessage = {
      id: Date.now().toString(),
      sender: 'Doctor',
      text: inputValue,
      timestamp: new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' }),
      tag: selectedTag
    };

    setMessages([...messages, newMessage]);
    setInputValue('');
    setSelectedTag(undefined);
  };

  return (
    <div className="flex flex-col h-[calc(100vh-128px)] bg-slate-50 relative overflow-hidden">
      {/* Sub-header for Mobile */}
      <div className="bg-white border-b border-slate-100 py-3 px-4 flex items-center shrink-0">
        <div className="w-8 h-8 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 text-[10px] font-black mr-3">CT</div>
        <div className="flex-1 min-w-0">
          <p className="text-xs font-black uppercase text-slate-400 tracking-wider">Care Team Session</p>
          <p className="text-sm font-bold text-slate-900 truncate">{patient?.name}</p>
        </div>
        <div className="flex space-x-1">
          <button className="p-2 text-slate-400 active:text-blue-600"><svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2" d="M3 5a2 2 0 012-2h3.28a1 1 0 01.948.684l1.498 4.493a1 1 0 01-.502 1.21l-2.257 1.13a11.042 11.042 0 005.516 5.516l1.13-2.257a1 1 0 011.21-.502l4.493 1.498a1 1 0 01.684.949V19a2 2 0 01-2 2h-1C9.716 21 3 14.284 3 6V5z" /></svg></button>
        </div>
      </div>

      {/* Messages */}
      <div ref={scrollRef} className="flex-1 overflow-y-auto p-4 space-y-4 scroll-smooth">
        {messages.map((msg) => (
          <div key={msg.id} className={`flex ${msg.sender === 'Doctor' ? 'justify-end' : 'justify-start'}`}>
            <div className={`max-w-[85%] ${msg.sender === 'AI Guardian' ? 'w-full flex justify-center py-2' : ''}`}>
              {msg.sender === 'AI Guardian' ? (
                <div className="bg-slate-200/50 backdrop-blur-sm rounded-full px-4 py-1 text-[9px] font-black text-slate-500 uppercase tracking-widest border border-white/50">
                  {msg.text}
                </div>
              ) : (
                <div className={`flex flex-col ${msg.sender === 'Doctor' ? 'items-end' : 'items-start'}`}>
                  <div className={`p-4 rounded-[22px] shadow-sm ${
                    msg.sender === 'Doctor' 
                    ? 'bg-blue-600 text-white rounded-tr-[4px]' 
                    : 'bg-white border border-slate-100 text-slate-800 rounded-tl-[4px]'
                  }`}>
                    {msg.tag && (
                      <span className={`inline-block px-1.5 py-0.5 rounded-full text-[9px] font-black uppercase mb-1.5 ${
                        msg.sender === 'Doctor' ? 'bg-blue-500 text-white' : 'bg-slate-100 text-slate-500'
                      }`}>
                        {msg.tag}
                      </span>
                    )}
                    <p className="text-sm font-medium leading-relaxed">{msg.text}</p>
                    <p className={`text-[9px] mt-1 opacity-60 font-bold ${msg.sender === 'Doctor' ? 'text-right' : 'text-left'}`}>
                      {msg.timestamp}
                    </p>
                  </div>
                </div>
              )}
            </div>
          </div>
        ))}
      </div>

      {/* Input Field (Mobile Anchored) */}
      <div className="p-4 bg-white border-t border-slate-100 safe-bottom">
        <div className="flex space-x-2 mb-3 overflow-x-auto pb-1 scrollbar-hide">
          {Object.values(MessageTag).map(tag => (
            <button 
              key={tag}
              onClick={() => setSelectedTag(tag === selectedTag ? undefined : tag)}
              className={`whitespace-nowrap px-3 py-1.5 rounded-full text-[10px] font-black uppercase tracking-tighter transition-all ${
                selectedTag === tag ? 'bg-blue-600 text-white' : 'bg-slate-100 text-slate-400'
              }`}
            >
              {tag}
            </button>
          ))}
        </div>
        <div className="flex items-center bg-slate-50 rounded-[28px] p-1 border border-slate-100">
          <button className="p-3 text-slate-400 active:text-blue-600"><svg className="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24"><path strokeLinecap="round" strokeLinejoin="round" strokeWidth="2.5" d="M12 4v16m8-8H4" /></svg></button>
          <input 
            type="text" 
            value={inputValue}
            onChange={(e) => setInputValue(e.target.value)}
            onKeyPress={(e) => e.key === 'Enter' && sendMessage()}
            placeholder="Clinical message..." 
            className="flex-1 bg-transparent border-none focus:ring-0 text-[15px] font-medium py-2 px-1"
          />
          <button 
            onClick={sendMessage}
            className="bg-blue-600 text-white w-10 h-10 rounded-full flex items-center justify-center shadow-lg shadow-blue-200 active:scale-90 transition-transform"
          >
            <svg className="w-5 h-5 transform rotate-90" fill="currentColor" viewBox="0 0 20 20"><path d="M10.894 2.553a1 1 0 00-1.788 0l-7 14a1 1 0 001.169 1.409l5-1.429A1 1 0 009 15.571V11a1 1 0 112 0v4.571a1 1 0 00.725.962l5 1.428a1 1 0 001.17-1.408l-7-14z" /></svg>
          </button>
        </div>
      </div>
    </div>
  );
};
