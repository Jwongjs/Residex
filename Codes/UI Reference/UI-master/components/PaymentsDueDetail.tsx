
import React from 'react';
import { ArrowLeft, CreditCard, AlertCircle, Calendar, ArrowRight, Wallet, History } from 'lucide-react';

export const PaymentsDueDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#050001] animate-in slide-in-from-bottom-6 duration-500">
      <div className="p-6 flex items-center gap-4 border-b border-rose-500/10">
        <button onClick={onBack} className="p-2 bg-rose-500/10 rounded-full text-rose-500 transition-transform active:scale-90"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic">Financial Outlook</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24">
        <div className="bg-rose-500/5 border border-rose-500/20 rounded-[2.5rem] p-8 text-center relative overflow-hidden">
          <div className="absolute top-0 right-0 p-4 opacity-10"><CreditCard size={120} className="text-rose-500" /></div>
          <div className="relative z-10">
            <div className="h-12 w-12 rounded-full bg-rose-500/20 flex items-center justify-center text-rose-500 mx-auto mb-4 animate-pulse">
                <AlertCircle size={28} />
            </div>
            <h2 className="text-3xl font-black text-white mb-2 italic">RM 650.10</h2>
            <p className="text-rose-500/60 text-[10px] font-black uppercase tracking-widest leading-none">Total Outbound Liabilities</p>
          </div>
        </div>

        <section>
          <div className="flex justify-between items-end mb-4 px-1">
             <h3 className="text-white font-black text-sm uppercase tracking-widest flex items-center gap-2">
               <AlertCircle size={16} className="text-rose-500" /> Immediate Settle
             </h3>
             <span className="text-rose-500 text-[9px] font-black uppercase tracking-widest animate-pulse">Critical</span>
          </div>
          <div className="space-y-4">
             {[
               { title: "Oct Rent (Verdi)", amount: 600.00, to: "David Wong", via: "TNG eWallet" },
               { title: "TNB Bill Split", amount: 50.10, to: "Sarah Tan", via: "DuitNow" }
             ].map((payment, i) => (
               <div key={i} className="bg-slate-900/40 border border-rose-500/20 p-5 rounded-[2rem] relative group hover:bg-slate-900/60 transition-all">
                 <div className="flex justify-between items-start mb-4">
                    <div>
                        <h4 className="text-white font-bold text-sm mb-1">{payment.title}</h4>
                        <div className="flex items-center gap-2">
                           <div className="h-5 w-5 rounded-full bg-slate-800 border border-white/5 flex items-center justify-center text-[8px] font-black">{payment.to[0]}</div>
                           <span className="text-slate-400 text-xs font-medium">Owed to <span className="text-white">{payment.to}</span></span>
                        </div>
                    </div>
                    <div className="text-right">
                       <div className="text-white font-black text-lg">RM {payment.amount.toFixed(2)}</div>
                       <div className="text-rose-500 text-[9px] font-black uppercase">Pending Approval</div>
                    </div>
                 </div>
                 <div className="flex gap-2">
                    <button className="flex-1 py-3 bg-rose-500 text-black font-black text-[10px] uppercase rounded-xl shadow-lg shadow-rose-900/20 active:scale-95 transition-all flex items-center justify-center gap-2">
                       <Wallet size={14} /> Settle via {payment.via}
                    </button>
                 </div>
               </div>
             ))}
          </div>
        </section>

        <section>
          <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
            <History size={16} className="text-slate-500" /> Settled History
          </h3>
          <div className="space-y-3 opacity-60">
             {[
               { bill: "Mamak Session", amount: 15.50, date: "2 days ago", to: "Ali" },
               { bill: "Subang Loft Rent", amount: 1200.00, date: "Oct 01", to: "Landlord" }
             ].map((log, i) => (
               <div key={i} className="flex justify-between items-center p-4 bg-slate-900/20 rounded-2xl border border-white/5">
                 <div className="flex items-center gap-3">
                    <div className="h-8 w-8 rounded-full bg-slate-800 flex items-center justify-center text-[10px] text-emerald-400 font-black">
                        <History size={14} />
                    </div>
                    <div>
                        <div className="text-white text-xs font-bold">{log.bill}</div>
                        <div className="text-slate-500 text-[10px] uppercase">Paid to {log.to} • {log.date}</div>
                    </div>
                 </div>
                 <span className="text-white font-mono font-bold text-sm">RM{log.amount.toFixed(2)}</span>
               </div>
             ))}
          </div>
        </section>
      </div>

      <div className="absolute bottom-6 left-6 right-6 z-20">
         <button className="w-full bg-white/5 backdrop-blur-xl border border-white/10 p-4 rounded-2xl flex items-center justify-center gap-3 text-slate-400 hover:text-white transition-all active:scale-[0.98]">
            <Calendar size={18} />
            <span className="text-xs font-black uppercase tracking-widest">Schedule Future Payment</span>
         </button>
      </div>
    </div>
  );
};
