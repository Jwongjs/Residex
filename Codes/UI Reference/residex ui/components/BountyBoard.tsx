
import React from 'react';
import { Swords, ChevronRight, Zap } from 'lucide-react';
import { AppMode } from '../types';

interface BountyBoardProps {
  onOpenDetail: () => void;
  mode?: AppMode;
}

export const BountyBoard: React.FC<BountyBoardProps> = ({ onOpenDetail }) => {
  return (
    <div className="relative group">
        <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-indigo-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
        <button 
        onClick={onOpenDetail}
        className="w-full text-left bg-black/40 border border-white/5 rounded-[2rem] p-5 relative overflow-hidden transition-all duration-300 z-10 backdrop-blur-sm hover:bg-blue-500/5"
        >
        <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity transform group-hover:scale-110 duration-500">
            <Swords size={80} className="text-blue-500" />
        </div>
        
        <div className="flex justify-between items-start mb-4 relative z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-blue-500/10 text-blue-400 flex items-center justify-center border border-blue-500/20 shadow-lg shadow-blue-900/10">
                    <Swords size={20} />
                </div>
                <div>
                    <h3 className="text-white font-bold text-sm">Bounty Board</h3>
                    <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Public Pool</p>
                </div>
            </div>
            <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-blue-400 group-hover:bg-blue-500/10 transition-all">
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
                <div className="flex items-center gap-1 text-blue-400 font-black text-xs">
                    <Zap size={10} /> 65 HP
                </div>
            </div>
        </div>
        </button>
    </div>
  );
};
