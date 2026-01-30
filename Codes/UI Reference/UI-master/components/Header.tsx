
import React from 'react';
import { Bell, Shield, Activity } from 'lucide-react';
import { User } from '../types';

interface HeaderProps {
  user: User;
  onProfileClick: () => void;
  onGamificationClick: () => void;
}

export const Header: React.FC<HeaderProps> = ({ user, onProfileClick, onGamificationClick }) => {
  return (
    <header className="flex justify-between items-center pt-6 pb-6">
      <button 
        onClick={onProfileClick}
        className="flex items-center gap-3 group text-left transition-all"
      >
        <div className="relative">
            <div className="absolute -inset-[3px] rounded-full opacity-80 blur-[1px] bg-gradient-to-br from-cyan-400 to-indigo-600"></div>
            <div className={`relative h-14 w-14 rounded-full flex items-center justify-center text-white font-bold text-lg overflow-hidden border-2 border-[#020617] ${user.color || 'bg-slate-700'}`}>
                {user.avatarInitials}
            </div>
            <div className="absolute -bottom-1 -right-1 h-6 w-6 bg-slate-800 rounded-full flex items-center justify-center border border-white/20 shadow-lg text-[10px]">
                <Shield size={10} className="text-cyan-400" />
            </div>
        </div>
        
        <div className="flex flex-col">
          <span className="text-slate-500 text-[10px] font-black tracking-widest uppercase">
            System Identity
          </span>
          <span className="text-white font-black text-lg leading-tight tracking-tight">{user.name}</span>
          <div className="flex items-center gap-2 text-[10px] font-bold text-slate-500">
             <span className="text-cyan-400 uppercase tracking-tighter">
               Member Status: {user.rank || 'Active'}
             </span>
             <span>•</span>
             <span className="text-orange-400">🔥 {user.stats?.streak || 0} Day Streak</span>
          </div>
        </div>
      </button>
      
      <div className="flex gap-3">
        <button onClick={onGamificationClick} className="h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center backdrop-blur-md text-amber-400 transition-all active:scale-95 hover:bg-white/10">
          <Activity size={18} />
        </button>
        <button className="h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-slate-300 backdrop-blur-md transition-all active:scale-95 hover:bg-white/10">
          <Bell size={20} strokeWidth={1.5} />
        </button>
      </div>
    </header>
  );
};
