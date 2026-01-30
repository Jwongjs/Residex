
import React from 'react';
import { ArrowLeft, Timer, ShieldCheck, Camera, Users, AlertTriangle } from 'lucide-react';

export const MissionControlDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#020205] animate-in slide-in-from-bottom-6 duration-500 relative overflow-hidden">
      {/* Top Ambient Glow */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/50 via-black to-black pointer-events-none"></div>

      <div className="p-6 flex items-center gap-4 border-b border-indigo-500/20 sticky top-0 bg-[#020205]/80 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-indigo-500/20 rounded-full text-indigo-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Mission Control</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24 relative z-10">
        <div className="bg-gradient-to-br from-indigo-900/40 to-black border border-indigo-500/40 rounded-[2.5rem] p-8 relative overflow-hidden group shadow-2xl shadow-indigo-900/20">
          <div className="absolute -right-10 -bottom-10 opacity-20 rotate-12 group-hover:rotate-0 transition-transform duration-700">
              <Users size={180} className="text-indigo-500" />
          </div>
          
          <div className="flex flex-col gap-4 relative z-10">
            <div className="flex items-center gap-4">
                <div className="h-16 w-16 rounded-2xl bg-indigo-500/30 border border-indigo-500/40 flex items-center justify-center text-indigo-300 shadow-lg shadow-indigo-900/30">
                    <Timer size={32} />
                </div>
                <div>
                    <h2 className="text-3xl font-black text-white italic leading-none">4 Active</h2>
                    <p className="text-indigo-300 text-[10px] font-black uppercase tracking-widest mt-1">Operational Tasks</p>
                </div>
            </div>
            
            <div className="w-full bg-slate-900/60 h-1.5 rounded-full overflow-hidden mt-2">
                <div className="w-[65%] h-full bg-indigo-500 shadow-[0_0_15px_#6366f1]"></div>
            </div>
            <div className="flex justify-between text-[9px] font-bold uppercase text-slate-400">
                <span>Completion Rate</span>
                <span>65%</span>
            </div>
          </div>
        </div>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <ShieldCheck size={16} className="text-indigo-400" /> Pending Peer Consensus
          </h3>
          <div className="bg-slate-900/70 border border-indigo-500/30 rounded-[2rem] p-6 shadow-xl relative overflow-hidden backdrop-blur-sm">
             <div className="absolute top-0 left-0 w-1.5 h-full bg-indigo-500 shadow-[0_0_10px_#6366f1]"></div>
             <div className="flex justify-between items-center mb-4 pl-3">
                <div className="flex items-center gap-3">
                   <div className="h-10 w-10 bg-slate-800 rounded-xl flex items-center justify-center font-black text-xs text-white border border-white/10 shadow-sm">AL</div>
                   <div>
                      <h4 className="text-white font-bold text-sm">Kitchen Sanitization</h4>
                      <p className="text-slate-400 text-[10px] uppercase font-bold">Evidence submitted 12m ago</p>
                   </div>
                </div>
                <button className="flex items-center gap-1.5 text-indigo-300 bg-indigo-500/15 px-3 py-1.5 rounded-lg border border-indigo-500/30 hover:bg-indigo-500/30 transition-colors shadow-sm">
                  <Camera size={14} /> 
                  <span className="text-[9px] font-black uppercase">View</span>
                </button>
             </div>
             <div className="flex gap-3 pl-3">
                <button className="flex-1 py-3 bg-indigo-600 text-white rounded-xl text-[10px] font-black uppercase tracking-widest shadow-lg shadow-indigo-500/30 active:scale-95 transition-all hover:bg-indigo-500">Verify</button>
                <button className="flex-1 py-3 bg-slate-800 text-rose-400 rounded-xl text-[10px] font-black uppercase tracking-widest border border-white/5 hover:bg-rose-950/30 hover:border-rose-500/30 transition-all active:scale-95">Dispute</button>
             </div>
          </div>
        </section>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <Users size={16} className="text-slate-400" /> Active Roster
          </h3>
          <div className="space-y-4">
             {[
               { name: "Raj", task: "Rent Verification", due: "6h", hp: 50, status: 'ontrack' },
               { name: "Sarah", task: "Laundry Cycle", due: "1h", hp: 15, status: 'warning' }
             ].map((op, i) => (
               <div key={i} className="flex items-center justify-between bg-slate-900/50 border border-white/10 p-4 rounded-2xl hover:bg-slate-800/60 transition-colors hover:border-white/20">
                 <div className="flex items-center gap-4">
                    <div className={`h-2.5 w-2.5 rounded-full shadow-sm ${op.status === 'warning' ? 'bg-amber-500 animate-pulse shadow-amber-500/50' : 'bg-emerald-500 shadow-emerald-500/50'}`}></div>
                    <div>
                       <div className="text-white text-xs font-bold mb-0.5">{op.task}</div>
                       <div className="text-slate-400 text-[10px] uppercase font-bold">{op.name} is handling</div>
                    </div>
                 </div>
                 <div className="text-right">
                    <div className={`text-xs font-mono font-bold ${op.status === 'warning' ? 'text-amber-500' : 'text-slate-300'}`}>{op.due} left</div>
                    <div className="text-indigo-400 text-[9px] font-black tracking-widest">+{op.hp} HP</div>
                 </div>
               </div>
             ))}
          </div>
        </section>
      </div>
    </div>
  );
};
