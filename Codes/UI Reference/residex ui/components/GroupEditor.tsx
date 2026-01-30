
import React, { useState } from 'react';
import { X, Save, Check, Trash2, AlertTriangle } from 'lucide-react';
import { Group, User } from '../types';

interface GroupEditorProps {
  group?: Group; 
  currentUser: User;
  availableFriends: User[];
  existingGroups: Group[];
  initialMemberIds?: string[];
  onSave: (groupData: Partial<Group>) => void;
  onDelete?: (groupId: string) => void;
  onClose: () => void;
}

const EMOJIS = ['👥', '🏠', '🏸', '🍔', '✈️', '🎉', '💼', '⚽', '🍕', '🥂'];
const COLORS = [
    'bg-slate-600',
    'bg-orange-500',
    'bg-blue-500',
    'bg-emerald-500',
    'bg-purple-500',
    'bg-rose-500'
];

export const GroupEditor: React.FC<GroupEditorProps> = ({ 
  group, 
  currentUser, 
  availableFriends, 
  existingGroups,
  initialMemberIds,
  onSave, 
  onDelete,
  onClose 
}) => {
  const [name, setName] = useState(group?.name || '');
  const [emoji, setEmoji] = useState(group?.emoji || '👥');
  const [color, setColor] = useState(group?.color || COLORS[0]);
  const [memberIds, setMemberIds] = useState<Set<string>>(
    new Set(group?.memberIds || initialMemberIds || [currentUser.id])
  );
  const [showDuplicateWarning, setShowDuplicateWarning] = useState(false);

  const toggleMember = (id: string) => {
    if (id === currentUser.id) return; 
    const newSet = new Set(memberIds);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setMemberIds(newSet);
  };

  const handleSaveClick = () => {
    if (!name.trim()) return;

    if (!group) { 
        const currentMembers = Array.from(memberIds);
        const isDuplicate = existingGroups.some(existing => {
            if (existing.memberIds.length !== currentMembers.length) return false;
            return existing.memberIds.every(id => memberIds.has(id));
        });

        if (isDuplicate) {
            setShowDuplicateWarning(true);
            return;
        }
    }

    finalizeSave();
  };

  const finalizeSave = () => {
    onSave({
      id: group?.id, 
      name,
      emoji,
      color,
      memberIds: Array.from(memberIds),
      createdBy: group?.createdBy || currentUser.id
    });
  };

  return (
    <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="w-full max-w-md bg-[#0f172a] sm:rounded-3xl rounded-t-3xl p-6 border border-white/10 shadow-2xl animate-ios-slide-up duration-500 h-[85vh] flex flex-col relative overflow-hidden">
        
        {/* Duplicate Warning Overlay */}
        {showDuplicateWarning && (
            <div className="absolute inset-0 z-20 bg-slate-900/80 backdrop-blur-sm flex items-center justify-center p-6 animate-in fade-in duration-200">
                <div className="bg-[#0f172a] border border-white/10 p-6 rounded-2xl shadow-2xl w-full max-w-xs text-center ring-1 ring-white/20 transform animate-ios-pop-in duration-300">
                    <div className="h-14 w-14 bg-yellow-500/10 text-yellow-400 rounded-2xl flex items-center justify-center mx-auto mb-4 shadow-lg shadow-yellow-500/10">
                        <AlertTriangle size={28} />
                    </div>
                    <h3 className="text-white font-bold text-lg mb-2">Duplicate Group</h3>
                    <p className="text-slate-400 text-sm mb-6 leading-relaxed">
                        Group with these members already exists. Continue creating anyway?
                    </p>
                    <div className="flex gap-3">
                        <button 
                            onClick={() => setShowDuplicateWarning(false)}
                            className="flex-1 py-3.5 rounded-xl font-bold text-slate-300 bg-slate-800 hover:bg-slate-700 transition-colors active:scale-95"
                        >
                            Cancel
                        </button>
                        <button 
                            onClick={finalizeSave}
                            className="flex-1 py-3.5 rounded-xl font-bold bg-gradient-to-r from-blue-600 to-purple-600 text-white hover:shadow-lg hover:shadow-purple-500/20 transition-all active:scale-95"
                        >
                            Create
                        </button>
                    </div>
                </div>
            </div>
        )}

        <div className="flex justify-between items-center mb-6">
          <h2 className="text-white font-bold text-xl">{group ? 'Edit Group' : 'New Group'}</h2>
          <button onClick={onClose} className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400 hover:text-white transition-colors active:scale-90">
            <X size={20} />
          </button>
        </div>

        <div className="flex-1 overflow-y-auto no-scrollbar -mx-2 px-2 space-y-6">
            {/* Icon & Name */}
            <div className="flex flex-col items-center gap-4">
                <div className={`h-20 w-20 rounded-2xl flex items-center justify-center text-4xl shadow-lg transition-all duration-300 ease-ios ${color} animate-ios-pop-in`}>
                    {emoji}
                </div>
                
                {/* Emoji Picker */}
                <div className="flex gap-2 overflow-x-auto w-full justify-center py-2 no-scrollbar">
                    {EMOJIS.map((e, idx) => (
                        <button 
                            key={e} 
                            onClick={() => setEmoji(e)}
                            style={{ animationDelay: `${idx * 50}ms` }}
                            className={`text-xl p-2 rounded-lg transition-all duration-300 ease-ios animate-in zoom-in-50 fade-in ${emoji === e ? 'bg-white/20 scale-125' : 'hover:bg-white/5'}`}
                        >
                            {e}
                        </button>
                    ))}
                </div>
                
                {/* Color Picker */}
                <div className="flex gap-3 justify-center">
                     {COLORS.map(c => (
                        <button
                            key={c}
                            onClick={() => setColor(c)}
                            className={`h-6 w-6 rounded-full ${c} ring-offset-2 ring-offset-[#0f172a] transition-all duration-300 ease-ios ${color === c ? 'ring-2 ring-white scale-125' : 'opacity-50 hover:opacity-100 hover:scale-110'}`}
                        />
                    ))}
                </div>

                <input 
                    type="text" 
                    value={name}
                    onChange={(e) => setName(e.target.value)}
                    placeholder="Group Name"
                    className="w-full bg-transparent border-b border-white/20 py-2 text-center text-white font-bold text-xl focus:outline-none focus:border-purple-500 placeholder-slate-600 transition-all"
                    autoFocus={!group}
                />
            </div>

            {/* Member Selection */}
            <div>
                <label className="text-xs text-slate-400 font-bold uppercase tracking-wider mb-3 block">Members ({memberIds.size})</label>
                <div className="space-y-2">
                    {/* Self */}
                    <div className="flex items-center justify-between p-3 rounded-xl bg-white/5 opacity-60 cursor-not-allowed">
                        <div className="flex items-center gap-3">
                             <div className={`h-8 w-8 rounded-full flex items-center justify-center text-xs font-bold ${currentUser.color || 'bg-slate-700'} text-white`}>
                                {currentUser.avatarInitials}
                             </div>
                             <span className="text-white text-sm font-medium">{currentUser.name} (You)</span>
                        </div>
                        <Check size={16} className="text-slate-500" />
                    </div>

                    {/* Friends */}
                    {availableFriends.map((friend, idx) => {
                         const isSelected = memberIds.has(friend.id);
                         return (
                            <button
                                key={friend.id}
                                onClick={() => toggleMember(friend.id)}
                                style={{ animationDelay: `${idx * 50}ms` }}
                                className={`w-full flex items-center justify-between p-3 rounded-xl transition-all duration-300 ease-ios animate-in slide-in-from-bottom-2 fade-in fill-mode-forwards active:scale-[0.98] ${isSelected ? 'bg-purple-500/10 border border-purple-500/30' : 'hover:bg-white/5 border border-transparent'}`}
                            >
                                <div className="flex items-center gap-3">
                                    <div className={`h-8 w-8 rounded-full flex items-center justify-center text-xs font-bold transition-all duration-300 ${friend.color || 'bg-slate-700'} text-white ${isSelected ? 'scale-110 shadow-lg' : ''}`}>
                                        {friend.avatarInitials}
                                    </div>
                                    <span className={`text-sm font-medium transition-colors ${isSelected ? 'text-purple-100' : 'text-slate-300'}`}>{friend.name}</span>
                                </div>
                                {isSelected && <Check size={16} className="text-purple-400 animate-ios-pop-in" />}
                            </button>
                         )
                    })}
                </div>
            </div>
        </div>

        {/* Footer Actions */}
        <div className="pt-4 mt-4 border-t border-white/10 flex gap-3">
            {group && onDelete && (
                <button 
                    onClick={() => { onDelete(group.id); onClose(); }}
                    className="p-4 rounded-2xl bg-red-500/10 text-red-400 hover:bg-red-500/20 transition-colors active:scale-95"
                >
                    <Trash2 size={20} />
                </button>
            )}
            <button 
                onClick={handleSaveClick}
                disabled={!name.trim()}
                className="flex-1 bg-gradient-to-r from-blue-600 to-purple-600 text-white font-bold py-4 rounded-2xl shadow-lg shadow-purple-500/20 hover:shadow-purple-500/30 active:scale-95 transition-all disabled:opacity-50 disabled:cursor-not-allowed flex items-center justify-center gap-2 duration-300 ease-ios"
            >
                <Save size={18} />
                {group ? 'Update Group' : 'Create Group'}
            </button>
        </div>
      </div>
    </div>
  );
};
