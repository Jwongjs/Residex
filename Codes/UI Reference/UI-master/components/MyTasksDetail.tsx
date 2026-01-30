
import React from 'react';
import { ArrowLeft, ClipboardList, Clock, CheckCircle2, Circle } from 'lucide-react';

export const MyTasksDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#000405] animate-in slide-in-from-bottom-6 duration-500">
      <div className="p-6 flex items-center gap-4 border-b border-cyan-500/10 sticky top-0 bg-[#000405]/95 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-cyan-500/10 rounded-full text-cyan-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">My Protocol</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24">
        <div className="bg-cyan-900/10 border border-cyan-500/20 rounded-[2.5rem] p-8 relative overflow-hidden">
           <div className="flex justify-between items-start relative z-10">
              <div>
                  <h2 className="text-3xl font-black text-white italic mb-1">2 Pending</h2>
                  <p className="text-cyan-400 text-[10px] font-black uppercase tracking-widest">Assignments Due Today</p>
              </div>
              <div className="h-14 w-14 bg-cyan-500/20 rounded-2xl flex items-center justify-center text-cyan-400 border border-cyan-500/30">
                  <ClipboardList size={28} />
              </div>
           </div>
           
           <div className="mt-6 flex items-end gap-2">
               <div className="flex-1 bg-slate-900/50 h-2 rounded-full overflow-hidden">
                   <div className="w-[50%] h-full bg-cyan-400 shadow-[0_0_10px_cyan]"></div>
               </div>
               <span className="text-[10px] font-mono font-bold text-cyan-500">50%</span>
           </div>
        </div>

        <section className="space-y-4">
           {[
             { id: 't1', title: 'Kitchen Sanitization', time: '11:30 AM', points: 25, status: 'pending' },
             { id: 't2', title: 'Trash Disposal', time: '09:00 PM', points: 10, status: 'pending' },
             { id: 't3', title: 'Morning Briefing', time: '08:00 AM', points: 5, status: 'completed' }
           ].map((task, i) => (
             <div 
                key={i} 
                className={`p-5 rounded-[2rem] border transition-all ${
                    task.status === 'completed' 
                        ? 'bg-slate-900/20 border-white/5 opacity-60' 
                        : 'bg-slate-900/40 border-cyan-500/20 hover:border-cyan-500/40'
                }`}
             >
                <div className="flex justify-between items-start mb-3">
                    <div className="flex items-center gap-3">
                        <button className={`h-6 w-6 rounded-full border-2 flex items-center justify-center transition-all ${task.status === 'completed' ? 'border-emerald-500 bg-emerald-500 text-black' : 'border-slate-600 hover:border-cyan-400'}`}>
                            {task.status === 'completed' && <CheckCircle2 size={16} />}
                        </button>
                        <div>
                            <h3 className={`font-bold text-sm ${task.status === 'completed' ? 'text-slate-500 line-through' : 'text-white'}`}>{task.title}</h3>
                            <div className="flex items-center gap-1.5 text-slate-500 mt-0.5">
                                <Clock size={10} />
                                <span className="text-[10px] font-mono">{task.time}</span>
                            </div>
                        </div>
                    </div>
                    {task.status !== 'completed' && (
                        <div className="bg-cyan-950 text-cyan-400 px-2 py-1 rounded text-[9px] font-black uppercase tracking-wider border border-cyan-500/20">
                            +{task.points} HP
                        </div>
                    )}
                </div>
                
                {task.status !== 'completed' && (
                    <button className="w-full py-3 mt-2 bg-white/5 hover:bg-cyan-500/10 text-slate-300 hover:text-cyan-400 font-bold text-[10px] uppercase rounded-xl border border-white/5 hover:border-cyan-500/30 transition-all">
                        Initiate Verification
                    </button>
                )}
             </div>
           ))}
        </section>
      </div>
    </div>
  );
};
