import React from 'react';
import { X, Users } from 'lucide-react';
import { Group } from '../types';

interface GroupPickerModalProps {
  groups: Group[];
  onSelect: (group: Group) => void;
  onClose: () => void;
}

export const GroupPickerModal: React.FC<GroupPickerModalProps> = ({ groups, onSelect, onClose }) => {
  return (
    <div className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="w-full max-w-md bg-[#0f172a]/95 backdrop-blur-2xl sm:rounded-[2.5rem] rounded-t-[2.5rem] p-8 border border-white/10 shadow-2xl animate-in slide-in-from-bottom-8 duration-500 relative overflow-hidden">
        {/* Decorative Glow */}
        <div className="absolute -top-24 -left-24 w-48 h-48 bg-indigo-500/10 rounded-full blur-[60px] pointer-events-none"></div>
        
        <div className="flex justify-between items-center mb-8 relative z-10">
          <div>
            <h2 className="text-white font-black text-2xl tracking-tight">Select Group</h2>
            <p className="text-slate-400 text-xs font-medium uppercase tracking-widest mt-1">View historical activity</p>
          </div>
          <button 
            onClick={onClose} 
            className="h-10 w-10 bg-white/5 rounded-full flex items-center justify-center text-slate-400 hover:text-white transition-all active:scale-90"
          >
            <X size={20} />
          </button>
        </div>

        <div className="grid grid-cols-3 gap-6 max-h-[60vh] overflow-y-auto no-scrollbar py-2 px-1 relative z-10">
            {groups.map((group, index) => (
                <button
                    key={group.id}
                    onClick={() => onSelect(group)}
                    style={{ animationDelay: `${index * 50}ms` }}
                    className="flex flex-col items-center gap-3 group animate-in zoom-in-95 fade-in duration-500"
                >
                    <div className={`
                        h-20 w-20 rounded-full flex items-center justify-center text-3xl shadow-xl transition-all duration-300 ease-spring
                        border-4 border-slate-900 ring-2 ring-white/5
                        ${group.color || 'bg-slate-700'} 
                        group-hover:scale-110 group-hover:ring-cyan-500/30 group-active:scale-90
                    `}>
                        <div className="drop-shadow-lg transform group-hover:rotate-6 transition-transform">{group.emoji || '👥'}</div>
                    </div>
                    <span className="text-white font-bold text-xs text-center truncate w-full group-hover:text-cyan-400 transition-colors">
                        {group.name}
                    </span>
                </button>
            ))}

            {/* Empty State / Create New */}
            {groups.length === 0 && (
                 <div className="col-span-3 py-10 flex flex-col items-center justify-center text-slate-500 bg-white/5 rounded-[2rem] border border-dashed border-white/10">
                    <Users size={32} className="mb-2 opacity-20" />
                    <p className="text-xs font-bold uppercase tracking-widest">No groups found</p>
                 </div>
            )}
        </div>

        <div className="mt-8 pt-6 border-t border-white/5 flex justify-center">
            <p className="text-[10px] text-slate-500 font-bold uppercase tracking-widest italic">SplitLah // Protocols</p>
        </div>
      </div>
    </div>
  );
};