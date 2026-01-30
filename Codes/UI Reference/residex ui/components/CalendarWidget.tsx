
import React from 'react';
import { Calendar, ChevronRight, Clock } from 'lucide-react';

export const CalendarWidget: React.FC<{ onOpenDetail: () => void }> = ({ onOpenDetail }) => {
  const today = new Date().toLocaleDateString('en-US', { weekday: 'long', day: 'numeric', month: 'short' });

  return (
    <div className="mb-4 relative group">
      <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-500 to-indigo-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
      <button 
        onClick={onOpenDetail}
        className="w-full p-5 rounded-[2rem] border flex flex-col gap-4 transition-all active:scale-[0.98] overflow-hidden relative shadow-xl bg-white/5 border-white/5 backdrop-blur-xl hover:bg-white/10 z-10"
      >
        <div className="absolute top-0 right-0 p-6 opacity-5 group-hover:opacity-10 transition-opacity transform group-hover:scale-110 duration-500">
            <Calendar size={100} className="text-purple-500" />
        </div>

        <div className="flex items-center justify-between w-full relative z-10">
            <div className="flex items-center gap-3">
                <div className="h-10 w-10 rounded-xl bg-purple-500/10 text-purple-400 flex items-center justify-center border border-purple-500/20 shadow-lg shadow-purple-900/10">
                    <Calendar size={20} />
                </div>
                <div className="text-left">
                    <h3 className="text-white font-bold text-sm">Shared Calendar</h3>
                    <p className="text-slate-500 text-[10px] font-bold uppercase tracking-widest">Schedule</p>
                </div>
            </div>
            <ChevronRight size={16} className="text-slate-500 group-hover:text-purple-400 transition-colors" />
        </div>

        <div className="w-full bg-black/40 rounded-xl p-3 border border-white/5 flex items-center justify-between relative z-10">
            <div className="flex items-center gap-3">
                <div className="bg-purple-500/20 px-2 py-1 rounded text-[10px] font-black text-purple-300 uppercase">
                    Today
                </div>
                <span className="text-xs text-white font-bold">{today}</span>
            </div>
            <div className="flex items-center gap-1.5 text-[10px] text-slate-400">
                <Clock size={12} />
                <span>2 Events</span>
            </div>
        </div>
      </button>
    </div>
  );
};
