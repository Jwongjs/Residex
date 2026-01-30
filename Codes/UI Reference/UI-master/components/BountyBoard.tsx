
import React from 'react';
import { Swords, ChevronRight, Zap } from 'lucide-react';
import { AppMode } from '../types';

interface BountyBoardProps {
  onOpenDetail: () => void;
  mode?: AppMode;
}

export const BountyBoard: React.FC<BountyBoardProps> = ({ onOpenDetail }) => {
  return (
    <button 
      onClick={onOpenDetail}
      className="w-full text-left bg-black/20 border border-white/5 rounded-[2rem] p-5 group hover:border-amber-500/30 hover:bg-amber-500/5 transition-all duration-300 relative overflow-hidden"
    >
      <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity transform group-hover:scale-110 duration-500">
         <Swords size={80} className="text-amber-500" />
      </div>
      
      <div className="flex justify-between items-start mb-4 relative z-10">
         <div className="flex items-center gap-3">
             <div className="h-10 w-10 rounded-xl bg-amber-500/10 text-amber-500 flex items-center justify-center border border-amber-500/20 shadow-lg shadow-amber-900/10">
                 <Swords size={20} />
             </div>
             <div>
                 <h3 className="text-white font-bold text-sm">Bounty Board</h3>
                 <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Public Pool</p>
             </div>
         </div>
         <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-amber-400 group-hover:bg-amber-500/10 transition-all">
             <ChevronRight size={16} />
         </div>
      </div>
      
      <div className="flex items-center gap-3 relative z-10">
          <div className="flex-1 bg-slate-900/60 rounded-xl p-3 border border-white/5 flex items-center justify-between">
              <span className="text-slate-400 text-[10px] font-bold uppercase">Available</span>
              <span className="text-white font-black text-xs">2 Tasks</span>
          </div>
          <div className="flex-1 bg-slate-900/60 rounded-xl p-3 border border-white/5 flex items-center justify-between">
              <span className="text-slate-400 text-[10px] font-bold uppercase">Rewards</span>
              <div className="flex items-center gap-1 text-amber-400 font-black text-xs">
                  <Zap size={10} /> 65 HP
              </div>
          </div>
      </div>
    </button>
  );
};
