import React, { useState, useEffect, useRef } from 'react';
import { ChevronLeft, Phone, Video, Stethoscope, CloudSun, User, ShieldAlert, Heart, Info, Clock, Check, CheckCheck, Activity, Users, Shield, Moon, ThumbsUp, X, ChevronDown, CheckCircle2, Eye, EyeOff, AlertTriangle, MapPin, ShieldCheck, Share, Pill, ChevronUp, History, Volume2, VolumeX, Wind, Smile, CloudRain, Sun, Zap, HeartPulse, MoreHorizontal, Calendar, Lock, BadgeCheck, ChevronRight, Frown, Flame, RotateCcw, Mic, Play, Pause, CloudDrizzle } from 'lucide-react';
import { ViewType, ChatSession, Message } from '../types';
import { InputBar } from './InputBar';
import { geminiService } from '../services/geminiService';
import { GenerateContentResponse } from '@google/genai';
import { CommunityFeed } from './CommunityFeed';

interface ChatScreenProps {
  session: ChatSession;
  onBack: () => void;
  onSendMessage: (sessionId: string, text: string) => void;
  onSOS: () => void;
}

export const ChatScreen: React.FC<ChatScreenProps> = ({ session, onBack, onSendMessage, onSOS }) => {
  // --- INTEGRATION: Redirect to Community Feed if type is COMMUNITY ---
  if (session.type === ViewType.COMMUNITY) {
      return (
          <CommunityFeed 
              session={session} 
              onBack={onBack} 
              onSendMessage={onSendMessage} 
          />
      );
  }

  const [localMessages, setLocalMessages] = useState<Message[]>(session.messages);
  const scrollRef = useRef<HTMLDivElement>(null);
  const [isTyping, setIsTyping] = useState(false);
  
  // Premium UI States
  const [dynamicSubtitle, setDynamicSubtitle] = useState(session.subtitle);
  const [showContextBanner, setShowContextBanner] = useState(session.type === ViewType.AI_COMPANION);
  const [showEscalation, setShowEscalation] = useState(false);
  const [simpleMode, setSimpleMode] = useState(false);
  const [showVerifiedToast, setShowVerifiedToast] = useState(false);
  const [floatingHearts, setFloatingHearts] = useState<{id: number, left: number, delay: number}[]>([]);
  const [showSmartReplies, setShowSmartReplies] = useState(session.type === ViewType.CAREGIVER);

  // Medication/System Specific States
  const [confirmationSheetOpen, setConfirmationSheetOpen] = useState(false);
  const [doseTaken, setDoseTaken] = useState(false);
  const [flippedCards, setFlippedCards] = useState<Record<string, boolean>>({});
  
  // Swipe Slider State
  const sliderRef = useRef<HTMLDivElement>(null);
  const [sliderValue, setSliderValue] = useState(0);
  const [isDragging, setIsDragging] = useState(false);
  const startXRef = useRef(0);

  // Peace of Mind Specific States
  const [isBreathing, setIsBreathing] = useState(false);
  const [breathingPhase, setBreathingPhase] = useState<'in' | 'hold' | 'out'>('in');
  const [isReflecting, setIsReflecting] = useState(false);
  const [isPlayingAudio, setIsPlayingAudio] = useState(true);
  const [moodValue, setMoodValue] = useState(50);
  const [cardDrag, setCardDrag] = useState({ y: 0, active: false });
  const cardStartRef = useRef(0);

  useEffect(() => {
    setLocalMessages(session.messages);
    scrollToBottom();
    setShowSmartReplies(session.type === ViewType.CAREGIVER);
    setDoseTaken(false); // Reset on new session load potentially
  }, [session.messages, session.type]);

  // Rotate Subtitle Effect
  useEffect(() => {
    if (session.type === ViewType.AI_COMPANION) {
        const subtitles = [
            "Monitoring quietly",
            "Here if you need me",
            "All looks normal"
        ];
        const randomSubtitle = subtitles[Math.floor(Math.random() * subtitles.length)];
        setDynamicSubtitle(randomSubtitle);
    } else if (session.type === ViewType.DOCTOR && !session.isOnline) {
        setDynamicSubtitle(session.statusText || "Replies during clinic hours");
    } else if (session.type === ViewType.PEACE_OF_MIND) {
        setDynamicSubtitle("Just for you");
    } else if (session.type === ViewType.SYSTEM) {
        setDynamicSubtitle(null as any); // Hide default subtitle to focus on header ring
    } else {
        setDynamicSubtitle(session.subtitle);
    }
  }, [session.type, session.subtitle, session.isOnline, session.statusText]);

  // Breathing Animation Loop
  useEffect(() => {
      if (isBreathing) {
          const interval = setInterval(() => {
              setBreathingPhase(prev => prev === 'in' ? 'out' : 'in');
          }, 4000); 
          return () => clearInterval(interval);
      } else {
          setBreathingPhase('in');
      }
  }, [isBreathing]);

  // Auto-fade context banner
  useEffect(() => {
      if (session.type === ViewType.AI_COMPANION) {
          const timer = setTimeout(() => setShowContextBanner(false), 7000); 
          return () => clearTimeout(timer);
      }
  }, [session.type]);

  const scrollToBottom = () => {
    if (scrollRef.current) {
      setTimeout(() => {
        scrollRef.current?.scrollTo({ top: scrollRef.current.scrollHeight, behavior: 'smooth' });
      }, 100);
    }
  };

  const triggerHeartEffect = () => {
      // Create 15 floating hearts
      const newHearts = Array.from({ length: 15 }).map((_, i) => ({
          id: Date.now() + i,
          left: Math.random() * 80 + 10, // Random position 10% to 90% width
          delay: Math.random() * 0.5 // Random start delay
      }));
      setFloatingHearts(newHearts);
      
      // Clear after animation
      setTimeout(() => setFloatingHearts([]), 3000);
  };

  // Slider Logic for Medication
  const handleDragStart = (e: React.MouseEvent | React.TouchEvent) => {
    if (doseTaken) return;
    setIsDragging(true);
    startXRef.current = 'touches' in e ? e.touches[0].clientX : e.clientX;
  };

  const handleDragMove = (e: React.MouseEvent | React.TouchEvent) => {
    if (!isDragging || !sliderRef.current || doseTaken) return;
    const currentX = 'touches' in e ? e.touches[0].clientX : e.clientX;
    const diff = currentX - startXRef.current;
    const maxDrag = sliderRef.current.clientWidth - 56; // Track width - Thumb width (w-12 + padding)
    
    const newValue = Math.max(0, Math.min(diff, maxDrag));
    setSliderValue(newValue);

    if (newValue >= maxDrag * 0.9) {
        setIsDragging(false);
        setDoseTaken(true);
        triggerHeartEffect();
        // Snap to end visual
        setSliderValue(maxDrag);
    }
  };

  const handleDragEnd = () => {
    setIsDragging(false);
    if (!doseTaken) {
        setSliderValue(0);
    }
  };

  const toggleFlip = (msgId: string) => {
    setFlippedCards(prev => ({...prev, [msgId]: !prev[msgId]}));
  };

  // Mood Horizon Handler
  const handleMoodChange = (e: React.ChangeEvent<HTMLInputElement>) => {
      setMoodValue(parseInt(e.target.value));
  };

  // Card Drag Logic (Pull-to-Fold)
  const handleCardDragStart = (e: React.TouchEvent | React.MouseEvent) => {
      setCardDrag(prev => ({ ...prev, active: true }));
      const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY;
      cardStartRef.current = clientY - cardDrag.y;
  };

  const handleCardDragMove = (e: React.TouchEvent | React.MouseEvent) => {
      if (!cardDrag.active) return;
      const clientY = 'touches' in e ? e.touches[0].clientY : e.clientY;
      const newY = Math.max(0, clientY - cardStartRef.current); // Only drag down
      setCardDrag({ active: true, y: newY });
  };

  const handleCardDragEnd = () => {
      if (cardDrag.y > 150) {
          // Dismiss
          onBack();
      } else {
          // Spring back
          setCardDrag({ active: false, y: 0 });
      }
  };

  const handleSend = async (text: string, type: 'text' | 'health-snapshot' = 'text') => {
    const lowerText = text.toLowerCase();
    
    // Distress Detection Logic
    if (session.type === ViewType.PEACE_OF_MIND) {
        if (lowerText.includes('scared') || lowerText.includes('pain') || lowerText.includes('help')) {
            setShowEscalation(true);
            return;
        }
        setLocalMessages(prev => [...prev, {
            id: Date.now().toString(),
            text,
            sender: 'user',
            timestamp: new Date(),
            type: 'text',
            status: 'sent'
        }]);
        scrollToBottom();
        return; 
    }

    const newMessage: Message = {
      id: Date.now().toString(),
      text,
      sender: 'user',
      timestamp: new Date(),
      type: type, // Support specialized message types
      status: 'sending'
    };
    
    setLocalMessages(prev => [...prev, newMessage]);
    onSendMessage(session.id, text); // NOTE: In real app, we'd pass 'type' too
    scrollToBottom();
    setShowSmartReplies(false);

    if (lowerText.includes('anxious') || lowerText.includes('lonely') || lowerText.includes('sad')) {
        setTimeout(() => setShowEscalation(true), 2000);
    }

    setTimeout(() => {
        setLocalMessages(prev => prev.map(m => m.id === newMessage.id ? { ...m, status: 'sent' } : m));
    }, 1000);

    // AI Logic
    if (session.type === ViewType.AI_COMPANION) {
      setIsTyping(true);
      setShowContextBanner(true);
      setTimeout(() => setShowContextBanner(false), 5000);

      try {
         const stream = await geminiService.sendMessageStream(text);
         let responseText = "";
         const responseMsgId = (Date.now() + 1).toString();
         
         setLocalMessages(prev => [...prev, {
             id: responseMsgId,
             text: "",
             sender: 'other',
             timestamp: new Date(),
             type: 'text'
         }]);

         for await (const chunk of stream) {
             const c = chunk as GenerateContentResponse;
             const chunkText = c.text;
             if (chunkText) {
                 responseText += chunkText;
                 setLocalMessages(prev => prev.map(m => 
                     m.id === responseMsgId ? { ...m, text: responseText } : m
                 ));
                 scrollToBottom();
             }
         }
      } catch (e) {
          console.error("AI Error", e);
      } finally {
          setIsTyping(false);
      }
    } else if (session.type === ViewType.CAREGIVER) {
        setIsTyping(true);
        setTimeout(() => {
            setIsTyping(false);
            setLocalMessages(prev => prev.map(m => m.id === newMessage.id ? { ...m, status: 'read' } : m));
            const reply: Message = {
                id: (Date.now() + 1).toString(),
                text: "I saw your message. I'm finishing up at the grocery store and will be there in 20 minutes!",
                sender: 'other',
                timestamp: new Date(),
                type: 'text'
            };
            setLocalMessages(prev => [...prev, reply]);
            scrollToBottom();
        }, 3000);
    } else if (session.type === ViewType.DOCTOR) {
        setIsTyping(true);
        setTimeout(() => {
             setIsTyping(false);
             const reply: Message = {
                 id: (Date.now() + 1).toString(),
                 text: "This is an automated response. Dr. Chen is currently with patients. For medical emergencies, please call 911 or use the Emergency button.\n\n— Dr. Chen",
                 sender: 'other',
                 timestamp: new Date(),
                 type: 'text'
             };
             setLocalMessages(prev => [...prev, reply]);
             scrollToBottom();
        }, 1500);
    }
  };

  const handleDoubleTapMessage = (msgId: string) => {
      setLocalMessages(prev => prev.map(m => {
          if (m.id === msgId && m.sender === 'other') {
              // Toggle heart reaction
              const hasReaction = m.reactions?.some(r => r.fromMe);
              return {
                  ...m,
                  reactions: hasReaction 
                    ? m.reactions?.filter(r => !r.fromMe) 
                    : [...(m.reactions || []), { emoji: '❤️', fromMe: true }]
              };
          }
          return m;
      }));
  };

  const handleVerifiedClick = () => {
    setShowVerifiedToast(true);
    setTimeout(() => setShowVerifiedToast(false), 2000);
  };

  // Sparkline Chart Renderer
  const renderSparkline = (data: number[]) => {
      const min = Math.min(...data);
      const max = Math.max(...data);
      const range = max - min || 1;
      const width = 100;
      const height = 30;
      
      const points = data.map((d, i) => {
          const x = (i / (data.length - 1)) * width;
          const y = height - ((d - min) / range) * height;
          return `${x},${y}`;
      }).join(' ');

      return (
          <div className="mt-3 bg-blue-50/50 rounded-xl p-3 border border-blue-100">
              <div className="flex justify-between items-center mb-1">
                  <span className="text-[10px] font-bold text-gray-400 uppercase tracking-wider">Heart Rate Trend</span>
                  <span className="text-[10px] font-bold text-blue-600 bg-blue-100 px-1.5 py-0.5 rounded-full">Avg: {Math.round(data.reduce((a,b)=>a+b,0)/data.length)}</span>
              </div>
              <svg viewBox={`0 0 ${width} ${height}`} className="w-full h-10 overflow-visible">
                  <polyline
                      fill="none"
                      stroke="#2563EB"
                      strokeWidth="2"
                      points={points}
                      strokeLinecap="round"
                      strokeLinejoin="round"
                  />
                  {/* Dots on points */}
                  {data.map((d, i) => {
                      const x = (i / (data.length - 1)) * width;
                      const y = height - ((d - min) / range) * height;
                      return <circle key={i} cx={x} cy={y} r="2" fill="white" stroke="#2563EB" strokeWidth="1.5" />
                  })}
              </svg>
          </div>
      );
  };

  const isPeaceOfMind = session.type === ViewType.PEACE_OF_MIND;
  
  // --- SPECIAL RENDER FOR PEACE OF MIND (SANCTUARY MODE) ---
  if (isPeaceOfMind) {
      // Calculate tint overlay
      const warmOpacity = moodValue / 100;
      const coolOpacity = (100 - moodValue) / 100;

      return (
        <div className="fixed inset-0 z-20 flex flex-col font-sans overflow-hidden slide-in-right">
             <style>{`
                @keyframes blob-bounce {
                    0% { transform: translate(0, 0) scale(1); }
                    33% { transform: translate(30px, -50px) scale(1.1); }
                    66% { transform: translate(-20px, 20px) scale(0.9); }
                    100% { transform: translate(0, 0) scale(1); }
                }
                .animate-blob {
                    animation: blob-bounce 15s infinite ease-in-out;
                }
                .bg-noise {
                    background-image: url("data:image/svg+xml,%3Csvg viewBox='0 0 200 200' xmlns='http://www.w3.org/2000/svg'%3E%3Cfilter id='noiseFilter'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.65' numOctaves='3' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23noiseFilter)' opacity='0.05'/%3E%3C/svg%3E");
                }
                @keyframes breathe-aura {
                    0% { transform: scale(1); opacity: 0.1; }
                    50% { transform: scale(1.6); opacity: 0.3; } /* Inhale */
                    100% { transform: scale(1); opacity: 0.1; } /* Exhale */
                }
                .animate-breathe {
                    animation: breathe-aura 8s infinite ease-in-out;
                }
                
                @keyframes liquid-blob {
                    0% { border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%; transform: rotate(0deg); }
                    50% { border-radius: 30% 60% 70% 40% / 50% 60% 30% 60%; }
                    100% { border-radius: 60% 40% 30% 70% / 60% 30% 70% 40%; transform: rotate(360deg); }
                }
                .animate-liquid {
                    animation: liquid-blob 8s linear infinite;
                }
             `}</style>
             
             {/* 1. Atmospheric Background (Living Gradient + Noise + Mood Tint) */}
             <div className="absolute inset-0 bg-[#E8E6D9] z-0 transition-colors duration-1000">
                 {/* Moving Gradient Orbs */}
                 <div className="absolute top-[-10%] left-[-10%] w-[80%] h-[70%] bg-[#D4E0D6] rounded-full mix-blend-multiply filter blur-[80px] opacity-70 animate-blob" />
                 <div className="absolute top-[20%] right-[-20%] w-[70%] h-[70%] bg-[#DCE6E9] rounded-full mix-blend-multiply filter blur-[80px] opacity-70 animate-blob" style={{ animationDelay: '2s' }} />
                 <div className="absolute bottom-[-10%] left-[20%] w-[80%] h-[60%] bg-[#E6D4D4] rounded-full mix-blend-multiply filter blur-[80px] opacity-50 animate-blob" style={{ animationDelay: '4s' }} />
                 
                 {/* Mood Tints */}
                 <div className="absolute inset-0 bg-blue-200/30 mix-blend-overlay transition-opacity duration-300 pointer-events-none" style={{ opacity: coolOpacity * 0.5 }} />
                 <div className="absolute inset-0 bg-amber-200/30 mix-blend-overlay transition-opacity duration-300 pointer-events-none" style={{ opacity: warmOpacity * 0.5 }} />
                 
                 {/* Noise Overlay */}
                 <div className="absolute inset-0 bg-noise opacity-40 mix-blend-overlay" />
             </div>

             {/* Header */}
             <div className="relative z-10 flex flex-col items-center pt-14 px-6 safe-area-top">
                 {/* Back Button (Retained as fallback, but primary is drag) */}
                 <button 
                    onClick={onBack}
                    className="absolute left-6 top-14 text-gray-700/40 hover:text-gray-900 transition-colors"
                 >
                     <ChevronLeft className="w-8 h-8" />
                 </button>

                 {/* 3. Audio Soundscape Pill */}
                 <button 
                    onClick={() => setIsPlayingAudio(!isPlayingAudio)}
                    className="flex items-center gap-3 bg-white/20 backdrop-blur-md border border-white/20 rounded-full pl-1.5 pr-4 py-1.5 shadow-sm active:scale-95 transition-transform"
                 >
                     <div className="w-8 h-8 rounded-full bg-white/40 flex items-center justify-center text-teal-800">
                         {isPlayingAudio ? <CloudDrizzle className="w-4 h-4" /> : <Play className="w-4 h-4 ml-0.5" />}
                     </div>
                     <div className="flex flex-col items-start">
                         <span className="text-[11px] font-bold text-gray-700 uppercase tracking-wider leading-none mb-0.5">Soundscape</span>
                         <span className="text-[13px] font-medium text-gray-800 leading-none">Rain on Leaves</span>
                     </div>
                     {/* Animated Bars */}
                     {isPlayingAudio && (
                         <div className="flex items-end gap-0.5 h-3 ml-2">
                             {[1, 2, 3, 2].map((h, i) => (
                                 <div key={i} className="w-0.5 bg-teal-700/60 rounded-full animate-pulse" style={{ height: `${h * 30}%`, animationDelay: `${i * 0.15}s` }} />
                             ))}
                         </div>
                     )}
                 </button>
             </div>

             {/* Main Content: Zen Card with Pull-to-Fold */}
             <div 
                className="flex-1 relative z-10 flex items-center justify-center p-8 perspective-1000"
                style={{ perspective: '1000px' }}
                onMouseDown={handleCardDragStart}
                onMouseMove={handleCardDragMove}
                onMouseUp={handleCardDragEnd}
                onMouseLeave={handleCardDragEnd}
                onTouchStart={handleCardDragStart}
                onTouchMove={handleCardDragMove}
                onTouchEnd={handleCardDragEnd}
             >
                 <div 
                    className="w-full max-w-sm bg-white/30 backdrop-blur-[40px] border border-white/40 shadow-[0_20px_60px_rgba(0,0,0,0.05)] rounded-[40px] p-8 text-center cursor-grab active:cursor-grabbing select-none"
                    style={{
                        transform: `translateY(${cardDrag.y}px) rotateX(${cardDrag.y * 0.1}deg) scale(${1 - cardDrag.y * 0.0005})`,
                        opacity: 1 - (cardDrag.y / 400),
                        transition: cardDrag.active ? 'none' : 'all 0.5s cubic-bezier(0.2, 0.8, 0.2, 1)'
                    }}
                 >
                     <p className="text-xs font-bold text-gray-500 uppercase tracking-widest mb-6 pointer-events-none">Daily Reflection</p>
                     
                     <h2 className="text-[32px] font-serif text-gray-800 leading-tight mb-8 pointer-events-none">
                        {localMessages[localMessages.length - 1]?.text || "What is one small thing that made you smile today?"}
                     </h2>
                     
                     {/* "Handle" for dragging affordance */}
                     <div className="w-8 h-1 bg-gray-400/20 rounded-full mx-auto" />
                     <p className="text-[10px] text-gray-400 mt-2 font-medium opacity-50">Pull down to close</p>
                 </div>
             </div>

             {/* Footer: Mood Slider & Voice Journal */}
             <div className="relative z-10 pb-12 safe-area-bottom flex flex-col items-center justify-end">
                 
                 {/* 3. Mood Horizon Slider */}
                 <div className="w-64 mb-10 relative group">
                     {/* Track */}
                     <div className="absolute top-1/2 left-0 right-0 h-1 bg-gray-900/5 rounded-full backdrop-blur-sm overflow-hidden">
                         {/* Gradient Fill */}
                         <div className="absolute inset-0 bg-gradient-to-r from-blue-300 via-gray-300 to-amber-300 opacity-50" />
                     </div>
                     <input 
                        type="range" 
                        min="0" 
                        max="100" 
                        value={moodValue} 
                        onChange={handleMoodChange}
                        className="w-full h-8 opacity-0 cursor-pointer relative z-20"
                     />
                     {/* Custom Thumb (Sun Icon that slides) */}
                     <div 
                        className="absolute top-1/2 -translate-y-1/2 pointer-events-none z-10 transition-all duration-75 flex items-center justify-center w-8 h-8 bg-white rounded-full shadow-sm border border-white/50 text-gray-400"
                        style={{ left: `calc(${moodValue}% - 16px)` }}
                     >
                         <Sun className={`w-4 h-4 transition-colors ${moodValue > 60 ? 'text-amber-500 fill-amber-500' : moodValue < 40 ? 'text-blue-400' : 'text-gray-400'}`} />
                     </div>
                     
                     {/* Labels */}
                     <div className="absolute -bottom-6 left-0 text-[10px] font-bold text-gray-400 uppercase tracking-wider opacity-0 group-hover:opacity-100 transition-opacity">Cloudy</div>
                     <div className="absolute -bottom-6 right-0 text-[10px] font-bold text-gray-400 uppercase tracking-wider opacity-0 group-hover:opacity-100 transition-opacity">Sunny</div>
                 </div>

                 {/* 1. & 2. Breathing Aura + Liquid Voice Visualizer */}
                 <div className="relative flex items-center justify-center">
                    
                     {/* Breathing Aura Ring (Always active, subconscious guidance) */}
                     <div className={`absolute w-32 h-32 rounded-full border border-white/40 animate-breathe pointer-events-none transition-opacity duration-500 ${isReflecting ? 'opacity-0' : 'opacity-100'}`} />

                     {/* Button Container */}
                     <button
                        className="relative outline-none select-none touch-none"
                        onMouseDown={() => setIsReflecting(true)}
                        onMouseUp={() => setIsReflecting(false)}
                        onTouchStart={() => setIsReflecting(true)}
                        onTouchEnd={() => setIsReflecting(false)}
                     >
                         {/* Liquid Blob (Active State) */}
                         <div className={`absolute inset-0 bg-gradient-to-tr from-amber-200 via-white to-teal-100 opacity-90 blur-md transition-all duration-500
                            ${isReflecting ? 'animate-liquid scale-125 opacity-100' : 'scale-75 opacity-0'}
                         `} style={{ borderRadius: '40% 60% 70% 30% / 40% 50% 60% 50%' }} />
                         
                         {/* The Physical Button */}
                         <div className={`relative w-20 h-20 rounded-full flex items-center justify-center shadow-lg transition-all duration-500 z-10
                             ${isReflecting 
                                ? 'bg-white/20 backdrop-blur-sm scale-90 border border-white/50' 
                                : 'bg-[#F2F2F2]/80 backdrop-blur-md hover:bg-white scale-100 border border-white/20'
                             }
                         `}>
                             <Mic className={`w-8 h-8 transition-colors duration-300 ${isReflecting ? 'text-gray-800' : 'text-gray-600'}`} />
                         </div>
                     </button>
                 </div>
                 
                 <p className={`text-sm font-medium text-gray-400 mt-6 transition-opacity duration-500 ${isReflecting ? 'opacity-0' : 'opacity-100'}`}>
                     Hold to reflect
                 </p>
             </div>
        </div>
      );
  }

  const isCommunity = false;
  const isAI = session.type === ViewType.AI_COMPANION;
  const isCaregiver = session.type === ViewType.CAREGIVER;
  const isDoctor = session.type === ViewType.DOCTOR;
  const isSystem = session.type === ViewType.SYSTEM;
  
  const getHeaderStyles = () => {
      if (isAI) return "bg-white/70 backdrop-blur-xl border-b border-black/5 text-gray-900 sticky top-0 z-40"; 
      if (isCaregiver) return "bg-[#F2F1ED]/80 backdrop-blur-xl border-b border-stone-200 text-gray-900 sticky top-0 z-40";
      if (isDoctor) return "bg-white/95 backdrop-blur-xl border-b border-gray-100 text-gray-900 sticky top-0 z-40";
      if (isSystem) return "bg-white/95 backdrop-blur-xl border-b border-gray-100 text-gray-900 sticky top-0 z-40";
      return "bg-[#f2f2f7] text-gray-900 border-b border-gray-200/50 sticky top-0 z-30";
  };

  const renderHeaderIcon = () => {
    switch (session.type) {
      case ViewType.AI_COMPANION: return null; 
      // Doctor replaced with custom avatar below
      case ViewType.DOCTOR: return null; 
      // System replaced with Progress Ring below
      case ViewType.SYSTEM: return null;
      default: return <User className="w-8 h-8 text-gray-400" />;
    }
  };

  const getContainerBackground = () => {
      if (isAI) return "bg-white"; 
      if (isCaregiver) return "bg-[#F2F1ED]"; // Warm Cream Wallpaper
      if (isDoctor || isSystem) return "bg-gray-50";
      return "bg-[#f2f2f7]";
  };

  const formatMessageTime = (date: Date) => {
      return date.toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' }).toLowerCase().replace(' ', '');
  };

  return (
    <div className={`fixed inset-0 flex flex-col z-20 slide-in-right safe-area-top safe-area-bottom 
        ${getContainerBackground()}`}>
      
      {/* 0. CAREGIVER WALLPAPER TEXTURE */}
      {isCaregiver && (
          <div className="absolute inset-0 z-0 pointer-events-none opacity-40" 
               style={{ 
                   backgroundImage: 'radial-gradient(circle at 50% 50%, #d6d3ce 1px, transparent 1px)',
                   backgroundSize: '30px 30px' 
               }} 
          />
      )}

      {/* 0. FLOATING HEART EFFECTS */}
      {floatingHearts.map((heart) => (
          <div 
             key={heart.id}
             className="absolute bottom-20 z-50 animate-float-up pointer-events-none"
             style={{ 
                 left: `${heart.left}%`,
                 animationDelay: `${heart.delay}s`,
                 animationDuration: '2.5s'
             }}
          >
             <Heart className="w-8 h-8 text-pink-500 fill-pink-500 drop-shadow-md" />
             <style>{`
                @keyframes floatUp {
                    0% { transform: translateY(0) scale(0.5); opacity: 0; }
                    20% { opacity: 1; transform: translateY(-50px) scale(1.2); }
                    100% { transform: translateY(-80vh) scale(1); opacity: 0; }
                }
                .animate-float-up {
                    animation-name: floatUp;
                    animation-timing-function: ease-out;
                    animation-fill-mode: forwards;
                }
             `}</style>
          </div>
      ))}

      {/* 4. SIRI-STYLE THINKING GLOW (Iridescent Border) */}
      {isAI && isTyping && (
          <div className="absolute inset-0 z-50 pointer-events-none">
              <div className="absolute inset-0 shadow-[inset_0_0_80px_20px_rgba(99,102,241,0.2)] animate-pulse" />
              <div className="absolute inset-x-0 bottom-0 h-1/2 bg-gradient-to-t from-indigo-500/10 to-transparent" />
          </div>
      )}

      {/* 1. APPLE INTELLIGENCE AMBIENT GLOW (Only for AI) */}
      {isAI && (
          <div className="absolute inset-0 z-0 pointer-events-none overflow-hidden">
              <div className="absolute top-[-20%] left-[-20%] w-[80%] h-[60%] bg-indigo-300/20 blur-[80px] rounded-full mix-blend-multiply animate-pulse-slow" />
              <div className="absolute top-[10%] right-[-10%] w-[60%] h-[60%] bg-pink-300/20 blur-[80px] rounded-full mix-blend-multiply animate-pulse-slow" style={{ animationDelay: '2s' }} />
              <div className="absolute bottom-[-10%] left-[20%] w-[70%] h-[50%] bg-purple-300/20 blur-[80px] rounded-full mix-blend-multiply animate-pulse-slow" style={{ animationDelay: '4s' }} />
              
              {/* Iridescent Edge Overlay */}
              <div className="absolute inset-0 bg-gradient-to-tr from-white/0 via-white/0 to-white/40 opacity-50" />
          </div>
      )}

      {/* Verified Professional Toast */}
      {showVerifiedToast && (
          <div className="absolute top-24 left-1/2 -translate-x-1/2 z-50 bg-gray-900/90 backdrop-blur-md text-white px-4 py-2 rounded-full flex items-center gap-2 animate-in fade-in slide-in-from-top-4 shadow-lg">
              <ShieldCheck className="w-4 h-4 text-blue-400" />
              <span className="text-sm font-semibold">Verified healthcare professional</span>
          </div>
      )}

      {/* Navbar */}
      <div className={`flex-none px-4 py-3 flex items-center justify-between transition-colors duration-300 relative z-30 ${getHeaderStyles()}`}>
        <div className="flex items-center gap-2">
          {/* Back Button */}
          <button 
            onClick={onBack} 
            className={`flex items-center gap-1 pr-4 py-2 rounded-lg active:opacity-50 transition-all ${isAI ? 'text-gray-900' : isCommunity ? 'text-orange-600' : 'text-blue-600'}`}
          >
            <ChevronLeft className="w-8 h-8 -ml-2" />
            <span className="text-lg font-medium">{isCommunity ? 'Community' : 'Chats'}</span>
          </button>
          
          <div className="flex items-center gap-3">
             {/* 2. THE HALO AVATAR (Now visible for AI too) */}
             {isDoctor ? (
                 <div className="relative w-10 h-10 rounded-full overflow-visible">
                     <div className="w-10 h-10 rounded-full bg-blue-50 border border-blue-100 flex items-center justify-center overflow-hidden">
                         <img src="https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop" alt="Dr. Emily" className="w-full h-full object-cover" />
                     </div>
                     {/* Status Dot */}
                     <div className={`absolute bottom-0 right-0 w-3 h-3 rounded-full border-2 border-white ${session.isOnline ? 'bg-green-500' : 'bg-gray-400'}`} />
                 </div>
             ) : isSystem ? (
                 // Adherence Ring for System View
                 <div className="w-10 h-10 relative flex items-center justify-center">
                     <svg height="40" width="40" className="rotate-[-90deg]">
                          <circle stroke="#E5E7EB" strokeWidth="3" fill="transparent" r="16" cx="20" cy="20" />
                          <circle 
                            stroke="#10B981" 
                            strokeWidth="3" 
                            strokeDasharray={`${2 * Math.PI * 16}`} 
                            strokeDashoffset={(2 * Math.PI * 16) - ((doseTaken ? 100 : (session.medicationProgress || 0)) / 100 * (2 * Math.PI * 16))} 
                            strokeLinecap="round" 
                            fill="transparent" 
                            r="16" 
                            cx="20" 
                            cy="20" 
                            className="transition-all duration-1000 ease-out"
                          />
                     </svg>
                     <Pill className="w-4 h-4 text-gray-500 absolute" />
                 </div>
             ) : (
                <div className={`w-10 h-10 rounded-full flex items-center justify-center overflow-hidden shadow-sm relative 
                    ${isAI ? 'bg-indigo-50 text-indigo-600' : 'bg-white'}
                `}>
                    {isAI ? (
                        <>
                            {/* Halo Pulse */}
                            <div className="absolute inset-0 rounded-full border-2 border-indigo-200 opacity-60 animate-pulse" />
                            <div className="absolute inset-0 rounded-full border border-purple-300 opacity-30 scale-125 animate-pulse-slow" />
                            <CloudSun className="w-6 h-6 relative z-10" />
                        </>
                    ) : (
                    session.type === ViewType.CAREGIVER ? (
                        <div className="w-full h-full bg-blue-100 flex items-center justify-center text-blue-600 font-bold text-lg">
                            {session.name.charAt(0)}
                        </div>
                    ) : renderHeaderIcon()
                    )}
                </div>
             )}
            
            <div className="flex flex-col">
              <div className="flex items-center gap-1">
                  <h2 className="font-semibold text-[17px] leading-tight flex items-center gap-2">
                      {session.name}
                  </h2>
                  {isDoctor && (
                    <div className="flex items-center gap-0.5 px-1.5 py-0.5 bg-blue-50/80 rounded-full">
                        <BadgeCheck className="w-3.5 h-3.5 text-blue-500 fill-blue-500/10" />
                        <span className="text-[10px] font-bold text-blue-600 uppercase tracking-tight">Verified</span>
                    </div>
                  )}
                  {/* Streak Flame Badge for System */}
                  {isSystem && session.messages.some(m => m.medication?.streakDays) && (
                      <div className="flex items-center gap-0.5 px-1.5 py-0.5 bg-orange-50 rounded-full animate-in zoom-in duration-300">
                          <Flame className="w-3 h-3 text-orange-500 fill-orange-500" />
                          <span className="text-[10px] font-bold text-orange-600">{session.messages.find(m => m.medication)?.medication?.streakDays} Day Streak</span>
                      </div>
                  )}
              </div>
              {/* Pinned Context (Caregiver) or Subtitle */}
              {isCaregiver ? (
                  <div className="flex items-center gap-1.5 text-blue-600/80 bg-blue-50/50 px-2 py-0.5 rounded-md mt-0.5 self-start">
                    <Calendar className="w-3 h-3" />
                    <span className="text-[11px] font-semibold">Visit: 5:00 PM Today</span>
                  </div>
              ) : isSystem ? (
                  <p className="text-[13px] text-gray-500 transition-all duration-500">
                      {doseTaken ? "All meds taken today" : `${session.medicationProgress}% for today`}
                  </p>
              ) : (
                !isAI && dynamicSubtitle && (
                    <p className={`text-[13px] transition-opacity duration-500 ${isCommunity ? 'text-orange-800/60' : 'text-gray-500'}`}>
                        {dynamicSubtitle}
                    </p>
                )
              )}
            </div>
          </div>
        </div>

        {/* 3. GLASS CONTEXT BUTTON (Right Side) */}
        <div className="flex items-center gap-4">
            {isAI ? (
                <button className="w-10 h-10 rounded-full bg-gray-100/50 backdrop-blur-md flex items-center justify-center text-gray-500 hover:bg-gray-200/50 transition-colors">
                    <MoreHorizontal className="w-5 h-5" />
                </button>
            ) : session.type === ViewType.CAREGIVER && (
                <div className="flex gap-4 text-blue-600">
                    <button className="rounded-full active:opacity-50 transition-opacity"><Phone className="w-6 h-6 fill-current" /></button>
                    <button className="rounded-full active:opacity-50 transition-opacity"><Video className="w-7 h-7" /></button>
                </div>
            )}
             {isDoctor && (
                <button className="w-9 h-9 rounded-full bg-gray-100 flex items-center justify-center text-gray-500">
                    <Info className="w-5 h-5" />
                </button>
            )}
        </div>
      </div>

      {/* Appointment Banner (Doctor only) */}
      {isDoctor && session.nextAppointment && (
          <div className="absolute top-[80px] left-0 right-0 flex justify-center z-20 pointer-events-none">
              <button className="bg-white/80 backdrop-blur-xl border border-white/60 text-gray-900 pl-4 pr-1 py-1.5 rounded-full flex items-center justify-between gap-6 shadow-sm active:scale-95 transition-transform pointer-events-auto">
                 <div className="flex items-center gap-2">
                    <Calendar className="w-4 h-4 text-blue-600" />
                    <span className="text-[12px] font-semibold tracking-wide">
                        Next Visit: {session.nextAppointment.toLocaleDateString('en-US', { weekday: 'short', hour: 'numeric', minute: '2-digit' })} (Video)
                    </span>
                 </div>
                 <div className="bg-blue-50 text-blue-600 rounded-full px-3 py-1 text-[10px] font-bold flex items-center gap-1">
                     Details <ChevronRight className="w-3 h-3" />
                 </div>
              </button>
          </div>
      )}

      {/* 4. REFINE STATUS PILL (The Floater) */}
      {isAI && (
          <div className="absolute top-[88px] left-0 right-0 flex justify-center z-20 pointer-events-none">
              <div className="bg-white/80 backdrop-blur-2xl border border-white/40 text-gray-900 pl-3 pr-4 py-1.5 rounded-full flex items-center gap-2.5 shadow-[0_4px_12px_rgba(0,0,0,0.08)] animate-in slide-in-from-top-2">
                 <div className="w-1.5 h-1.5 bg-green-500 rounded-full animate-pulse shadow-[0_0_8px_rgba(34,197,94,0.6)]" />
                 <div className="flex items-center gap-1.5 border-l border-gray-300/50 pl-2.5">
                    <HeartPulse className="w-3.5 h-3.5 text-red-500 animate-pulse" />
                    <span className="text-[11px] font-semibold tracking-wide tabular-nums">72 BPM</span>
                 </div>
                 <div className="flex items-center gap-1.5 border-l border-gray-300/50 pl-2.5">
                    <span className="text-[10px] text-gray-500 font-medium">Monitoring</span>
                 </div>
              </div>
          </div>
      )}

      {/* Messages Area */}
      <div className={`flex-1 overflow-y-auto p-4 ${isAI ? 'pb-40 pt-24' : ''} ${isDoctor ? 'pt-20' : ''} relative z-10`} ref={scrollRef}>
         
         {/* HIPAA Footer/Header */}
         {isDoctor && (
             <div className="flex justify-center mb-6 mt-2">
                 <div className="flex items-center gap-1.5 text-gray-400/80">
                     <Lock className="w-3 h-3" />
                     <span className="text-[10px] font-semibold uppercase tracking-wider">End-to-End Encrypted • HIPAA Compliant</span>
                 </div>
             </div>
         )}

         {/* Today divider (Only for non-AI to avoid clash with Vitals Island) */}
         {!isAI && !isDoctor && !isSystem && (
             <div className="text-center py-4">
                 <span className={`text-[11px] font-semibold uppercase tracking-wide px-3 py-1 rounded-full backdrop-blur-sm ${isCaregiver ? 'bg-stone-200/50 text-stone-500' : 'bg-gray-200/40 text-gray-400'}`}>Today</span>
             </div>
         )}

         {/* GLOBAL EVENT LISTENER FOR SLIDER */}
         {isDragging && (
            <div 
                className="fixed inset-0 z-[100] cursor-grabbing"
                onMouseMove={handleDragMove}
                onMouseUp={handleDragEnd}
                onTouchMove={handleDragMove}
                onTouchEnd={handleDragEnd}
            />
         )}

         <div className="space-y-2 pb-16">
            {localMessages.map((msg, index) => {
                const isMe = msg.sender === 'user';
                const isSystemMsg = msg.sender === 'system';
                const isHealthSnapshot = msg.type === 'health-snapshot';
                const isPrescription = !!msg.prescription;
                const isMedicationReminder = !!msg.medication;
                
                // Message Grouping Logic
                const isSameSender = index > 0 && localMessages[index - 1].sender === msg.sender;
                
                // Tail Logic
                const isLastInGroup = index === localMessages.length - 1 || localMessages[index + 1].sender !== msg.sender;
                const mtClass = isSameSender ? 'mt-1' : 'mt-5';
                
                // 1. "Hero" Pill Card (Medication Reminder)
                if (isMedicationReminder && msg.medication) {
                    const isCardFlipped = flippedCards[msg.id] || false;
                    
                    return (
                        <div key={msg.id} className="flex flex-col items-center my-6 w-full animate-in slide-in-from-bottom-6 fade-in duration-500 relative">
                             
                             {/* 1. "Next Up" Glass Stack (Peeking Context) */}
                             {msg.medication.nextDose && !doseTaken && (
                                <div className="absolute top-4 w-[85%] max-w-[300px] bg-white/40 backdrop-blur-sm border border-white/40 rounded-[32px] p-6 shadow-sm z-0 transform scale-95 opacity-50 blur-[1px]">
                                    <div className="flex justify-between items-center opacity-0">
                                        {/* Invisible filler to maintain height */}
                                        <div className="h-20" />
                                    </div>
                                    <div className="absolute bottom-2 left-6 right-6 flex justify-between items-center opacity-100">
                                        <span className="text-[10px] font-bold text-gray-500 uppercase tracking-widest">{msg.medication.nextDose.time}</span>
                                        <span className="text-xs font-semibold text-gray-600">{msg.medication.nextDose.name}</span>
                                    </div>
                                </div>
                             )}

                             {/* The Main Card Container with 3D Perspective */}
                             <div className="relative w-full max-w-[340px] perspective-1000 group z-10" style={{ perspective: '1000px' }}>
                                 <div 
                                    className={`relative w-full transition-all duration-700`}
                                    style={{ 
                                        transformStyle: 'preserve-3d', 
                                        transform: isCardFlipped ? 'rotateY(180deg)' : 'rotateY(0deg)',
                                        minHeight: '260px' // Ensure height for flip
                                    }}
                                 >
                                     {/* FRONT FACE */}
                                     <div 
                                        className={`absolute inset-0 bg-white/90 backdrop-blur-xl border border-white/60 shadow-[0_12px_40px_rgba(0,0,0,0.06)] rounded-[32px] p-6 overflow-hidden flex flex-col justify-between ${doseTaken ? 'ring-2 ring-green-400/30' : ''}`}
                                        style={{ backfaceVisibility: 'hidden' }}
                                     >
                                         {/* Background Shine */}
                                         <div className="absolute -top-20 -right-20 w-40 h-40 bg-gradient-to-br from-white via-white to-transparent opacity-50 rounded-full blur-2xl pointer-events-none" />

                                         <div className="flex justify-between items-start mb-4 relative z-10">
                                              {/* 3D Realistic Pill Visualization */}
                                             <div className={`w-20 h-20 rounded-full bg-gray-100 shadow-[inset_0_4px_8px_rgba(0,0,0,0.05)] flex items-center justify-center relative group`}>
                                                  <div className={`w-12 h-12 rounded-full shadow-[0_8px_16px_rgba(0,0,0,0.15),inset_0_-4px_8px_rgba(0,0,0,0.05)] transform transition-transform duration-500 ${doseTaken ? 'scale-0 opacity-0' : 'group-hover:scale-105 rotate-12'} ${msg.medication.pillColor || 'bg-blue-100'}`} style={{background: 'radial-gradient(circle at 30% 30%, white, #e1e1e1)'}} />
                                                  {doseTaken && (
                                                      <CheckCircle2 className="w-10 h-10 text-green-500 animate-in zoom-in spin-in-90 duration-500 absolute" />
                                                  )}
                                             </div>

                                             {/* 2. Supply Level Indicator (Top Right) */}
                                             {msg.medication.inventory && (
                                                 <div className="flex flex-col items-center gap-1">
                                                     <div className="w-3 h-8 border border-gray-200 bg-gray-50 rounded-full overflow-hidden relative shadow-inner">
                                                         <div 
                                                            className={`absolute bottom-0 w-full transition-all duration-1000 ${msg.medication.inventory.status === 'low' ? 'bg-orange-400' : 'bg-green-400'}`}
                                                            style={{ height: `${(msg.medication.inventory.remaining / msg.medication.inventory.total) * 100}%` }}
                                                         />
                                                     </div>
                                                     <span className="text-[9px] font-bold text-gray-400">{msg.medication.inventory.remaining} left</span>
                                                 </div>
                                             )}
                                         </div>

                                         <div className="relative z-10">
                                             <p className="text-xs font-bold text-gray-400 uppercase tracking-wide mb-1">
                                                 {doseTaken ? "Completed" : "Scheduled for 2:00 PM"}
                                             </p>
                                             <h2 className={`text-2xl font-bold text-gray-900 leading-tight transition-all ${doseTaken ? 'text-green-600' : ''}`}>
                                                 {msg.medication.name}
                                             </h2>
                                             <p className="text-sm font-medium text-gray-500 mt-1">
                                                 {msg.medication.dosage} • {msg.medication.context}
                                             </p>
                                         </div>

                                         {/* 3. Flip Button (Info) */}
                                         <button 
                                            onClick={() => toggleFlip(msg.id)}
                                            className="absolute bottom-20 right-6 w-6 h-6 rounded-full bg-gray-100 flex items-center justify-center text-gray-500 hover:bg-gray-200 transition-colors z-20"
                                         >
                                             <Info className="w-3.5 h-3.5" />
                                         </button>

                                         {/* Swipe Slider */}
                                         <div className="relative h-14 bg-gray-100 rounded-full flex items-center p-1 overflow-hidden mt-4">
                                             {doseTaken ? (
                                                 <div className="w-full h-full flex items-center justify-center gap-2 text-green-600 font-bold animate-in fade-in">
                                                     <Check className="w-5 h-5 stroke-[3px]" />
                                                     Taken at {new Date().toLocaleTimeString([], { hour: 'numeric', minute: '2-digit' })}
                                                 </div>
                                             ) : (
                                                 <>
                                                    <div className="absolute inset-0 flex items-center justify-center pointer-events-none">
                                                        <span className={`text-[13px] font-bold text-gray-400 uppercase tracking-widest transition-opacity ${isDragging ? 'opacity-0' : 'opacity-100'}`}>
                                                            Slide to take
                                                        </span>
                                                        <ChevronRight className={`w-4 h-4 text-gray-400 ml-1 animate-pulse ${isDragging ? 'opacity-0' : 'opacity-100'}`} />
                                                    </div>
                                                    <div 
                                                        ref={sliderRef}
                                                        className="w-full h-full relative"
                                                    >
                                                        <div 
                                                            className={`absolute top-0 bottom-0 w-12 bg-white rounded-full shadow-[0_2px_8px_rgba(0,0,0,0.1)] flex items-center justify-center cursor-grab active:cursor-grabbing z-20 ${doseTaken ? 'hidden' : ''}`}
                                                            style={{ transform: `translateX(${sliderValue}px)` }}
                                                            onMouseDown={handleDragStart}
                                                            onTouchStart={handleDragStart}
                                                        >
                                                            <Pill className="w-5 h-5 text-blue-500" />
                                                        </div>
                                                        {/* Green Fill Track */}
                                                        <div 
                                                            className="absolute top-0 left-0 bottom-0 bg-green-100 rounded-full transition-all duration-75"
                                                            style={{ width: `${sliderValue + 48}px`, opacity: sliderValue > 0 ? 1 : 0 }}
                                                        />
                                                    </div>
                                                 </>
                                             )}
                                         </div>
                                     </div>

                                     {/* BACK FACE (Details) */}
                                     <div 
                                        className="absolute inset-0 bg-[#F5F5F7] border border-gray-200 rounded-[32px] p-6 flex flex-col shadow-inner"
                                        style={{ backfaceVisibility: 'hidden', transform: 'rotateY(180deg)' }}
                                     >
                                         <div className="flex justify-between items-start mb-4">
                                             <h3 className="text-lg font-bold text-gray-900">Clinical Details</h3>
                                             <button 
                                                onClick={() => toggleFlip(msg.id)}
                                                className="w-8 h-8 rounded-full bg-white border border-gray-200 flex items-center justify-center text-gray-500 shadow-sm"
                                             >
                                                 <RotateCcw className="w-4 h-4" />
                                             </button>
                                         </div>
                                         
                                         <div className="flex-1 space-y-4 overflow-y-auto no-scrollbar">
                                             <div>
                                                 <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1">Doctor's Note</p>
                                                 <p className="text-sm text-gray-700 bg-white p-3 rounded-xl border border-gray-100 italic">
                                                     "{msg.medication.doctorNotes}"
                                                 </p>
                                             </div>
                                             <div>
                                                 <p className="text-[10px] font-bold text-gray-400 uppercase tracking-wider mb-1">Potential Side Effects</p>
                                                 <div className="flex flex-wrap gap-2">
                                                     {msg.medication.sideEffects?.map((effect, i) => (
                                                         <span key={i} className="px-2.5 py-1 bg-white border border-gray-200 rounded-lg text-xs font-medium text-gray-600">
                                                             {effect}
                                                         </span>
                                                     ))}
                                                 </div>
                                             </div>
                                         </div>
                                         
                                         <div className="mt-4 pt-4 border-t border-gray-200/50 flex justify-between items-center">
                                             <span className="text-xs text-gray-400">Refill ID: #839210</span>
                                             <span className="text-xs font-bold text-blue-600">View Full Insert</span>
                                         </div>
                                     </div>
                                 </div>
                             </div>
                        </div>
                    );
                }

                if (isSystemMsg) {
                    return (
                        <div key={msg.id} className="flex flex-col items-center my-4 w-full">
                            <div className="bg-gray-100 text-gray-800 text-[15px] leading-relaxed px-6 py-4 rounded-3xl text-center max-w-[90%] mb-4 shadow-sm border border-gray-200">
                                {msg.text}
                            </div>
                        </div>
                    );
                }

                return (
                    <div key={msg.id} className={`flex flex-col ${isMe ? 'items-end' : 'items-start'} ${mtClass} animate-in slide-in-from-bottom-2 fade-in duration-300`}>
                        <div 
                            className={`flex ${isMe ? 'justify-end' : 'justify-start'} group max-w-[90%] items-end gap-2 relative`}
                            onDoubleClick={() => handleDoubleTapMessage(msg.id)}
                        >
                            {/* ... (Existing Avatar Logic) ... */}
                            {!isMe && (
                                <div className={`w-8 h-8 rounded-full mb-1 flex-shrink-0 flex items-center justify-center shadow-sm z-10
                                    ${isAI ? 'bg-gradient-to-tr from-indigo-400 to-purple-400 text-white shadow-purple-200' : 'bg-gray-200 text-gray-500 font-bold text-xs'}
                                    ${isSameSender ? 'opacity-0' : 'opacity-100'}
                                    ${isDoctor ? 'bg-white border border-gray-100 overflow-hidden' : ''}
                                `}>
                                    {isAI ? <CloudSun className="w-5 h-5" /> 
                                     : isDoctor ? <img src="https://images.unsplash.com/photo-1559839734-2b71ea860632?q=80&w=100&auto=format&fit=crop" className="w-full h-full object-cover" /> 
                                     : session.name.charAt(0)}
                                </div>
                            )}

                            {/* Health Snapshot Widget (Special Render) */}
                            {isHealthSnapshot ? (
                                <div className="bg-white p-1 rounded-[24px] shadow-sm rounded-br-sm border border-gray-100">
                                    <div className="flex items-center gap-3 bg-green-50 rounded-[20px] p-3 pr-5">
                                        <div className="w-10 h-10 rounded-full bg-green-500 flex items-center justify-center text-white shadow-green-200 shadow-md">
                                            <Check className="w-6 h-6 stroke-[3px]" />
                                        </div>
                                        <div className="text-left">
                                            <p className="text-[15px] font-bold text-gray-900 leading-tight">Afternoon Meds</p>
                                            <p className="text-[12px] font-medium text-green-700 leading-tight opacity-80 mt-0.5">Taken at 1:15 PM</p>
                                        </div>
                                    </div>
                                </div>
                            ) : isPrescription && msg.prescription ? (
                                /* Prescription Widget */
                                <div className="bg-white p-4 rounded-[24px] shadow-sm rounded-bl-sm border border-gray-100 max-w-[260px]">
                                    <div className="flex items-start gap-3 mb-3">
                                        <div className="w-10 h-10 rounded-full bg-blue-50 flex items-center justify-center text-blue-600">
                                            <Pill className="w-5 h-5" />
                                        </div>
                                        <div>
                                            <h3 className="font-bold text-gray-900 text-[15px]">{msg.prescription.name}</h3>
                                            <p className="text-xs text-gray-500">{msg.prescription.dosage}</p>
                                        </div>
                                    </div>
                                    <div className="bg-gray-50 rounded-xl p-3 mb-3">
                                        <p className="text-[13px] text-gray-600 leading-snug">{msg.prescription.instructions}</p>
                                    </div>
                                    <button className="w-full py-2 bg-blue-600 text-white rounded-xl text-sm font-bold shadow-sm active:scale-95 transition-transform">
                                        Order Refill
                                    </button>
                                    
                                    {/* Text explanation above it */}
                                    <p className="text-[13px] text-gray-500 mt-2 px-1">{msg.text}</p>
                                    
                                    {/* Integrated Timestamp (Bottom Right) */}
                                    <div className="flex justify-end items-center gap-1 mt-1 opacity-60">
                                        <span className="text-[10px] text-gray-400 font-medium">
                                            {formatMessageTime(msg.timestamp)}
                                        </span>
                                    </div>
                                </div>
                            ) : (
                                /* Standard Glass Message Bubble */
                                <div className={`px-5 py-3.5 text-[17px] relative transition-all whitespace-pre-wrap
                                    ${isMe 
                                        ? isCaregiver 
                                            ? `bg-gradient-to-b from-blue-500 to-blue-600 text-white rounded-[20px] shadow-sm ${isLastInGroup ? 'rounded-br-sm' : ''}` // Caregiver specific gradient & tail
                                        : 'bg-blue-500 text-white rounded-[26px] rounded-br-sm shadow-md' 
                                        : isAI
                                            ? 'bg-white/40 backdrop-blur-md text-gray-800 rounded-[26px] rounded-bl-sm shadow-sm' // Floating Glass
                                        : isCaregiver
                                            ? `bg-white text-gray-900 rounded-[20px] shadow-sm ${isLastInGroup ? 'rounded-bl-sm' : ''}` 
                                        : isDoctor
                                            ? 'bg-white/80 backdrop-blur-sm text-gray-800 rounded-[20px] rounded-bl-sm border border-gray-100/50 shadow-sm'
                                        : 'bg-white text-gray-900 rounded-[26px] rounded-bl-sm border border-gray-100'
                                    }
                                    ${isSameSender && isMe ? 'rounded-tr-xl !mt-0.5' : ''}
                                    ${isSameSender && !isMe ? 'rounded-tl-xl !mt-0.5' : ''}
                                `}>
                                    {msg.text}
                                    
                                    {/* Data-Rich Content (Sparkline) */}
                                    {msg.chartData && renderSparkline(msg.chartData)}

                                    {/* Integrated Timestamp & Read Receipts (Inside Bubble) */}
                                    <div className={`flex justify-end items-center gap-1 mt-1 ${isMe ? 'text-blue-100' : 'text-gray-400'} opacity-80`}>
                                        <span className="text-[10px] font-medium">
                                            {formatMessageTime(msg.timestamp)}
                                        </span>
                                        {isMe && (
                                            msg.status === 'read' 
                                            ? <CheckCheck className="w-3 h-3 text-white" /> 
                                            : <Check className="w-3 h-3 text-white/70" />
                                        )}
                                    </div>

                                    {/* Tapback Reactions (Pill attached to bubble) */}
                                    {msg.reactions && msg.reactions.length > 0 && (
                                        <div className={`absolute -top-3 ${isMe ? '-left-2' : '-right-2'} bg-gray-100/90 backdrop-blur-sm border border-white shadow-sm rounded-full px-1.5 py-0.5 text-xs flex items-center gap-1 z-20 animate-in zoom-in duration-300`}>
                                            {msg.reactions.map((r, i) => (
                                                <span key={i} className="text-[14px] leading-none">{r.emoji}</span>
                                            ))}
                                        </div>
                                    )}
                                </div>
                            )}
                        </div>
                    </div>
                );
            })}
         </div>
         <div className="h-4" /> 
      </div>

      {/* Floating Smart Replies (Above Input) */}
      {showSmartReplies && isCaregiver && (
          <div className="absolute bottom-[80px] left-0 right-0 z-50 flex items-center justify-center gap-2 px-4 pointer-events-none">
              <div className="pointer-events-auto flex gap-2 overflow-x-auto no-scrollbar pb-1 px-1 snap-x max-w-full">
                  {[
                      { text: "Yes, please 🥛", type: 'text' },
                      { text: "No, I'm good", type: 'text' },
                      { text: "Call me 📞", type: 'text' },
                      { text: "Share Status ✅", type: 'health-snapshot' }
                  ].map((chip, i) => (
                      <button 
                        key={i}
                        onClick={() => handleSend(chip.text, chip.type as any)}
                        className="bg-white/60 backdrop-blur-md border border-white/50 text-gray-800 font-medium text-[15px] px-4 py-2 rounded-full shadow-lg active:scale-95 transition-transform whitespace-nowrap snap-center"
                      >
                          {chip.text}
                      </button>
                  ))}
              </div>
          </div>
      )}

      {/* 2. SMART STACK WIDGETS (Replaces Text Chips) */}
      {isAI && localMessages.length <= 1 && !simpleMode && (
          <div className="fixed bottom-24 left-0 right-0 px-6 flex gap-4 overflow-x-auto no-scrollbar z-30 py-6 snap-x snap-mandatory pb-8">
              
              {/* Widget 1: Contact Card (Primary) */}
              <button 
                onClick={() => handleSend("Call Sarah")}
                className="snap-center shrink-0 w-[85%] bg-white/70 backdrop-blur-xl border border-white/50 rounded-[28px] p-5 shadow-xl flex items-center gap-4 active:scale-95 transition-transform"
              >
                  <div className="w-14 h-14 rounded-full bg-gray-200 flex items-center justify-center text-gray-500 text-xl font-bold shadow-inner">S</div>
                  <div className="text-left flex-1">
                      <p className="text-[17px] font-bold text-gray-900 leading-tight">Call Sarah</p>
                      <p className="text-[13px] text-gray-500 leading-tight mt-0.5">Daughter • Online</p>
                  </div>
                  <div className="w-10 h-10 rounded-full bg-green-500 flex items-center justify-center text-white shadow-lg shadow-green-200">
                      <Phone className="w-5 h-5 fill-current" />
                  </div>
              </button>

              {/* Widget 2: Mood Card */}
              <button 
                onClick={() => handleSend("I feel anxious")}
                className="snap-center shrink-0 w-[45%] bg-white/70 backdrop-blur-xl border border-white/50 rounded-[28px] p-5 shadow-xl flex flex-col justify-between active:scale-95 transition-transform h-28"
              >
                  <div className="w-10 h-10 rounded-full bg-blue-100 flex items-center justify-center text-blue-600 mb-2">
                      <CloudRain className="w-6 h-6" />
                  </div>
                  <div className="text-left">
                      <p className="text-[15px] font-bold text-gray-900 leading-tight">Anxious</p>
                      <p className="text-[11px] text-gray-500 leading-tight">Log Mood</p>
                  </div>
              </button>

               {/* Widget 3: Relax */}
               <button 
                onClick={() => handleSend("Help me relax")}
                className="snap-center shrink-0 w-[45%] bg-white/70 backdrop-blur-xl border border-white/50 rounded-[28px] p-5 shadow-xl flex flex-col justify-between active:scale-95 transition-transform h-28"
              >
                  <div className="w-10 h-10 rounded-full bg-purple-100 flex items-center justify-center text-purple-600 mb-2">
                      <Wind className="w-6 h-6" />
                  </div>
                  <div className="text-left">
                      <p className="text-[15px] font-bold text-gray-900 leading-tight">Relax</p>
                      <p className="text-[11px] text-gray-500 leading-tight">Breathing</p>
                  </div>
              </button>
          </div>
      )}

      {/* Input Area */}
      <InputBar 
        onSend={(text) => handleSend(text)} 
        isThinking={isTyping}
        onHeartTrigger={triggerHeartEffect}
        type={
            session.type === ViewType.AI_COMPANION ? 'ai' 
            : session.type === ViewType.DOCTOR ? 'doctor' 
            : session.type === ViewType.SYSTEM ? 'system' 
            : session.type === ViewType.PEACE_OF_MIND ? 'peace'
            : 'caregiver'
        }
        isOnline={session.isOnline} // Pass online status for Doctor view
        placeholder={
            session.type === ViewType.DOCTOR 
            ? "Message Dr. Emily..." 
            : isCommunity
                ? "Message (shared with everyone)..."
                : isCaregiver 
                    ? "iMessage" 
                    : undefined 
        }
      />

      {/* Safety Escalation Suggestion (Conditional) - RENDERED AFTER INPUTBAR WITH HIGHER Z-INDEX */}
      {(showEscalation && !simpleMode) && (
          <div className={`mx-4 mb-2 bg-white rounded-2xl p-4 shadow-xl border border-red-100 animate-in slide-in-from-bottom-4 duration-500 z-[60]
              ${isAI ? 'fixed bottom-32 left-4 right-4' : 'relative'}
          `}>
              <div className="flex gap-3">
                   <div className="w-10 h-10 bg-red-100 rounded-full flex items-center justify-center text-red-600 shrink-0">
                       <Heart className="w-5 h-5 fill-current" />
                   </div>
                   <div>
                       <p className="font-semibold text-gray-900 text-sm">
                           {isPeaceOfMind ? "It sounds like you might need support." : "Would you like me to tell Sarah?"}
                       </p>
                       <div className="flex gap-3 mt-3">
                           <button className="px-4 py-2 bg-red-600 text-white text-xs font-bold rounded-full shadow-sm active:scale-95 transition-transform" onClick={() => setShowEscalation(false)}>Yes, tell Sarah</button>
                           <button className="px-4 py-2 bg-gray-100 text-gray-600 text-xs font-bold rounded-full active:scale-95 transition-transform" onClick={() => setShowEscalation(false)}>Not right now</button>
                       </div>
                   </div>
              </div>
          </div>
      )}
      
      {/* Footer Text (Non-AI modes) */}
      {!simpleMode && !isAI && !isDoctor && (
          <div className={`text-center pb-1 pt-1 opacity-70 safe-area-bottom ${isCaregiver ? 'bg-[#F2F1ED]' : 'bg-white'}`}>
              <p className="text-[10px] text-gray-400 font-medium">
                  Tap <button onClick={onSOS} className="font-bold text-red-500 underline decoration-red-200 underline-offset-2">SOS</button> for emergencies
              </p>
          </div>
      )}
    </div>
  );
};