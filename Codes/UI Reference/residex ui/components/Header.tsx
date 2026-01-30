
import React from 'react';
import { Bell, Shield, Zap, Activity, LayoutGrid } from 'lucide-react';
import { User } from '../types';

interface HeaderProps {
  user: User;
  onProfileClick: () => void;
  onGamificationClick: () => void;
}

export const Header: React.FC<HeaderProps> = ({ user, onProfileClick, onGamificationClick }) => {
  return (
    <header className="flex flex-col pt-8 pb-6 px-1 gap-6">
      {/* Title Section */}
      <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-xl bg-indigo-500/20 text-indigo-300 flex items-center justify-center border border-indigo-500/30 shadow-lg shadow-indigo-900/20">
              <LayoutGrid size={20} />
          </div>
          <div>
              <h1 className="text-white font-black text-xl tracking-tight">Command Center</h1>
              <p className="text-indigo-400 text-[10px] font-black uppercase tracking-widest">Resident Overview</p>
          </div>
      </div>

      {/* Profile and Actions Row */}
      <div className="flex justify-between items-center">
        <button 
            onClick={onProfileClick}
            className="flex items-center gap-3 group text-left transition-all"
        >
            <div className="relative">
                <div className="absolute -inset-0.5 rounded-full opacity-0 group-hover:opacity-100 transition-opacity bg-purple-500/50 blur-[4px]"></div>
                <div className={`relative h-12 w-12 rounded-full flex items-center justify-center text-white font-bold text-sm overflow-hidden border-2 border-[#020617] ring-1 ring-white/10 ${user.color || 'bg-slate-700'}`}>
                    {user.avatarInitials}
                </div>
                <div className="absolute -bottom-1 -right-1 h-5 w-5 bg-slate-900 rounded-full flex items-center justify-center border border-slate-700 shadow-sm text-[10px]">
                    <Shield size={10} className="text-indigo-400 fill-indigo-400/20" />
                </div>
            </div>
            
            <div className="flex flex-col">
            <span className="text-white font-bold text-lg leading-tight tracking-tight group-hover:text-purple-200 transition-colors">
                {user.name}
            </span>
            <div className="flex items-center gap-2 text-[10px] font-medium text-slate-400 mt-0.5">
                <span className="text-blue-400 font-bold uppercase tracking-wider">
                {user.rank || 'Active'}
                </span>
                <span className="w-0.5 h-0.5 rounded-full bg-slate-600"></span>
                <span className="text-purple-400 flex items-center gap-1 font-bold">
                    <Zap size={10} fill="currentColor" /> {user.stats?.streak || 0} Streak
                </span>
            </div>
            </div>
        </button>
        
        <div className="flex gap-3">
            <button 
            onClick={onGamificationClick} 
            className="h-10 w-10 rounded-2xl bg-slate-800/50 border border-white/5 flex items-center justify-center backdrop-blur-md text-purple-400 transition-all active:scale-95 hover:bg-purple-500/10 hover:border-purple-500/30 shadow-lg shadow-black/20"
            >
            <Activity size={18} />
            </button>
            <button className="h-10 w-10 rounded-2xl bg-slate-800/50 border border-white/5 flex items-center justify-center text-slate-400 backdrop-blur-md transition-all active:scale-95 hover:text-white hover:bg-white/10 shadow-lg shadow-black/20">
            <Bell size={18} />
            </button>
        </div>
      </div>
    </header>
  );
};
