
import React from 'react';
import { Layers, ChevronRight, TrendingUp } from 'lucide-react';

export const LiquidityWidget: React.FC<{ onOpenDetail: () => void }> = ({ onOpenDetail }) => {
  return (
    <div className="mb-4">
      <button 
        onClick={onOpenDetail}
        className="w-full p-5 rounded-[2rem] border flex flex-col gap-4 transition-all active:scale-[0.98] group overflow-hidden relative shadow-xl bg-slate-900/80 border-white/10 backdrop-blur-xl hover:border-emerald-500/30"
      >
        <div className="absolute bottom-0 left-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity transform group-hover:rotate-6 duration-500">
            <Layers size={100} className="text-emerald-500" />
        </div>

        <div className="flex items-center justify-between w-full relative z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center border border-emerald-500/20 shadow-lg shadow-emerald-900/10">
                    <TrendingUp size={20} />
                </div>
                <div className="text-left">
                    <h3 className="text-white font-bold text-sm">Liquidity Pools</h3>
                    <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Group Funds</p>
                </div>
            </div>
            <ChevronRight size={16} className="text-slate-500 group-hover:text-emerald-400 transition-colors" />
        </div>

        <div className="flex items-center gap-3 w-full relative z-10">
            <div className="flex-1">
                <div className="flex justify-between items-end mb-1">
                    <span className="text-[10px] text-slate-400 font-bold uppercase">Total Active</span>
                    <span className="text-xs text-white font-black">RM 2,250.50</span>
                </div>
                <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                    <div className="w-[65%] h-full bg-emerald-500 shadow-[0_0_10px_rgba(16,185,129,0.5)]"></div>
                </div>
            </div>
        </div>
      </button>
    </div>
  );
};
