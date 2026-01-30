
import React from 'react';
import { AppMode } from '../types';
import { Briefcase, Swords } from 'lucide-react';

interface ModeToggleProps {
  mode: AppMode;
  onToggle: (mode: AppMode) => void;
}

export const ModeToggle: React.FC<ModeToggleProps> = ({ mode, onToggle }) => {
  return (
    <div className="flex justify-center mb-6">
      <div className="bg-slate-800/80 backdrop-blur-md p-1 rounded-2xl border border-white/10 flex items-center shadow-lg">
        <button
          onClick={() => onToggle(AppMode.RPG)}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
            mode === AppMode.RPG 
              ? 'bg-cyan-500 text-white shadow-lg shadow-cyan-500/20' 
              : 'text-slate-500 hover:text-slate-300'
          }`}
        >
          <Swords size={14} />
          RPG Mode
        </button>
        <button
          onClick={() => onToggle(AppMode.EXECUTIVE)}
          className={`flex items-center gap-2 px-4 py-2 rounded-xl text-[10px] font-black uppercase tracking-widest transition-all ${
            mode === AppMode.EXECUTIVE 
              ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-600/20' 
              : 'text-slate-500 hover:text-slate-300'
          }`}
        >
          <Briefcase size={14} />
          Executive
        </button>
      </div>
    </div>
  );
};
