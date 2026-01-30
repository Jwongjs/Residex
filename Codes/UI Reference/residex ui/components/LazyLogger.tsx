
import React, { useState, useRef, useEffect } from 'react';
import { ArrowLeft, FileText, Upload, Sparkles, Send, Loader2, FileCheck, Building2, ChevronDown, Check, X } from 'lucide-react';

interface Property {
  id: string;
  name: string;
  unit: string;
  color: string;
}

const MOCK_PROPERTIES: Property[] = [
  { id: 'p1', name: 'Verdi Eco-Dominium', unit: 'Unit 4-2', color: 'bg-blue-600' },
  { id: 'p2', name: 'The Grand Subang', unit: 'Block B-12', color: 'bg-purple-600' },
  { id: 'p3', name: 'Arcuz Kelana Jaya', unit: 'Unit 08-01', color: 'bg-emerald-600' },
];

export const LazyLogger: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  const [activeProperty, setActiveProperty] = useState<Property>(MOCK_PROPERTIES[0]);
  const [showPropertySelector, setShowPropertySelector] = useState(false);

  const [messages, setMessages] = useState([
    { id: 1, sender: 'AI', text: `Lazy Logger system online. I have indexed documents for ${MOCK_PROPERTIES[0].name}. What do you need to find?` }
  ]);
  const [input, setInput] = useState('');
  const [isUploading, setIsUploading] = useState(false);
  const [showUploadSuccess, setShowUploadSuccess] = useState(false);
  const messagesEndRef = useRef<HTMLDivElement>(null);
  const fileInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  }, [messages]);

  const handleSend = () => {
    if (!input.trim()) return;
    
    setMessages(prev => [...prev, { id: Date.now(), sender: 'USER', text: input }]);
    const userQuery = input.toLowerCase();
    setInput('');
    
    // Simulating RAG Response based on active property
    setTimeout(() => {
        let response = "I couldn't find that in your documents. Can you be more specific?";
        
        if (userQuery.includes('ac') || userQuery.includes('aircon') || userQuery.includes('warranty')) {
            response = `Found in 'Acson_Warranty_${activeProperty.unit.replace(/\s/g, '')}.pdf': The warranty for the Master Bedroom AC in ${activeProperty.name} expires on **15 March 2026**. Coverage includes compressor and gas refill.`;
        } else if (userQuery.includes('bill') || userQuery.includes('water') || userQuery.includes('tnb')) {
            response = `Reference 'TNB_Sept2025.pdf' for ${activeProperty.unit}: The last electricity bill was **RM 154.20** (Due 28 Sept). It was 12% higher than August.`;
        } else if (userQuery.includes('insurance') || userQuery.includes('policy')) {
            response = `According to 'Allianz_Home_Policy.pdf', fire insurance for ${activeProperty.name} covers up to RM 500,000. Next premium payment is due **01 Jan 2026**.`;
        }

        setMessages(prev => [...prev, { 
            id: Date.now() + 1, 
            sender: 'AI', 
            text: response,
            citation: true
        }]);
    }, 1500);
  };

  const handleFileUpload = (e: React.ChangeEvent<HTMLInputElement>) => {
      const file = e.target.files?.[0];
      if (!file) return;

      setIsUploading(true);
      
      // Simulate indexing process
      setTimeout(() => {
          setIsUploading(false);
          setShowUploadSuccess(true);
          setMessages(prev => [...prev, {
              id: Date.now(),
              sender: 'AI',
              text: `Successfully indexed ${file.name} to ${activeProperty.name} database.`
          }]);
          
          setTimeout(() => setShowUploadSuccess(false), 3000);
      }, 2000);
  };

  const switchProperty = (prop: Property) => {
      setActiveProperty(prop);
      setShowPropertySelector(false);
      setMessages(prev => [...prev, {
          id: Date.now(),
          sender: 'AI',
          text: `Context switched to ${prop.name} (${prop.unit}). Document search is now scoped to this property.`
      }]);
  };

  return (
    <div className="flex flex-col h-full bg-[#02040a] relative overflow-hidden">
      {/* Blue/Indigo Glow */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/40 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      {/* Header */}
      <div className="p-6 flex items-center gap-4 border-b border-indigo-500/10 sticky top-0 bg-[#02040a]/90 backdrop-blur-md z-20">
        <button onClick={onBack} className="p-2 bg-indigo-500/10 rounded-full text-indigo-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <div className="flex-1">
            <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Lazy Logger</h1>
            <p className="text-indigo-400/60 text-[10px] font-black uppercase tracking-widest">AI Document Indexer</p>
        </div>
        <button 
            onClick={() => fileInputRef.current?.click()}
            className="p-2.5 bg-indigo-600 rounded-xl text-white shadow-lg shadow-indigo-900/20 active:scale-95 transition-all"
        >
            <Upload size={18} />
        </button>
      </div>

      <input type="file" ref={fileInputRef} className="hidden" accept=".pdf,.jpg,.png,.doc" onChange={handleFileUpload} />

      {/* File Upload Overlay Animation */}
      {isUploading && (
          <div className="absolute inset-0 z-50 bg-black/80 backdrop-blur-sm flex flex-col items-center justify-center animate-in fade-in">
              <div className="relative">
                  <div className="absolute inset-0 bg-indigo-500 blur-2xl opacity-20 animate-pulse"></div>
                  <FileText size={60} className="text-indigo-400 animate-bounce" />
              </div>
              <h2 className="text-white font-bold mt-6 text-lg">Indexing Document</h2>
              <div className="flex items-center gap-2 text-indigo-400 text-xs font-mono mt-2">
                  <Loader2 size={12} className="animate-spin" />
                  <span>EXTRACTING VECTOR EMBEDDINGS...</span>
              </div>
          </div>
      )}

      {/* Success Toast */}
      {showUploadSuccess && (
          <div className="absolute top-24 left-1/2 -translate-x-1/2 z-40 bg-emerald-900/90 text-emerald-100 px-4 py-2 rounded-xl flex items-center gap-2 border border-emerald-500/30 shadow-xl animate-in slide-in-from-top-4 fade-in">
              <FileCheck size={16} />
              <span className="text-xs font-bold">Document Secured</span>
          </div>
      )}

      {/* Chat Area */}
      <div className="flex-1 overflow-y-auto no-scrollbar p-6 pb-32 relative z-10">
         
         {/* Context Switcher Widget */}
         <div className="mb-6 relative group z-10">
             <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-[1.5rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
             <button 
                onClick={() => setShowPropertySelector(true)}
                className="relative w-full text-left bg-[#0a0a15]/80 border border-indigo-500/20 rounded-[1.5rem] p-4 flex items-center justify-between backdrop-blur-md hover:bg-[#0a0a15] transition-all active:scale-[0.98]"
             >
                 <div className="flex items-center gap-3">
                     <div className={`h-10 w-10 rounded-xl flex items-center justify-center text-white shadow-lg ${activeProperty.color}`}>
                         <Building2 size={18} />
                     </div>
                     <div>
                         <span className="text-indigo-300 text-[9px] font-black uppercase tracking-widest block mb-0.5">Active Property</span>
                         <h3 className="text-white font-bold text-sm leading-none">{activeProperty.name}</h3>
                         <span className="text-slate-500 text-[10px] font-medium">{activeProperty.unit}</span>
                     </div>
                 </div>
                 <ChevronDown size={16} className="text-indigo-400" />
             </button>
         </div>

         <div className="space-y-4">
            {messages.map(msg => (
                <div key={msg.id} className={`flex gap-3 ${msg.sender === 'USER' ? 'flex-row-reverse' : ''} animate-in slide-in-from-bottom-2`}>
                    <div className={`h-8 w-8 rounded-full flex items-center justify-center flex-shrink-0 ${msg.sender === 'AI' ? 'bg-indigo-500/20 text-indigo-400 border border-indigo-500/30' : 'bg-slate-700 text-white'}`}>
                        {msg.sender === 'AI' ? <Sparkles size={16} /> : <span className="text-[10px] font-bold">ME</span>}
                    </div>
                    <div className={`p-4 rounded-2xl max-w-[85%] text-sm leading-relaxed shadow-lg relative ${
                        msg.sender === 'AI' 
                        ? 'bg-[#0a0a15] border border-white/10 text-slate-200 rounded-tl-none' 
                        : 'bg-indigo-600 text-white rounded-tr-none shadow-indigo-900/20'
                    }`}>
                        <span className="relative z-10">{msg.text}</span>
                        {msg.citation && (
                            <div className="mt-3 pt-2 border-t border-white/10 flex items-center gap-1.5 text-[10px] text-indigo-300 font-bold uppercase tracking-wider">
                                <FileText size={10} /> Source Verified
                            </div>
                        )}
                    </div>
                </div>
            ))}
            <div ref={messagesEndRef} />
         </div>
      </div>

      {/* Input */}
      <div className="absolute bottom-0 left-0 right-0 p-4 bg-gradient-to-t from-black via-black to-transparent z-20">
          <div className="bg-[#0f172a] border border-white/10 rounded-[1.5rem] p-1.5 pl-4 flex items-center shadow-2xl">
              <input 
                  type="text" 
                  value={input}
                  onChange={(e) => setInput(e.target.value)}
                  onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                  placeholder={`Search ${activeProperty.name}...`} 
                  className="flex-1 bg-transparent text-white text-sm placeholder-slate-500 focus:outline-none py-2"
              />
              <button 
                  onClick={handleSend}
                  disabled={!input.trim()}
                  className="p-3 bg-indigo-600 rounded-2xl text-white hover:bg-indigo-500 transition-colors disabled:opacity-50 active:scale-95"
              >
                  <Send size={18} />
              </button>
          </div>
      </div>

      {/* Property Selector Modal */}
      {showPropertySelector && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
              <div className="w-full max-w-md bg-[#0f172a] sm:rounded-3xl rounded-t-3xl p-6 border border-white/10 shadow-2xl animate-ios-slide-up duration-500 max-h-[80vh] flex flex-col">
                  
                  <div className="flex justify-between items-center mb-6">
                      <div>
                          <h2 className="text-white font-black text-xl">Select Context</h2>
                          <p className="text-slate-400 text-xs mt-1">Choose property to query</p>
                      </div>
                      <button onClick={() => setShowPropertySelector(false)} className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors">
                          <X size={20} />
                      </button>
                  </div>

                  <div className="space-y-3 overflow-y-auto no-scrollbar pb-6">
                      {MOCK_PROPERTIES.map((prop) => {
                          const isSelected = activeProperty.id === prop.id;
                          return (
                              <button
                                  key={prop.id}
                                  onClick={() => switchProperty(prop)}
                                  className={`w-full p-4 rounded-2xl border flex items-center justify-between transition-all group active:scale-[0.98] ${
                                      isSelected 
                                        ? 'bg-indigo-900/30 border-indigo-500/50 shadow-lg shadow-indigo-900/10' 
                                        : 'bg-slate-800/40 border-white/5 hover:bg-slate-800/60 hover:border-white/10'
                                  }`}
                              >
                                  <div className="flex items-center gap-4 text-left">
                                      <div className={`h-12 w-12 rounded-xl flex items-center justify-center text-white shadow-lg ${prop.color}`}>
                                          <Building2 size={20} />
                                      </div>
                                      <div>
                                          <div className="text-white font-bold text-sm mb-0.5">{prop.name}</div>
                                          <div className="text-slate-400 text-xs font-medium">{prop.unit}</div>
                                      </div>
                                  </div>
                                  {isSelected && (
                                      <div className="h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center text-white shadow-lg animate-in zoom-in">
                                          <Check size={16} strokeWidth={3} />
                                      </div>
                                  )}
                              </button>
                          );
                      })}
                  </div>
              </div>
          </div>
      )}

    </div>
  );
};
