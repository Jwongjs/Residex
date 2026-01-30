
import React, { useState, useEffect, useRef } from 'react';
import { ArrowLeft, Mic, Send, Paperclip, Camera, ShieldCheck, FileText, Wrench, Users, Scale, BookOpen, X, Play } from 'lucide-react';
import { User, Bill } from '../types';
import { Logo } from './Logo';
import { analyzeReceipt } from '../services/geminiService'; // Assuming this exists or using mock

interface RexInterfaceProps {
  user: User;
  onClose: () => void;
  initialContext?: string; // e.g., "Fiscal Analyst", "Maintenance"
}

interface Message {
  id: string;
  sender: 'REX' | 'USER';
  text: string;
  type?: 'TEXT' | 'ACTION_REQ' | 'SUGGESTION' | 'WARNING';
  attachment?: string;
}

export const RexInterface: React.FC<RexInterfaceProps> = ({ user, onClose, initialContext }) => {
  const [messages, setMessages] = useState<Message[]>([]);
  const [input, setInput] = useState('');
  const [isListening, setIsListening] = useState(false);
  const [isThinking, setIsThinking] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  // Initialize Rex
  useEffect(() => {
    const startMsg = getInitialGreeting(initialContext);
    setMessages([
        { id: '1', sender: 'REX', text: startMsg, type: 'TEXT' }
    ]);
  }, [initialContext]);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: 'smooth' });
  }, [messages]);

  const getInitialGreeting = (ctx?: string) => {
      switch(ctx) {
          case 'Fiscal Analyst': return "I'm in Fiscal Analyst mode. I see the rent is due in 3 days. Would you like to settle the RM 600 share now?";
          case 'Harmony Engine': return "Harmony Engine online. According to the rotation, it is your turn for trash disposal. Would you like to upload verification?";
          case 'Contract Guardian': return "Lease Sentinel active. Upload your tenancy agreement PDF, and I'll scan for predatory clauses.";
          case 'Maintenance Advisor': return "Maintenance Advisor here. Describe the issue (e.g., 'leaking sink') or snap a photo.";
          default: return `Hello ${user.name.split(' ')[0]}. I'm Rex. Your Sync Score is stable. How can I assist you today?`;
      }
  };

  const handleSend = async () => {
    if (!input.trim()) return;
    
    const userMsg: Message = { id: Date.now().toString(), sender: 'USER', text: input };
    setMessages(prev => [...prev, userMsg]);
    setInput('');
    setIsThinking(true);

    // Simulate AI Latency & Logic
    setTimeout(() => {
        setIsThinking(false);
        const response = processLogic(input);
        setMessages(prev => [...prev, response]);
    }, 1500);
  };

  // Mock Logic Engine (Replacing backend)
  const processLogic = (query: string): Message => {
      const q = query.toLowerCase();
      
      if (q.includes('bill') || q.includes('pay') || q.includes('owe')) {
          return {
              id: Date.now().toString(),
              sender: 'REX',
              text: "To process this bill split, I require proof of transaction. Please upload the receipt or PDF for verification.",
              type: 'ACTION_REQ'
          };
      }
      if (q.includes('drill') || q.includes('shelf') || q.includes('paint')) {
          return {
              id: Date.now().toString(),
              sender: 'REX',
              text: "Checking Digital Rulebook... Clause 9 prohibits permanent wall alterations. I suggest using command strips instead to protect your deposit.",
              type: 'WARNING'
          };
      }
      if (q.includes('broke') || q.includes('scratch') || q.includes('damage')) {
          return {
              id: Date.now().toString(),
              sender: 'REX',
              text: "Understood. Please take a clear photo of the damage. I will analyze the material and estimate fair repair costs based on KL market rates.",
              type: 'ACTION_REQ'
          };
      }
      
      return {
          id: Date.now().toString(),
          sender: 'REX',
          text: "I've logged that request. Is there anything else you need to sync?",
          type: 'TEXT'
      };
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (file) {
          const userMsg: Message = { id: Date.now().toString(), sender: 'USER', text: `Uploaded: ${file.name}`, type: 'TEXT' };
          setMessages(prev => [...prev, userMsg]);
          setIsThinking(true);
          
          setTimeout(() => {
              setIsThinking(false);
              setMessages(prev => [...prev, {
                  id: Date.now().toString(),
                  sender: 'REX',
                  text: "Receipt verified. Total: RM 45.50. I have drafted the split for housemates. Shall I notify them?",
                  type: 'SUGGESTION'
              }]);
          }, 2000);
      }
  };

  return (
    <div className="fixed inset-0 z-50 bg-[#020617] flex flex-col animate-in slide-in-from-bottom-full duration-500">
        
        {/* Header - Dynamic Island Style */}
        <div className="pt-6 pb-2 px-4 flex justify-between items-center bg-[#020617]/80 backdrop-blur-md sticky top-0 z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-full bg-slate-800 flex items-center justify-center shadow-[0_0_15px_rgba(59,130,246,0.3)]">
                    <Logo size={24} animate={true} />
                </div>
                <div>
                    <h2 className="text-white font-black text-lg tracking-tight">Rex</h2>
                    <p className="text-indigo-400 text-[10px] font-bold uppercase tracking-widest">{initialContext || "Concierge Mode"}</p>
                </div>
            </div>
            <button onClick={onClose} className="bg-white/5 p-2 rounded-full hover:bg-white/10 transition-colors">
                <X size={20} className="text-slate-400" />
            </button>
        </div>

        {/* Chat Area */}
        <div className="flex-1 overflow-y-auto no-scrollbar p-4 space-y-6 pb-32">
            {messages.map((msg) => (
                <div key={msg.id} className={`flex ${msg.sender === 'USER' ? 'justify-end' : 'justify-start'}`}>
                    <div className={`max-w-[85%] rounded-[1.5rem] p-5 shadow-lg relative ${
                        msg.sender === 'USER' 
                        ? 'bg-blue-600 text-white rounded-tr-none' 
                        : 'bg-[#0f172a] border border-white/10 text-slate-200 rounded-tl-none'
                    }`}>
                        {/* Message Icon for Rex */}
                        {msg.sender === 'REX' && (
                            <div className="absolute -top-3 -left-2 bg-[#020617] p-1 rounded-full border border-white/10">
                                {msg.type === 'WARNING' ? <ShieldCheck size={16} className="text-amber-400" /> : 
                                 msg.type === 'ACTION_REQ' ? <FileText size={16} className="text-rose-400" /> :
                                 <Logo size={16} />}
                            </div>
                        )}
                        
                        <p className="text-sm leading-relaxed font-medium">{msg.text}</p>
                        
                        {/* Interactive Elements for specific types */}
                        {msg.type === 'ACTION_REQ' && (
                            <button 
                                onClick={() => fileInputRef.current?.click()}
                                className="mt-3 w-full py-3 bg-white/5 border border-dashed border-white/20 rounded-xl flex items-center justify-center gap-2 text-xs font-bold text-indigo-300 hover:bg-white/10 transition-all"
                            >
                                <Paperclip size={14} /> Upload Evidence
                            </button>
                        )}
                    </div>
                </div>
            ))}
            
            {/* Thinking Indicator */}
            {isThinking && (
                <div className="flex justify-start">
                    <div className="bg-[#0f172a] border border-white/10 rounded-[1.5rem] rounded-tl-none p-4 flex gap-1 items-center">
                        <div className="w-1.5 h-1.5 bg-indigo-500 rounded-full animate-bounce"></div>
                        <div className="w-1.5 h-1.5 bg-indigo-500 rounded-full animate-bounce delay-100"></div>
                        <div className="w-1.5 h-1.5 bg-indigo-500 rounded-full animate-bounce delay-200"></div>
                    </div>
                </div>
            )}
            
            <div ref={messagesEndRef} />
        </div>

        {/* Input Dock */}
        <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black via-black/90 to-transparent pt-10">
            <div className="relative flex items-center bg-[#1e293b] border border-white/10 rounded-full p-2 pl-5 shadow-2xl">
                <input 
                    type="text" 
                    value={input}
                    onChange={(e) => setInput(e.target.value)}
                    onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                    placeholder="Ask Rex..." 
                    className="flex-1 bg-transparent text-white placeholder-slate-500 focus:outline-none text-sm font-medium"
                />
                
                <div className="flex gap-2">
                    <button 
                        onClick={() => fileInputRef.current?.click()}
                        className="p-2 text-slate-400 hover:text-white transition-colors"
                    >
                        <Camera size={20} />
                    </button>
                    <button 
                        onClick={handleSend}
                        className={`h-10 w-10 rounded-full flex items-center justify-center transition-all ${
                            input.trim() ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/30' : 'bg-slate-700 text-slate-500'
                        }`}
                        disabled={!input.trim()}
                    >
                        <Send size={18} className={input.trim() ? 'ml-0.5' : ''} />
                    </button>
                </div>
            </div>
            <input type="file" ref={fileInputRef} className="hidden" onChange={handleFileUpload} />
        </div>

    </div>
  );
};
