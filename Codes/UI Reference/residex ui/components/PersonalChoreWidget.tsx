
import React from 'react';
import { ClipboardList, ChevronRight, Clock } from 'lucide-react';

interface PersonalChoreWidgetProps {
  onOpenDetail: () => void;
}

export const PersonalChoreWidget: React.FC<PersonalChoreWidgetProps> = ({ onOpenDetail }) => {
  return (
    <div className="relative group">
        <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-500 to-blue-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
        <button 
        onClick={onOpenDetail}
        className="w-full text-left bg-black/40 border border-white/5 rounded-[2rem] p-5 relative overflow-hidden transition-all duration-300 z-10 backdrop-blur-sm hover:bg-purple-500/5"
        >
        <div className="flex justify-between items-start mb-4 relative z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-purple-500/10 text-purple-400 flex items-center justify-center border border-purple-500/20 shadow-lg shadow-purple-900/10">
                    <ClipboardList size={20} />
                </div>
                <div>
                    <h3 className="text-white font-bold text-sm">My Protocol</h3>
                    <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Personal Tasks</p>
                </div>
            </div>
            <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-purple-400 group-hover:bg-purple-500/10 transition-all">
                <ChevronRight size={16} />
            </div>
        </div>

        <div className="space-y-2 relative z-10">
            {[
                { name: 'Kitchen Sanitization', due: '11:30 AM' },
                { name: 'Trash Disposal', due: '09:00 PM' }
            ].map((task, i) => (
                <div key={i} className="flex items-center justify-between p-2 rounded-lg bg-slate-800/40 border border-white/5">
                    <span className="text-xs font-bold text-slate-300">{task.name}</span>
                    <div className="flex items-center gap-1 text-[9px] font-mono text-purple-500/80">
                        <Clock size={10} /> {task.due}
                    </div>
                </div>
            ))}
        </div>
        </button>
    </div>
  );
};
