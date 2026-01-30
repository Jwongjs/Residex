
import React from 'react';
import { User, Plus, History } from 'lucide-react';
import { User as UserType } from '../types';

interface FriendsListProps {
  friends: UserType[];
  onAddFriend: () => void;
  onViewHistory: (userId: string) => void;
}

export const FriendsList: React.FC<FriendsListProps> = ({ friends, onAddFriend, onViewHistory }) => {
  return (
    <div className="relative group mb-4">
      <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-blue-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
      <div className="relative z-10 bg-white/5 backdrop-blur-xl rounded-[2rem] p-6 border border-white/5 shadow-lg overflow-hidden">
      <div className="flex justify-between items-center mb-4">
        <h2 className="text-white font-bold text-lg">My Network</h2>
        <button 
            onClick={onAddFriend}
            className="text-xs bg-cyan-500 hover:bg-cyan-400 text-white px-3 py-1.5 rounded-full font-semibold transition-all flex items-center gap-1 shadow-lg shadow-cyan-500/20 active:scale-95"
        >
            <Plus size={12} strokeWidth={3} /> Add
        </button>
      </div>

      <div className="flex gap-4 overflow-x-auto no-scrollbar pb-2">
         {friends.map((friend) => (
            <div
                key={friend.id}
                onClick={() => onViewHistory(friend.id)}
                className="flex flex-col items-center gap-2 min-w-[70px] group cursor-pointer"
            >
                <div className={`h-14 w-14 rounded-full flex items-center justify-center text-sm font-bold shadow-lg transition-all group-hover:scale-110 group-active:scale-90 ${friend.color || 'bg-slate-700'} text-white ring-2 ring-transparent group-hover:ring-white/20`}>
                    {friend.avatarInitials}
                </div>
                <span className="text-white font-medium text-[11px] truncate w-full text-center">{friend.name.split(' ')[0]}</span>
            </div>
         ))}
         
         <button 
            onClick={() => onViewHistory('all')}
            className="flex flex-col items-center gap-2 min-w-[70px] group"
         >
            <div className="h-14 w-14 rounded-full bg-white/5 border-2 border-dashed border-white/10 flex items-center justify-center text-slate-500 group-hover:text-white group-hover:border-white/30 transition-all active:scale-95">
                <History size={20} />
            </div>
            <span className="text-slate-500 font-medium text-[11px]">History</span>
         </button>
      </div>
    </div>
    </div>
  );
};
