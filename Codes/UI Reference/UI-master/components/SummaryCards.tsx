
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
  const cardBase = "border border-white/10 shadow-lg backdrop-blur-xl bg-slate-900/80 p-5 rounded-[2rem] text-left overflow-hidden relative group transition-all duration-300 hover:bg-slate-800/80 active:scale-95";

  return (
    <div className="grid grid-cols-2 gap-4">
      <button onClick={onViewYouOwe} className={cardBase}>
        <div className="absolute top-0 right-0 w-20 h-20 bg-rose-500/10 rounded-full blur-2xl group-hover:bg-rose-500/20 transition-colors"></div>
        <div className="flex items-center gap-2 mb-2 relative z-10">
            <div className="p-1.5 rounded-full bg-rose-500/20 text-rose-400">
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

      <button onClick={onViewTasks} className={cardBase}>
        <div className="absolute top-0 right-0 w-20 h-20 bg-cyan-500/10 rounded-full blur-2xl group-hover:bg-cyan-500/20 transition-colors"></div>
        <div className="flex items-center gap-2 mb-2 relative z-10">
            <div className="p-1.5 rounded-full bg-cyan-500/20 text-cyan-400">
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
  );
};
