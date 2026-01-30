
import React from 'react';
import { Timer, ChevronRight, Activity } from 'lucide-react';
import { AppMode } from '../types';

interface MissionControlProps {
  onOpenDetail: () => void;
  mode?: AppMode;
}

export const MissionControl: React.FC<MissionControlProps> = ({ onOpenDetail }) => {
  return (
    <div className="relative group">
        <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-purple-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
        <button 
        onClick={onOpenDetail}
        className="w-full text-left bg-black/40 border border-white/5 rounded-[2rem] p-5 relative overflow-hidden transition-all duration-300 z-10 backdrop-blur-sm hover:bg-indigo-500/5"
        >
        <div className="absolute bottom-0 left-0 p-4 opacity-5 group-hover:opacity-10 transition-opacity transform group-hover:rotate-12 duration-500">
            <Activity size={100} className="text-indigo-500" />
        </div>

        <div className="flex justify-between items-start mb-4 relative z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-indigo-500/10 text-indigo-400 flex items-center justify-center border border-indigo-500/20 shadow-lg shadow-indigo-900/10">
                    <Timer size={20} />
                </div>
                <div>
                    <h3 className="text-white font-bold text-sm">Mission Control</h3>
                    <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Shared Status</p>
                </div>
            </div>
            <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-indigo-400 group-hover:bg-indigo-500/10 transition-all">
                <ChevronRight size={16} />
            </div>
        </div>

        <div className="relative z-10">
            <div className="flex justify-between text-[10px] font-bold uppercase text-slate-500 mb-1.5">
                <span>Ops Progress</span>
                <span className="text-indigo-400">4 Active</span>
            </div>
            <div className="w-full bg-slate-800 rounded-full h-1.5 overflow-hidden">
                <div className="w-[65%] h-full bg-indigo-500 shadow-[0_0_10px_rgba(99,102,241,0.5)]"></div>
            </div>
        </div>
        </button>
    </div>
  );
};
