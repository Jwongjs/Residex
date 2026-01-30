
import React from 'react';
import { Headphones, ChevronRight } from 'lucide-react';

export const ReportWidget: React.FC<{ onOpenDetail: () => void }> = ({ onOpenDetail }) => {
  return (
    <div className="mb-8 relative group">
      <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-purple-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
      <button 
        onClick={onOpenDetail}
        className="w-full p-5 rounded-[2rem] border flex items-center justify-between transition-all active:scale-[0.98] overflow-hidden relative shadow-xl bg-white/5 border-white/5 backdrop-blur-xl hover:bg-white/10 z-10"
      >
        <div className="absolute inset-0 bg-gradient-to-r from-transparent via-white/5 to-transparent translate-x-[-100%] group-hover:translate-x-[100%] transition-transform duration-1000 pointer-events-none"></div>
        <div className="flex items-center gap-4 relative z-10">
          <div className="h-12 w-12 rounded-2xl flex items-center justify-center shadow-lg bg-blue-500/10 text-blue-400 transition-transform group-hover:scale-110 border border-blue-500/20">
            <Headphones size={24} />
          </div>
          <div className="text-left">
            <h3 className="font-black text-base uppercase tracking-tight text-white">
              Support Center
            </h3>
            <p className="text-[10px] font-bold uppercase tracking-widest leading-none mt-1 text-slate-500 group-hover:text-blue-400 transition-colors">
              Request services or help
            </p>
          </div>
        </div>
        <ChevronRight size={20} className="text-slate-500 group-hover:text-white transition-colors" />
      </button>
    </div>
  );
};
