
import React from 'react';
import { ArrowLeft, Swords, Target, Zap, History, ShieldAlert } from 'lucide-react';

export const BountyBoardDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#050301] animate-in slide-in-from-bottom-6 duration-500">
      <div className="p-6 flex items-center gap-4 border-b border-amber-500/10 sticky top-0 bg-[#050301]/95 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-amber-500/10 rounded-full text-amber-500 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Marketplace</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24">
        <div className="bg-amber-500/5 border border-amber-500/20 rounded-[2.5rem] p-8 text-center relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10"><Swords size={120} className="text-amber-500" /></div>
          <div className="relative z-10">
             <div className="h-14 w-14 rounded-2xl bg-amber-500/20 flex items-center justify-center text-amber-500 mx-auto mb-4 border border-amber-500/30 animate-pulse">
                <Zap size={28} />
             </div>
             <h2 className="text-4xl font-black text-white mb-2 italic">150 HP</h2>
             <p className="text-amber-500/60 text-[10px] font-black uppercase tracking-widest">Total Available Bounty Rewards</p>
          </div>
        </div>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <Target size={16} className="text-amber-500" /> Open Directives
          </h3>
          <div className="space-y-4">
             {[
               { title: "Internet Stability Patch", desc: "Contact Unifi support regarding packet loss in Zone A.", reward: 25, urgency: "HIGH", slots: 1 },
               { title: "Pantry Restock Protocol", desc: "Acquire communal milk, coffee, and eggs for the week.", reward: 40, urgency: "MEDIUM", slots: 2 }
             ].map((item, i) => (
               <div key={i} className="bg-slate-900/40 border border-amber-500/20 p-5 rounded-[2rem] relative group hover:bg-slate-900/60 transition-all">
                 <div className="flex justify-between items-start mb-3">
                    <div>
                        <div className="flex items-center gap-2 mb-1">
                            {item.urgency === 'HIGH' && <ShieldAlert size={12} className="text-rose-500" />}
                            <h4 className="text-white font-bold text-sm">{item.title}</h4>
                        </div>
                        <p className="text-slate-500 text-xs leading-relaxed max-w-[85%]">{item.desc}</p>
                    </div>
                    <div className="flex flex-col items-end">
                        <span className="text-amber-400 font-black text-lg italic">+{item.reward}</span>
                        <span className="text-[9px] text-amber-500/50 font-bold uppercase">HP Points</span>
                    </div>
                 </div>
                 
                 <div className="flex items-center justify-between mt-4 pt-4 border-t border-white/5">
                    <span className="text-[10px] font-bold text-slate-500 uppercase">{item.slots} Slot(s) Remaining</span>
                    <button className="px-6 py-2 bg-amber-500 text-black font-black text-[10px] uppercase rounded-xl shadow-lg shadow-amber-500/20 active:scale-95 transition-all hover:bg-amber-400">
                        Accept Contract
                    </button>
                 </div>
               </div>
             ))}
          </div>
        </section>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <History size={16} className="text-slate-500" /> Contract History
          </h3>
          <div className="space-y-3 opacity-60">
             {[
               { user: "Sarah", task: "Rent Verification", points: 50, time: "2h ago" },
               { user: "Ali", task: "Kitchen Sanitization", points: 25, time: "1d ago" }
             ].map((log, i) => (
               <div key={i} className="flex justify-between items-center text-xs p-4 bg-slate-900/20 rounded-2xl border border-white/5">
                 <div>
                    <span className="text-slate-300 font-bold">{log.user}</span>
                    <span className="text-slate-500"> claimed </span>
                    <span className="text-white font-bold">{log.task}</span>
                 </div>
                 <div className="text-right">
                    <div className="text-amber-500 font-bold">+{log.points} HP</div>
                    <div className="text-[9px] text-slate-600">{log.time}</div>
                 </div>
               </div>
             ))}
          </div>
        </section>
      </div>
    </div>
  );
};
