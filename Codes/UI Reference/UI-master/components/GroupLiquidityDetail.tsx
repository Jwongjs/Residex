
import React from 'react';
import { ArrowLeft, Layers, Wallet, TrendingUp, History, FileText, CheckCircle2 } from 'lucide-react';

export const GroupLiquidityDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#000402] animate-in slide-in-from-bottom-6 duration-500">
      <div className="p-6 flex items-center gap-4 border-b border-emerald-500/10">
        <button onClick={onBack} className="p-2 bg-emerald-500/10 rounded-full text-emerald-400"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic">Liquidity Node</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-20">
        <div className="bg-emerald-500/5 border border-emerald-500/20 rounded-[2.5rem] p-8 text-center">
          <TrendingUp size={40} className="text-emerald-400 mx-auto mb-4" />
          <h2 className="text-3xl font-black text-white mb-2 italic">66.7%</h2>
          <p className="text-emerald-400/60 text-[10px] font-black uppercase tracking-widest">Node Saturation (Cleared)</p>
          <div className="w-full h-2 bg-slate-900 rounded-full mt-6 overflow-hidden">
            <div className="h-full bg-emerald-500 w-[66.7%] shadow-[0_0_15px_rgba(16,185,129,0.5)]"></div>
          </div>
        </div>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <FileText size={16} className="text-emerald-400" /> Outstanding Liability Pool
          </h3>
          <div className="space-y-4">
             {[
               { bill: "Monthly Rent (Oct)", total: 1800.0, cleared: 1200.0, participants: 3 },
               { bill: "TNB Electricity", total: 150.40, cleared: 0.0, participants: 3 }
             ].map((pool, i) => (
               <div key={i} className="bg-slate-900/40 border border-white/5 p-5 rounded-2xl relative overflow-hidden group">
                 <div className="flex justify-between items-start mb-4 relative z-10">
                    <div>
                       <h4 className="text-white font-bold">{pool.bill}</h4>
                       <p className="text-slate-500 text-[10px] uppercase">{pool.participants} Nodes Integrated</p>
                    </div>
                    <div className="text-right">
                       <div className="text-white font-black">RM {pool.total.toFixed(2)}</div>
                       <div className="text-emerald-400 text-[10px] font-bold">RM {pool.cleared.toFixed(2)} Secured</div>
                    </div>
                 </div>
                 <div className="h-1 bg-slate-800 rounded-full overflow-hidden">
                   <div className="h-full bg-emerald-500/30" style={{ width: `${(pool.cleared/pool.total)*100}%` }}></div>
                 </div>
               </div>
             ))}
          </div>
        </section>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <CheckCircle2 size={16} className="text-emerald-400" /> Settled Cycles
          </h3>
          <div className="space-y-3 opacity-60">
             {[
               { title: "Sept Rent", amount: 1800, date: "Sept 30" },
               { title: "Internet (Sept)", amount: 159, date: "Sept 15" }
             ].map((hist, i) => (
               <div key={i} className="flex justify-between items-center text-xs p-3 border-b border-white/5">
                 <span className="text-slate-400">{hist.title} • {hist.date}</span>
                 <span className="text-white font-bold">RM {hist.amount}</span>
               </div>
             ))}
          </div>
        </section>
      </div>
    </div>
  );
};
