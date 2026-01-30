
import React, { useState } from 'react';
import { Logo } from './Logo';
import { User, SyncState } from '../types';
import { Sparkles, AlertCircle, LayoutGrid, Users, Radio, ArrowUpRight } from 'lucide-react';

interface SyncHubProps {
  user: User;
  onAskRex: (initialContext?: string) => void;
  onOpenCommunity: () => void;
  onOpenDashboard: () => void;
}

export const SyncHub: React.FC<SyncHubProps> = ({ user, onAskRex, onOpenCommunity, onOpenDashboard }) => {
  // Logic to determine gradient based on SyncState
  const syncState: SyncState = user.syncState || 'SYNCED';

  const getTheme = () => {
      switch (syncState) {
          case 'SYNCED': 
            return {
                // Official Brand: Deep Indigo/Purple
                bg: 'bg-gradient-to-b from-indigo-900 via-[#020617] to-black',
                text: 'text-indigo-400',
                subtext: 'text-purple-200/60',
                greeting: 'You are in Sync.',
                subGreeting: 'System Optimal.',
                pulseColor: 'bg-indigo-500/20'
            };
          case 'DRIFTING':
            return {
                bg: 'bg-gradient-to-b from-amber-900 via-[#020617] to-black',
                text: 'text-amber-400',
                subtext: 'text-amber-200/60',
                greeting: 'Drifting slightly.',
                subGreeting: '2 actions pending review.',
                pulseColor: 'bg-amber-500/20'
            };
          case 'OUT_OF_SYNC':
            return {
                bg: 'bg-gradient-to-b from-rose-900 via-[#020617] to-black',
                text: 'text-rose-500',
                subtext: 'text-rose-200/60',
                greeting: 'Out of Sync.',
                subGreeting: 'Immediate attention required.',
                pulseColor: 'bg-rose-500/20'
            };
      }
  };

  const theme = getTheme();

  return (
    <div className={`h-full w-full relative overflow-hidden transition-colors duration-1000 ${theme.bg}`}>
        
        {/* HERO SECTION (Top 40%) */}
        <div className="h-[45%] flex flex-col items-center justify-center relative z-10 pt-10">
            
            {/* The Living Avatar */}
            <div className="relative mb-8">
                {/* Ambient Breathing Glow */}
                <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-64 h-64 rounded-full blur-[80px] transition-all duration-[2000ms] ${theme.pulseColor} animate-pulse`}></div>
                
                <button 
                    onClick={() => onAskRex()}
                    className="relative transition-transform active:scale-95 duration-500 hover:scale-105"
                >
                    <Logo size={140} animate={true} syncState={syncState} />
                </button>
            </div>

            {/* The Greeting */}
            <div className="text-center space-y-1 animate-in fade-in slide-in-from-bottom-4 duration-1000 delay-300">
                <h1 className={`text-3xl font-black tracking-tight ${theme.text} drop-shadow-2xl`}>
                    {theme.greeting}
                </h1>
                <p className={`text-sm font-medium ${theme.subtext} uppercase tracking-widest`}>
                    {theme.subGreeting}
                </p>
            </div>
        </div>

        {/* PREDICTION DECK (Middle 35%) */}
        <div className="h-[35%] px-6 relative z-10 grid grid-cols-2 gap-4 animate-in slide-in-from-bottom-8 duration-700 delay-150 pb-4">
            
            {/* Card 1: Fiscal Analyst */}
            <button 
                onClick={() => onAskRex("Fiscal Analyst")}
                className="relative w-full h-full bg-[#0f172a]/60 border border-white/5 rounded-[2rem] p-6 flex flex-col justify-between text-left overflow-hidden group hover:bg-[#0f172a]/80 transition-all active:scale-[0.98] shadow-2xl"
            >
                {/* Background Gradient Blob */}
                <div className="absolute -right-6 -top-6 w-32 h-32 bg-rose-500/20 rounded-full blur-[50px] group-hover:bg-rose-500/30 transition-colors"></div>
                
                {/* Top: Title */}
                <div className="relative z-10">
                    <span className="text-slate-300 font-semibold text-sm tracking-wide">Rent Due</span>
                </div>

                {/* Bottom: Value & Pill */}
                <div className="relative z-10">
                    <div className="text-3xl font-black text-white mb-2 tracking-tight">RM 600</div>
                    <div className="inline-flex items-center gap-1.5 bg-rose-500/10 border border-rose-500/20 px-3 py-1.5 rounded-xl backdrop-blur-md">
                        <AlertCircle size={12} className="text-rose-400" />
                        <span className="text-[10px] font-bold text-rose-300 uppercase tracking-wider">3 Days Left</span>
                    </div>
                </div>
            </button>

            {/* Card 2: Harmony Engine */}
            <button 
                onClick={() => onAskRex("Harmony Engine")}
                className="relative w-full h-full bg-[#0f172a]/60 border border-white/5 rounded-[2rem] p-6 flex flex-col justify-between text-left overflow-hidden group hover:bg-[#0f172a]/80 transition-all active:scale-[0.98] shadow-2xl"
            >
                {/* Background Gradient Blob */}
                <div className="absolute -right-6 -top-6 w-32 h-32 bg-indigo-500/20 rounded-full blur-[50px] group-hover:bg-indigo-500/30 transition-colors"></div>
                
                {/* Top: Title & Avatar */}
                <div className="relative z-10 flex justify-between items-start w-full">
                    <span className="text-slate-300 font-semibold text-sm tracking-wide">Trash Duty</span>
                    <div className={`h-6 w-6 rounded-full flex items-center justify-center text-[8px] font-bold text-white border border-white/10 ${user.color || 'bg-indigo-500'}`}>
                        {user.avatarInitials}
                    </div>
                </div>

                {/* Bottom: Value & Pill */}
                <div className="relative z-10">
                    <div className="text-3xl font-black text-white mb-2 tracking-tight">Your Turn</div>
                    <div className="inline-flex items-center gap-1.5 bg-indigo-500/10 border border-indigo-500/20 px-3 py-1.5 rounded-xl backdrop-blur-md">
                        <Sparkles size={12} className="text-indigo-400" />
                        <span className="text-[10px] font-bold text-indigo-300 uppercase tracking-wider">Suggested</span>
                    </div>
                </div>
            </button>

        </div>

        {/* COMMAND CENTER (Bottom 20%) */}
        <div className="absolute bottom-0 left-0 right-0 h-[20%] z-20 flex flex-col items-center justify-end pb-6 bg-gradient-to-t from-black via-black/90 to-transparent">
            
            {/* "Ask Rex" Floating Pill */}
            <button 
                onClick={() => onAskRex()}
                className="relative group mb-6 scale-100 active:scale-95 transition-all duration-200"
            >
                <div className="absolute -inset-1 bg-gradient-to-r from-blue-600 via-indigo-500 to-purple-600 rounded-full blur opacity-75 group-hover:opacity-100 transition duration-200 animate-pulse"></div>
                <div className="relative bg-slate-950 border border-white/10 rounded-full h-14 pl-2 pr-6 flex items-center gap-3 shadow-2xl">
                    <div className="h-10 w-10 rounded-full bg-gradient-to-br from-indigo-500 to-purple-600 flex items-center justify-center shadow-inner">
                        <Logo size={20} className="text-white" />
                    </div>
                    <span className="text-white font-bold text-sm tracking-wide mr-2">Ask Rex...</span>
                    <div className="flex gap-1 h-3 items-center">
                        <div className="w-1 h-3 bg-white/50 rounded-full animate-[bounce_1s_infinite_0ms]"></div>
                        <div className="w-1 h-2 bg-white/50 rounded-full animate-[bounce_1s_infinite_200ms]"></div>
                        <div className="w-1 h-3 bg-white/50 rounded-full animate-[bounce_1s_infinite_400ms]"></div>
                    </div>
                </div>
            </button>

            {/* Bottom Bar Icons */}
            <div className="flex w-full justify-center gap-16 items-center pb-2">
                {/* Left: Dashboard (New) */}
                <button 
                    onClick={onOpenDashboard} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <LayoutGrid size={24} />
                </button>
                
                {/* Middle: Sync (Active) */}
                <div className="relative">
                    <div className="absolute -inset-4 bg-indigo-500/20 rounded-full blur-lg pointer-events-none"></div>
                    <button className="relative text-indigo-400 p-2">
                        <Radio size={28} className="drop-shadow-[0_0_10px_rgba(99,102,241,0.5)]" />
                    </button>
                </div>

                {/* Right: Community (Moved from Left) */}
                <button 
                    onClick={onOpenCommunity} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <Users size={24} />
                </button>
            </div>
        </div>

    </div>
  );
};
