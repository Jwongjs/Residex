
import React from 'react';
import { ArrowLeft, Wrench, Clock, AlertTriangle, ChevronRight } from 'lucide-react';

export const MaintenanceManager: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  return (
    <div className="flex flex-col h-full bg-[#02040a] animate-in slide-in-from-bottom-6 duration-500 relative overflow-hidden">
      {/* Blue Ambient Glow */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-blue-900/40 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      <div className="p-6 flex items-center gap-4 border-b border-blue-500/20 sticky top-0 bg-[#02040a]/90 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-blue-500/10 rounded-full text-blue-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Maintenance</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-4 no-scrollbar pb-24 relative z-10">
         {[
             { id: 't1', title: 'Leaking Sink', unit: 'Unit 4-2', urgency: 'HIGH', status: 'PENDING', date: 'Today' },
             { id: 't2', title: 'AC Not Cooling', unit: 'Master Bedroom', urgency: 'MEDIUM', status: 'PENDING', date: 'Yesterday' },
             { id: 't3', title: 'Broken Tile', unit: 'Balcony', urgency: 'LOW', status: 'RESOLVED', date: 'Oct 12' }
         ].map((ticket, i) => (
             <div key={i} className="bg-[#0a0a15]/80 border border-white/10 rounded-[2rem] p-5 hover:border-blue-500/30 transition-all group">
                 <div className="flex justify-between items-start mb-3">
                     <div className="flex items-center gap-3">
                         <div className={`h-10 w-10 rounded-xl flex items-center justify-center ${ticket.status === 'RESOLVED' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-blue-500/20 text-blue-400'}`}>
                             <Wrench size={20} />
                         </div>
                         <div>
                             <h4 className="text-white font-bold text-sm">{ticket.title}</h4>
                             <p className="text-slate-400 text-xs font-medium">{ticket.unit}</p>
                         </div>
                     </div>
                     <div className={`text-[9px] font-black uppercase px-2 py-1 rounded ${ticket.urgency === 'HIGH' ? 'bg-rose-500 text-white' : 'bg-slate-800 text-slate-400'}`}>
                         {ticket.urgency} Priority
                     </div>
                 </div>
                 
                 <div className="flex items-center justify-between mt-4 pl-1">
                     <div className="flex items-center gap-1.5 text-slate-500 text-[10px] font-bold uppercase">
                         <Clock size={12} /> {ticket.date}
                     </div>
                     <button className="flex items-center gap-1 text-slate-300 text-xs font-bold group-hover:text-cyan-400 transition-colors">
                         View Details <ChevronRight size={14} />
                     </button>
                 </div>
             </div>
         ))}
      </div>
    </div>
  );
};
