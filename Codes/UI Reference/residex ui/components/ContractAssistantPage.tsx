
import React, { useState, useEffect, useRef } from 'react';
import { FileText, Bot, Send, Calendar, DollarSign, ArrowLeft, ChevronDown, Check, Building2, User, X, ChevronRight, Users } from 'lucide-react';

interface ContractAssistantPageProps {
  onBack?: () => void;
}

interface TenantProfile {
  id: string;
  name: string;
  rent: string;
  status: 'Active' | 'Moving Out';
}

interface PropertyContract {
  id: string;
  property: string;
  unit: string;
  expiry: string;
  color: string;
  tenants: TenantProfile[];
}

const MOCK_PROPERTIES: PropertyContract[] = [
  { 
      id: 'p1', 
      unit: 'Unit 4-2', 
      property: 'Verdi Eco-Dominium', 
      expiry: '31 Dec 2025', 
      color: 'bg-blue-600',
      tenants: [
          { id: 't1', name: 'Ali Rahman', rent: 'RM 900', status: 'Active' },
          { id: 't2', name: 'Raj Kumar', rent: 'RM 900', status: 'Active' }
      ]
  },
  { 
      id: 'p2', 
      unit: 'Block B-12', 
      property: 'The Grand Subang', 
      expiry: '15 Aug 2026', 
      color: 'bg-purple-600',
      tenants: [
          { id: 't3', name: 'Sarah Tan', rent: 'RM 1,500', status: 'Active' }
      ]
  },
];

export const ContractAssistantPage: React.FC<ContractAssistantPageProps> = ({ onBack }) => {
  // Context State
  const [activeProperty, setActiveProperty] = useState<PropertyContract>(MOCK_PROPERTIES[0]);
  const [activeTenant, setActiveTenant] = useState<TenantProfile>(MOCK_PROPERTIES[0].tenants[0]);
  
  // UI State
  const [showSelector, setShowSelector] = useState(false);
  const [selectorView, setSelectorView] = useState<'PROPERTIES' | 'TENANTS'>('PROPERTIES');
  const [tempSelectedProperty, setTempSelectedProperty] = useState<PropertyContract | null>(null);

  const [messages, setMessages] = useState([
    { id: 1, sender: 'AI', text: `Hello. I have indexed the tenancy agreement for ${MOCK_PROPERTIES[0].property}. Currently analyzing context for tenant: ${MOCK_PROPERTIES[0].tenants[0].name}.` }
  ]);
  const [input, setInput] = useState('');
  const messagesEndRef = useRef<HTMLDivElement>(null);

  const scrollToBottom = () => {
    messagesEndRef.current?.scrollIntoView({ behavior: "smooth" });
  };

  useEffect(() => {
    scrollToBottom();
  }, [messages]);

  const handleSend = () => {
    if (!input.trim()) return;
    
    setMessages(prev => [...prev, { id: Date.now(), sender: 'USER', text: input }]);
    setInput('');
    
    setTimeout(() => {
        setMessages(prev => [...prev, { 
            id: Date.now() + 1, 
            sender: 'AI', 
            text: `Regarding ${activeTenant.name}'s lease at ${activeProperty.property}: The clause regarding early termination requires a 2-month notice period.` 
        }]);
    }, 1000);
  };

  const handlePropertyClick = (property: PropertyContract) => {
      setTempSelectedProperty(property);
      setSelectorView('TENANTS');
  };

  const handleTenantSelect = (tenant: TenantProfile) => {
      if (tempSelectedProperty) {
          setActiveProperty(tempSelectedProperty);
          setActiveTenant(tenant);
          setShowSelector(false);
          setSelectorView('PROPERTIES'); // Reset for next time
          setTempSelectedProperty(null);

          setMessages(prev => [...prev, {
              id: Date.now(),
              sender: 'AI',
              text: `Context switched. Now analyzing lease data for ${tenant.name} at ${tempSelectedProperty.property}.`
          }]);
      }
  };

  const closeSelector = () => {
      setShowSelector(false);
      setSelectorView('PROPERTIES');
      setTempSelectedProperty(null);
  };

  return (
    <div className="flex flex-col h-full relative overflow-hidden bg-[#02040a]">
      {/* Sapphire/Amethyst Gradient */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-purple-900/40 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      {/* Header */}
      <div className="pt-8 pb-4 px-6 sticky top-0 z-30 backdrop-blur-sm bg-[#02040a]/20">
        <div className="flex items-center gap-3 mb-1">
            {onBack && (
              <button onClick={onBack} className="p-2 bg-purple-500/10 rounded-full text-purple-400 active:scale-90 transition-transform mr-1">
                <ArrowLeft size={20}/>
              </button>
            )}
            <div className="h-10 w-10 rounded-xl bg-purple-500/20 text-purple-300 flex items-center justify-center border border-purple-500/30 shadow-lg shadow-purple-900/20">
                <FileText size={20} />
            </div>
            <div>
                <h1 className="text-white font-black text-xl tracking-tight">Lease Sentinel</h1>
                <p className="text-purple-400 text-[10px] font-black uppercase tracking-widest">AI Contract Overview</p>
            </div>
        </div>
      </div>

      {/* Messages Area */}
      <div className="flex-1 overflow-y-auto no-scrollbar p-6 pb-48 relative z-10">
         
         {/* Interactive Summary Widget */}
         <div className="relative group mb-6 z-20">
             <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-purple-600 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
             <button 
                onClick={() => setShowSelector(true)}
                className="relative w-full text-left bg-[#0a0a15]/80 border border-indigo-500/30 rounded-[2rem] p-6 backdrop-blur-md shadow-xl hover:bg-[#0a0a15] transition-all group/card"
             >
                 <div className="flex justify-between items-start mb-6">
                     <div>
                         <div className="flex items-center gap-2 mb-1">
                            <span className="text-indigo-300 text-[10px] font-black uppercase tracking-widest">{activeProperty.unit}</span>
                            <ChevronDown size={14} className="text-indigo-400 animate-bounce mt-0.5" />
                         </div>
                         <h3 className="text-white font-bold text-lg leading-tight">{activeProperty.property}</h3>
                         <div className="flex items-center gap-1.5 mt-1">
                             <User size={12} className="text-slate-400" />
                             <span className="text-slate-400 text-xs font-medium">Analyzing: <span className="text-white font-bold">{activeTenant.name}</span></span>
                         </div>
                     </div>
                     <div className="bg-blue-500/20 px-2 py-1 rounded text-blue-300 text-[10px] font-bold uppercase border border-blue-500/30 shadow-sm">
                         {activeTenant.status}
                     </div>
                 </div>
                 
                 <div className="grid grid-cols-2 gap-4">
                     <div className="bg-white/5 p-3 rounded-xl border border-white/5 group-hover/card:border-indigo-500/30 transition-colors">
                         <div className="flex items-center gap-2 text-slate-400 mb-1">
                             <DollarSign size={12} className="text-indigo-400" />
                             <span className="text-[10px] font-bold uppercase">Rent Share</span>
                         </div>
                         <span className="text-white font-mono font-bold">{activeTenant.rent}</span>
                     </div>
                     <div className="bg-white/5 p-3 rounded-xl border border-white/5 group-hover/card:border-indigo-500/30 transition-colors">
                         <div className="flex items-center gap-2 text-slate-400 mb-1">
                             <Calendar size={12} className="text-indigo-400" />
                             <span className="text-[10px] font-bold uppercase">Expiry</span>
                         </div>
                         <span className="text-white font-mono font-bold">{activeProperty.expiry}</span>
                     </div>
                 </div>
             </button>
         </div>

         {/* Chat Interface */}
         <div className="space-y-4">
             {messages.map(msg => (
                 <div key={msg.id} className={`flex gap-3 ${msg.sender === 'USER' ? 'flex-row-reverse' : ''} animate-in slide-in-from-bottom-2`}>
                     <div className={`h-8 w-8 rounded-full flex items-center justify-center flex-shrink-0 ${msg.sender === 'AI' ? 'bg-indigo-500/30 text-indigo-300 border border-indigo-500/20' : 'bg-slate-700 text-white'}`}>
                         {msg.sender === 'AI' ? <Bot size={16} /> : <span className="text-[10px] font-bold">ME</span>}
                     </div>
                     <div className={`p-4 rounded-2xl max-w-[80%] text-sm leading-relaxed shadow-lg relative ${
                         msg.sender === 'AI' 
                         ? 'bg-slate-900/80 text-slate-200 rounded-tl-none border border-white/10' 
                         : 'bg-blue-600 text-white rounded-tr-none shadow-blue-900/30 border border-blue-500/20'
                     }`}>
                         <span className="relative z-10">{msg.text}</span>
                     </div>
                 </div>
             ))}
             <div ref={messagesEndRef} />
         </div>
      </div>

      {/* Input Area */}
      <div className="absolute bottom-[90px] left-0 right-0 z-30 px-4">
          <div className="max-w-md mx-auto relative group">
               <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-purple-500 rounded-3xl opacity-30 group-hover:opacity-60 blur transition duration-500"></div>
               <div className="relative flex items-center bg-[#0a0a0a] border border-indigo-500/30 rounded-3xl p-2 pl-5 shadow-2xl backdrop-blur-xl">
                   <input 
                      type="text" 
                      value={input}
                      onChange={(e) => setInput(e.target.value)}
                      onKeyDown={(e) => e.key === 'Enter' && handleSend()}
                      placeholder={`Ask about ${activeTenant.name}'s lease...`} 
                      className="bg-transparent border-none focus:outline-none text-white w-full placeholder-slate-400 text-sm font-medium py-2.5"
                   />
                   <button 
                      onClick={handleSend}
                      disabled={!input.trim()}
                      className="p-3 bg-blue-600 text-white rounded-2xl hover:bg-blue-500 transition-colors shadow-lg active:scale-90 disabled:opacity-50 disabled:cursor-not-allowed"
                   >
                       <Send size={18} />
                   </button>
               </div>
          </div>
      </div>

      {/* Context Selector Modal */}
      {showSelector && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
              <div className="w-full max-w-md bg-[#0f172a] sm:rounded-3xl rounded-t-3xl p-6 border border-white/10 shadow-2xl animate-ios-slide-up duration-500 max-h-[80vh] flex flex-col">
                  
                  {/* Modal Header */}
                  <div className="flex justify-between items-center mb-6">
                      <div className="flex items-center gap-2">
                          {selectorView === 'TENANTS' && (
                              <button onClick={() => setSelectorView('PROPERTIES')} className="p-1 rounded-full bg-white/5 hover:bg-white/10 mr-1">
                                  <ArrowLeft size={16} className="text-slate-400" />
                              </button>
                          )}
                          <div>
                            <h2 className="text-white font-black text-xl">
                                {selectorView === 'PROPERTIES' ? 'Select Property' : 'Select Tenant'}
                            </h2>
                            <p className="text-slate-400 text-xs mt-1">
                                {selectorView === 'PROPERTIES' ? 'Choose a property to analyze' : `Who in ${tempSelectedProperty?.unit}?`}
                            </p>
                          </div>
                      </div>
                      <button onClick={closeSelector} className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors">
                          <X size={20} />
                      </button>
                  </div>

                  {/* Property List View */}
                  {selectorView === 'PROPERTIES' && (
                      <div className="space-y-3 overflow-y-auto no-scrollbar pb-6">
                          {MOCK_PROPERTIES.map((prop) => {
                              const isSelected = activeProperty.id === prop.id;
                              return (
                                  <button
                                      key={prop.id}
                                      onClick={() => handlePropertyClick(prop)}
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
                                              <div className="text-white font-bold text-sm mb-0.5">{prop.property}</div>
                                              <div className="text-slate-400 text-xs font-medium flex items-center gap-1.5">
                                                  <span>{prop.unit}</span>
                                                  <span className="w-1 h-1 rounded-full bg-slate-600"></span>
                                                  <span className="flex items-center gap-1"><Users size={10} /> {prop.tenants.length}</span>
                                              </div>
                                          </div>
                                      </div>
                                      <ChevronRight size={16} className="text-slate-500 group-hover:text-white" />
                                  </button>
                              );
                          })}
                      </div>
                  )}

                  {/* Tenant List View */}
                  {selectorView === 'TENANTS' && tempSelectedProperty && (
                      <div className="space-y-3 overflow-y-auto no-scrollbar pb-6">
                          {tempSelectedProperty.tenants.map((tenant) => {
                              const isActive = activeTenant.id === tenant.id && activeProperty.id === tempSelectedProperty.id;
                              return (
                                  <button
                                      key={tenant.id}
                                      onClick={() => handleTenantSelect(tenant)}
                                      className={`w-full p-4 rounded-2xl border flex items-center justify-between transition-all group active:scale-[0.98] ${
                                          isActive 
                                            ? 'bg-indigo-900/30 border-indigo-500/50 shadow-lg' 
                                            : 'bg-slate-800/40 border-white/5 hover:bg-slate-800/60 hover:border-white/10'
                                      }`}
                                  >
                                      <div className="flex items-center gap-4 text-left">
                                          <div className={`h-12 w-12 rounded-full flex items-center justify-center text-white font-bold shadow-lg bg-slate-700 border border-white/10`}>
                                              {tenant.name.substring(0,2).toUpperCase()}
                                          </div>
                                          <div>
                                              <div className="text-white font-bold text-sm mb-0.5">{tenant.name}</div>
                                              <div className="text-slate-400 text-xs font-medium flex items-center gap-1.5">
                                                  <span>{tenant.rent}</span>
                                                  <span className="w-1 h-1 rounded-full bg-slate-600"></span>
                                                  <span className={tenant.status === 'Active' ? 'text-emerald-400' : 'text-amber-400'}>{tenant.status}</span>
                                              </div>
                                          </div>
                                      </div>
                                      {isActive && (
                                          <div className="h-8 w-8 rounded-full bg-indigo-500 flex items-center justify-center text-white shadow-lg animate-in zoom-in">
                                              <Check size={16} strokeWidth={3} />
                                          </div>
                                      )}
                                  </button>
                              );
                          })}
                      </div>
                  )}
              </div>
          </div>
      )}

    </div>
  );
};
