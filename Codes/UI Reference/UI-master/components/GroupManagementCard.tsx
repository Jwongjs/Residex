import React from 'react';
import { Users, Plus, ChevronRight, Edit2 } from 'lucide-react';
import { Group } from '../types';

interface GroupManagementCardProps {
  groups: Group[];
  onManageGroup: (group: Group) => void;
  onCreateGroup: () => void;
}

export const GroupManagementCard: React.FC<GroupManagementCardProps> = ({ 
  groups, 
  onManageGroup, 
  onCreateGroup 
}) => {
  return (
    <div className="bg-slate-800/40 backdrop-blur-xl rounded-[2rem] p-6 mb-8 border border-white/10 shadow-lg relative overflow-hidden">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-white font-bold text-lg flex items-center gap-2">
            <Users size={18} className="text-cyan-400" />
            My Groups
        </h2>
        <button 
            onClick={onCreateGroup}
            className="text-xs bg-white/10 hover:bg-white/20 text-white px-3 py-1.5 rounded-full font-semibold transition-all flex items-center gap-1"
        >
            <Plus size={12} /> New
        </button>
      </div>

      <div className="flex gap-3 overflow-x-auto no-scrollbar pb-2 -mx-2 px-2">
         {/* Create New Card (Visual shortcut) */}
         <button 
            onClick={onCreateGroup}
            className="min-w-[100px] h-32 rounded-2xl border-2 border-dashed border-white/10 flex flex-col items-center justify-center gap-2 text-slate-400 hover:text-cyan-400 hover:border-cyan-500/30 hover:bg-cyan-500/5 transition-all group"
         >
            <div className="h-10 w-10 rounded-full bg-white/5 flex items-center justify-center group-hover:scale-110 transition-transform">
                <Plus size={20} />
            </div>
            <span className="text-xs font-bold">Create</span>
         </button>

         {groups.map(group => (
            <button
                key={group.id}
                onClick={() => onManageGroup(group)}
                className="min-w-[140px] h-32 rounded-2xl bg-slate-700/30 border border-white/5 p-4 flex flex-col justify-between items-start hover:bg-slate-700/50 hover:border-white/20 transition-all group relative overflow-hidden"
            >
                <div className={`absolute top-0 right-0 p-2 opacity-0 group-hover:opacity-100 transition-opacity text-slate-300`}>
                    <Edit2 size={12} />
                </div>
                
                <div className={`h-10 w-10 rounded-xl flex items-center justify-center text-xl shadow-sm ${group.color || 'bg-slate-600'}`}>
                    {group.emoji || '👥'}
                </div>
                
                <div className="text-left w-full">
                    <h3 className="text-white font-bold text-sm truncate w-full">{group.name}</h3>
                    <p className="text-slate-400 text-xs">{group.memberIds.length} members</p>
                </div>
            </button>
         ))}
      </div>
    </div>
  );
};
