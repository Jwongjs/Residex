
import React from 'react';
import { ArrowLeft, Activity, AlertCircle, Droplets, Zap, Recycle, TrendingUp, CheckCircle2 } from 'lucide-react';

export const PropertyPulseDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#02040a] animate-in slide-in-from-bottom-6 duration-500 relative overflow-hidden">
      {/* Blue/Cyan Ambient Glow */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-blue-900/50 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      <div className="p-6 flex items-center gap-4 border-b border-blue-500/20 sticky top-0 bg-[#02040a]/80 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-blue-500/10 rounded-full text-blue-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Property Pulse</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24 relative z-10">
        
        {/* Main Score Card */}
        <div className="bg-gradient-to-br from-blue-900/40 to-slate-900 border border-blue-500/30 rounded-[2.5rem] p-8 text-center relative overflow-hidden shadow-2xl">
           <div className="relative z-10">
               <div className="inline-block p-4 rounded-full border-4 border-blue-500/30 mb-4 bg-black/40">
                   <span className="text-6xl font-black text-white tracking-tighter">87</span>
               </div>
               <p className="text-cyan-400 text-[10px] font-black uppercase tracking-[0.3em]">Excellent Condition</p>
           </div>
        </div>

        {/* Aggregation Section */}
        <section>
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
                <Activity size={16} className="text-blue-400" /> Vitals Check
            </h3>
            <div className="grid grid-cols-2 gap-3">
                <div className="bg-[#0a0a15] p-4 rounded-2xl border border-white/5">
                    <span className="text-slate-500 text-[10px] font-bold uppercase block mb-1">Bills</span>
                    <span className="text-cyan-400 font-black text-lg flex items-center gap-1">
                        <CheckCircle2 size={14} /> All Paid
                    </span>
                </div>
                <div className="bg-[#0a0a15] p-4 rounded-2xl border border-white/5">
                    <span className="text-slate-500 text-[10px] font-bold uppercase block mb-1">Tickets</span>
                    <span className="text-amber-400 font-black text-lg flex items-center gap-1">
                        <AlertCircle size={14} /> 2 Open
                    </span>
                </div>
                <div className="bg-[#0a0a15] p-4 rounded-2xl border border-white/5">
                    <span className="text-slate-500 text-[10px] font-bold uppercase block mb-1">Chores</span>
                    <span className="text-white font-black text-lg">92% Done</span>
                </div>
                <div className="bg-[#0a0a15] p-4 rounded-2xl border border-white/5">
                    <span className="text-slate-500 text-[10px] font-bold uppercase block mb-1">Rent</span>
                    <span className="text-white font-black text-lg">Due in 5d</span>
                </div>
            </div>
        </section>

        {/* Sustainability & AI Insights */}
        <section>
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
                <TrendingUp size={16} className="text-blue-400" /> AI Insights
            </h3>
            <div className="space-y-3">
                <div className="bg-slate-900/60 border border-blue-500/20 p-4 rounded-2xl flex gap-4 items-start">
                    <div className="p-2 bg-blue-500/10 text-blue-400 rounded-xl">
                        <Droplets size={20} />
                    </div>
                    <div>
                        <h4 className="text-white font-bold text-sm">Water Usage Normal</h4>
                        <p className="text-slate-400 text-xs leading-relaxed mt-1">Usage matches monthly average. No leaks detected.</p>
                    </div>
                </div>

                <div className="bg-slate-900/60 border border-amber-500/20 p-4 rounded-2xl flex gap-4 items-start">
                    <div className="p-2 bg-amber-500/10 text-amber-400 rounded-xl">
                        <Zap size={20} />
                    </div>
                    <div>
                        <h4 className="text-white font-bold text-sm flex items-center gap-2">
                            Electricity Spike
                            <span className="text-[9px] bg-amber-500/20 text-amber-400 px-1.5 rounded uppercase font-black">Alert</span>
                        </h4>
                        <p className="text-slate-400 text-xs leading-relaxed mt-1">Usage up 40% vs last month. Suggest AC servicing for Unit 4-2.</p>
                    </div>
                </div>

                <div className="bg-slate-900/60 border border-cyan-500/20 p-4 rounded-2xl flex gap-4 items-start">
                    <div className="p-2 bg-cyan-500/10 text-cyan-400 rounded-xl">
                        <Recycle size={20} />
                    </div>
                    <div>
                        <h4 className="text-white font-bold text-sm">Waste Management</h4>
                        <p className="text-slate-400 text-xs leading-relaxed mt-1">Tenants marked 'Recycling Run' complete 4 weeks in a row.</p>
                    </div>
                </div>
            </div>
        </section>

      </div>
    </div>
  );
};
