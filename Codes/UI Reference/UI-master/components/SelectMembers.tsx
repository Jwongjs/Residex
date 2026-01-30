
import React, { useState, useMemo } from 'react';
import { ArrowLeft, Search, Plus, Users, Check, X, Star, Save, AlertCircle } from 'lucide-react';
import { User, Group } from '../types';

interface SelectMembersProps {
  currentUser: User;
  existingFriends: User[];
  existingGroups: Group[];
  onBack: () => void;
  onNext: (selectedMembers: User[]) => void;
  onCreateGroup: (selectedMembers: User[]) => void;
}

export const SelectMembers: React.FC<SelectMembersProps> = ({ 
  currentUser, 
  existingFriends, 
  existingGroups,
  onBack, 
  onNext,
  onCreateGroup
}) => {
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set([currentUser.id]));
  const [searchQuery, setSearchQuery] = useState('');
  const [tempGuests, setTempGuests] = useState<User[]>([]);
  const [error, setError] = useState<string | null>(null);

  // Combine real friends and temp guests for the list, filtering out duplicates
  const allDisplayUsers = useMemo(() => {
    const uniqueTempGuests = tempGuests.filter(
        guest => !existingFriends.some(friend => friend.id === guest.id)
    );
    return [...existingFriends, ...uniqueTempGuests];
  }, [existingFriends, tempGuests]);

  const filteredUsers = allDisplayUsers.filter(user => 
    user.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const filteredGroups = existingGroups.filter(group => 
    group.name.toLowerCase().includes(searchQuery.toLowerCase())
  );

  const toggleUser = (userId: string) => {
    if (userId === currentUser.id) return; 
    const newSet = new Set(selectedIds);
    if (newSet.has(userId)) {
      newSet.delete(userId);
    } else {
      newSet.add(userId);
    }
    setSelectedIds(newSet);
    if (error) setError(null);
  };

  const toggleGroup = (group: Group) => {
    const newSet = new Set(selectedIds);
    const allMembersInGroupSelected = group.memberIds.every(id => newSet.has(id));

    if (allMembersInGroupSelected) {
      group.memberIds.forEach(id => {
        if (id !== currentUser.id) newSet.delete(id);
      });
    } else {
      group.memberIds.forEach(id => newSet.add(id));
    }
    setSelectedIds(newSet);
    if (error) setError(null);
  };

  const addNewGuest = () => {
    if (!searchQuery.trim()) return;
    
    // Fix: Added missing properties (phone, fiscalPoints, harmonyPoints) to satisfy User interface
    const newGuest: User = {
      id: `guest-${Date.now()}`,
      name: searchQuery.trim(),
      avatarInitials: searchQuery.slice(0, 2).toUpperCase(),
      isGuest: true,
      color: 'bg-slate-600',
      phone: '',
      fiscalPoints: 0,
      harmonyPoints: 0
    };

    setTempGuests(prev => [...prev, newGuest]);
    setSelectedIds(prev => new Set(prev).add(newGuest.id));
    setSearchQuery('');
    if (error) setError(null);
  };

  const getSelectedUsersList = () => {
    return [...allDisplayUsers, currentUser].filter(u => selectedIds.has(u.id));
  };

  const handleNextStep = () => {
    if (selectedIds.size < 2) {
        setError('Minimum 2 people required to split');
        setTimeout(() => setError(null), 3000);
        return;
    }
    onNext(getSelectedUsersList());
  };

  return (
    <div className="fixed inset-0 z-50 bg-[#020617] flex flex-col">
      <div className="w-full max-w-md mx-auto h-full flex flex-col relative">
        
        {/* Fixed Header */}
        <div className="flex-none pt-6 pb-4 px-6 flex flex-col gap-4 bg-[#020617] border-b border-white/5 z-10 animate-ios-slide-in-right">
          <div className="flex items-center gap-4">
              <button 
                onClick={onBack}
                className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all duration-300 ease-ios active:scale-95 backdrop-blur-md group"
              >
                <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
              </button>
              <div>
                  <h1 className="text-white font-bold text-xl tracking-tight">Who's splitting?</h1>
                  <p className="text-slate-400 text-xs">Select friends or groups</p>
              </div>
          </div>

          <div className="relative transform transition-all duration-300 ease-ios focus-within:scale-[1.02]">
              <div className="absolute left-4 top-3.5 text-slate-500">
                  <Search size={18} />
              </div>
              <input 
                  type="text"
                  value={searchQuery}
                  onChange={(e) => setSearchQuery(e.target.value)}
                  placeholder="Search name or group..."
                  className="w-full bg-slate-800/50 border border-white/10 rounded-2xl py-3.5 pl-11 pr-4 text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all duration-300 ease-ios"
              />
              {searchQuery && filteredUsers.length === 0 && filteredGroups.length === 0 && (
                  <button 
                      onClick={addNewGuest}
                      className="absolute right-2 top-2 bottom-2 bg-cyan-500/10 text-cyan-400 px-3 rounded-xl text-xs font-bold hover:bg-cyan-500 hover:text-white transition-all duration-300 ease-ios flex items-center gap-1 animate-ios-pop-in"
                  >
                      <Plus size={14} />
                      Add "{searchQuery}"
                  </button>
              )}
          </div>
        </div>

        {/* Scrollable List */}
        <div className="flex-1 overflow-y-auto no-scrollbar px-6 pb-48 space-y-6 pt-4 animate-ios-fade-in">
          
          {/* Quick Groups - Updated to Grid with Tiles and Big Logos */}
          {filteredGroups.length > 0 && (
            <section>
                <div className="flex items-center justify-between mb-3 px-1">
                    <h3 className="text-slate-400 text-xs font-bold uppercase tracking-wider">Quick Groups</h3>
                    <button 
                        onClick={() => onCreateGroup(getSelectedUsersList())}
                        className="text-cyan-400 text-xs font-bold hover:text-cyan-300 transition-colors duration-300"
                    >
                        + New Group
                    </button>
                </div>
                
                {/* GRID LAYOUT for Tiles */}
                <div className="grid grid-cols-2 gap-3">
                    {filteredGroups.map((group, idx) => {
                        const isSelected = group.memberIds.every(id => selectedIds.has(id));
                        return (
                            <button
                                key={group.id}
                                onClick={() => toggleGroup(group)}
                                style={{ animationDelay: `${idx * 50}ms` }}
                                className={`
                                    relative p-4 rounded-2xl border transition-all duration-300 ease-ios flex flex-col items-center justify-center gap-3 w-full group active:scale-95 animate-in slide-in-from-bottom-2 fade-in fill-mode-forwards overflow-hidden
                                    ${isSelected 
                                        ? 'bg-cyan-900/20 border-cyan-500/50 shadow-[0_0_20px_rgba(34,211,238,0.1)]' 
                                        : 'bg-slate-800/40 border-white/5 hover:bg-slate-700/60 hover:border-white/10'}
                                `}
                            >
                                {/* Big Logo / Icon */}
                                <div className={`h-14 w-14 rounded-2xl flex items-center justify-center text-3xl shadow-lg transition-transform duration-300 ease-ios group-hover:scale-110 ${group.color || 'bg-slate-600'}`}>
                                    {group.icon || group.emoji || '👥'}
                                </div>
                                
                                <div className="text-center w-full relative z-10">
                                    <div className={`text-sm font-bold truncate w-full transition-colors duration-300 ${isSelected ? 'text-white' : 'text-slate-200'}`}>
                                        {group.name}
                                    </div>
                                    <div className="text-xs text-slate-500 font-medium mt-0.5">{group.memberIds.length} members</div>
                                </div>
                                
                                {/* Selected Indicator */}
                                {isSelected && (
                                    <div className="absolute top-3 right-3 text-cyan-400 animate-ios-pop-in bg-cyan-950/50 rounded-full p-1 border border-cyan-500/20">
                                        <Check size={12} strokeWidth={3} />
                                    </div>
                                )}
                            </button>
                        )
                    })}
                </div>
            </section>
          )}

          {/* All Friends List */}
          <section>
              <h3 className="text-slate-400 text-xs font-bold uppercase tracking-wider mb-3 px-1">All Friends</h3>
              <div className="space-y-2">
                  {/* Current User */}
                  <div className="flex items-center justify-between p-3 rounded-2xl bg-slate-800/30 border border-white/5 opacity-70">
                      <div className="flex items-center gap-3">
                          <div className={`h-10 w-10 rounded-full flex items-center justify-center text-white font-bold text-xs shadow-sm ${currentUser.color || 'bg-slate-600'}`}>
                              {currentUser.profileImage ? (
                                  <img src={currentUser.profileImage} alt={currentUser.name} className="w-full h-full object-cover rounded-full" />
                              ) : currentUser.avatarInitials}
                          </div>
                          <div className="flex flex-col">
                              <span className="text-white font-bold text-sm">{currentUser.name} (You)</span>
                              <span className="text-slate-500 text-[10px]">Host</span>
                          </div>
                      </div>
                      <div className="h-6 w-6 rounded-full bg-cyan-500/20 flex items-center justify-center border border-cyan-500/50">
                          <Check size={12} className="text-cyan-400" strokeWidth={3} />
                      </div>
                  </div>

                  {/* Filtered List */}
                  {filteredUsers.map((user, idx) => {
                      const isSelected = selectedIds.has(user.id);
                      return (
                          <button
                              key={user.id}
                              onClick={() => toggleUser(user.id)}
                              style={{ animationDelay: `${idx * 30}ms` }}
                              className={`w-full flex items-center justify-between p-3 rounded-2xl border transition-all duration-300 ease-ios active:scale-[0.98] animate-in slide-in-from-bottom-2 fade-in fill-mode-forwards
                                  ${isSelected 
                                      ? 'bg-cyan-500/10 border-cyan-500/30' 
                                      : 'bg-transparent border-transparent hover:bg-white/5'}`}
                          >
                              <div className="flex items-center gap-3">
                                  <div className={`h-10 w-10 rounded-full flex items-center justify-center font-bold text-xs text-white shadow-sm ring-2 transition-all duration-300 ease-ios
                                      ${user.color || 'bg-slate-600'}
                                      ${isSelected ? 'ring-cyan-500/50 scale-105' : 'ring-transparent opacity-80'}`}>
                                      {user.profileImage ? (
                                          <img src={user.profileImage} alt={user.name} className="w-full h-full object-cover rounded-full" />
                                      ) : user.avatarInitials}
                                  </div>
                                  <div className="flex flex-col items-start">
                                      <span className={`font-bold text-sm transition-colors duration-300 ${isSelected ? 'text-white' : 'text-slate-300'}`}>{user.name}</span>
                                      {user.isGuest && (
                                          <span className="text-cyan-500/70 text-[10px] bg-cyan-950/30 px-1.5 py-0.5 rounded border border-cyan-500/10">New Guest</span>
                                      )}
                                  </div>
                              </div>
                              
                              <div className={`h-6 w-6 rounded-full flex items-center justify-center border transition-all duration-300 ease-ios
                                  ${isSelected 
                                      ? 'bg-cyan-500 border-cyan-400 scale-110' 
                                      : 'border-slate-600 bg-transparent'}`}>
                                  {isSelected && <Check size={14} className="text-white animate-ios-pop-in" strokeWidth={3} />}
                              </div>
                          </button>
                      );
                  })}
              </div>
          </section>
        </div>

        {/* Fixed Bottom Action Bar */}
        <div className="absolute bottom-0 left-0 right-0 z-20">
          
          {/* Error Message Toast */}
          {error && (
            <div className="absolute -top-12 left-1/2 -translate-x-1/2 bg-red-500/90 text-white px-4 py-2 rounded-xl text-xs font-bold shadow-lg flex items-center gap-2 animate-ios-pop-in">
                <AlertCircle size={14} />
                {error}
            </div>
          )}

          <div className="h-16 bg-gradient-to-b from-transparent to-[#020617] pointer-events-none"></div>
          <div className="bg-[#020617] px-6 pb-8 pt-2 animate-ios-slide-up">
            {/* Selected Avatars Preview */}
            {selectedIds.size > 1 && (
                <div className="mb-4 flex items-center gap-2 animate-in slide-in-from-bottom-2 fade-in">
                    <div className="flex -space-x-3">
                        {getSelectedUsersList().slice(0, 5).map((u) => (
                            <div key={u.id} className={`h-8 w-8 rounded-full border-2 border-[#020617] flex items-center justify-center text-[10px] text-white font-bold shadow-sm animate-ios-pop-in ${u.color || 'bg-slate-600'}`}>
                                {u.profileImage ? (
                                    <img src={u.profileImage} alt={u.name} className="w-full h-full object-cover rounded-full" />
                                ) : u.avatarInitials}
                            </div>
                        ))}
                        {selectedIds.size > 5 && (
                            <div className="h-8 w-8 rounded-full border-2 border-[#020617] bg-slate-700 flex items-center justify-center text-[10px] text-white font-bold animate-ios-pop-in">
                                +{selectedIds.size - 5}
                            </div>
                        )}
                    </div>
                    <span className="text-slate-400 text-xs font-medium ml-2 animate-in fade-in duration-300">
                        {selectedIds.size} people selected
                    </span>
                </div>
            )}

            <div className="flex gap-3">
                {selectedIds.size > 1 && (
                    <button 
                        onClick={() => onCreateGroup(getSelectedUsersList())}
                        className="h-14 w-14 rounded-2xl bg-slate-800 border border-white/10 flex items-center justify-center text-slate-400 hover:text-white hover:bg-slate-700 transition-all duration-300 ease-ios active:scale-95"
                        title="Save as Group"
                    >
                        <Save size={20} />
                    </button>
                )}
                <button 
                    onClick={handleNextStep}
                    className="flex-1 bg-gradient-to-r from-cyan-500 to-blue-600 text-white h-14 rounded-2xl font-bold text-sm shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 hover:scale-[1.02] active:scale-95 transition-all duration-300 ease-ios flex items-center justify-center gap-2"
                >
                    Next Step
                    <div className="bg-white/20 rounded-full p-1">
                        <ArrowLeft size={12} className="rotate-180" strokeWidth={3} />
                    </div>
                </button>
            </div>
          </div>
        </div>
      </div>
    </div>
  );
};
