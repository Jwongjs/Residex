
import React from 'react';
import { CreditCard, ListChecks } from 'lucide-react';

interface SummaryCardsProps {
  youOwe: number;
  pendingTasks: number;
  onViewYouOwe?: () => void;
  onViewTasks?: () => void;
}

export const SummaryCards: React.FC<SummaryCardsProps> = ({ 
  youOwe, 
  pendingTasks, 
  onViewYouOwe = () => {}, 
  onViewTasks = () => {}
}) => {
  const cardBase = "border border-white/5 shadow-lg backdrop-blur-xl bg-white/5 p-5 rounded-[2rem] text-left overflow-hidden relative transition-all duration-300 hover:bg-white/10 active:scale-95 h-full";

  return (
    <div className="grid grid-cols-2 gap-4">
      {/* Outstanding Card */}
      <div className="relative group">
        <div className="absolute -inset-0.5 bg-gradient-to-r from-rose-500 to-orange-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
        <button onClick={onViewYouOwe} className={cardBase}>
            <div className="absolute top-0 right-0 w-20 h-20 bg-rose-500/10 rounded-full blur-2xl group-hover:bg-rose-500/20 transition-colors"></div>
            <div className="flex items-center gap-2 mb-2 relative z-10">
                <div className="p-1.5 rounded-full bg-rose-500/20 text-rose-400 border border-rose-500/20">
                    <CreditCard size={10} strokeWidth={3} />
                </div>
                <span className="text-[9px] font-black uppercase tracking-widest text-slate-400">
                    Outstanding
                </span>
            </div>
            <div className="text-xl font-black relative z-10 text-white">
            <span className="text-[10px] font-bold mr-1 opacity-60">RM</span>
            {youOwe.toFixed(2)}
            </div>
        </button>
      </div>

      {/* Active Tasks Card */}
      <div className="relative group">
        <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-500 to-indigo-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
        <button onClick={onViewTasks} className={cardBase}>
            <div className="absolute top-0 right-0 w-20 h-20 bg-purple-500/10 rounded-full blur-2xl group-hover:bg-purple-500/20 transition-colors"></div>
            <div className="flex items-center gap-2 mb-2 relative z-10">
                <div className="p-1.5 rounded-full bg-purple-500/20 text-purple-400 border border-purple-500/20">
                    <ListChecks size={10} strokeWidth={3} />
                </div>
                <span className="text-[9px] font-black uppercase tracking-widest text-slate-400">
                    Active Tasks
                </span>
            </div>
            <div className="text-xl font-black relative z-10 text-white">
            {pendingTasks} <span className="text-[10px] font-bold uppercase ml-1 opacity-60">Pending</span>
            </div>
        </button>
      </div>
    </div>
  );
};
