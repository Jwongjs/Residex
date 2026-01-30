
import React, { useState } from 'react';
import { Search, Sparkles, Volume2, Snowflake, Trash2, ShieldCheck, ChevronRight } from 'lucide-react';

export const RulebookPage: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');

  const rules = [
    { id: 1, title: 'Quiet Hours Protocol', icon: <Volume2 size={18} />, desc: 'Strict silence between 11:00 PM - 7:00 AM.', category: 'NOISE' },
    { id: 2, title: 'Climate Control', icon: <Snowflake size={18} />, desc: 'AC must be OFF when unit is vacant.', category: 'ENERGY' },
    { id: 3, title: 'Refuse Disposal', icon: <Trash2 size={18} />, desc: 'Halal/Non-Halal separation required in shared fridge.', category: 'KITCHEN' },
    { id: 4, title: 'Guest Verification', icon: <ShieldCheck size={18} />, desc: 'All overnight guests must register via App.', category: 'SECURITY' },
  ];

  return (
    <div className="flex flex-col h-full relative overflow-hidden bg-[#02040a]">
      {/* Sapphire/Amethyst Gradient Background */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/40 via-[#02040a] to-[#02040a] pointer-events-none"></div>
      
      {/* Header */}
      <div className="pt-8 pb-4 px-6 sticky top-0 z-30 backdrop-blur-sm">
        <div className="flex items-center gap-3 mb-4">
            <div className="h-10 w-10 rounded-xl bg-blue-500/10 text-blue-300 flex items-center justify-center border border-blue-500/20 shadow-lg shadow-blue-900/10">
                <Sparkles size={20} />
            </div>
            <div>
                <h1 className="text-white font-black text-xl tracking-tight">House Protocol</h1>
                <p className="text-indigo-300 text-[10px] font-black uppercase tracking-widest">AI Rulebook</p>
            </div>
        </div>

        {/* Search Bar - Metallic Highlight */}
        <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-purple-600 rounded-2xl opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
            <div className="relative flex items-center bg-[#050510]/80 border border-indigo-500/30 rounded-2xl p-3 shadow-xl backdrop-blur-md">
                <Search size={18} className="text-indigo-400 ml-2" />
                <input 
                    type="text" 
                    placeholder="Search protocols..." 
                    className="bg-transparent border-none focus:outline-none text-white w-full ml-3 placeholder-slate-500 text-sm font-bold"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                />
            </div>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar p-6 space-y-4 relative z-10 pb-32">
         {rules.map((rule, index) => (
             <div key={rule.id} className="relative group">
                 <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-900 to-purple-900 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                 <button 
                    className="relative w-full bg-[#0a0a15]/60 border border-indigo-500/20 rounded-[2rem] p-5 flex items-center justify-between hover:bg-[#0a0a15]/80 transition-all active:scale-[0.98] backdrop-blur-md"
                    style={{ animationDelay: `${index * 100}ms` }}
                 >
                     <div className="flex items-center gap-4 text-left">
                         <div className="h-12 w-12 rounded-2xl bg-indigo-900/20 text-indigo-300 border border-indigo-500/20 flex items-center justify-center shadow-lg group-hover:scale-110 transition-transform duration-300">
                             {rule.icon}
                         </div>
                         <div>
                             <h3 className="text-white font-bold text-sm mb-1 group-hover:text-blue-300 transition-colors">{rule.title}</h3>
                             <p className="text-slate-400 text-xs font-medium leading-snug max-w-[200px]">{rule.desc}</p>
                         </div>
                     </div>
                     <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-indigo-300 group-hover:bg-indigo-500/10 transition-all">
                        <ChevronRight size={16} />
                     </div>
                 </button>
             </div>
         ))}
      </div>
    </div>
  );
};
