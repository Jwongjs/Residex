
import React from 'react';
import { ArrowLeft, Headphones, Wrench, Truck, ShieldAlert, ChevronRight, Phone } from 'lucide-react';

export const SupportCenterDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  const services = [
    { id: 'maintenance', label: 'Maintenance Request', desc: 'Schedule facility repairs', icon: <Wrench size={24} />, color: 'bg-amber-500', accent: 'text-amber-500', border: 'border-amber-500/20' },
    { id: 'cleaning', label: 'Cleaning Service', desc: 'Book professional sanitization', icon: <Truck size={24} />, color: 'bg-blue-500', accent: 'text-blue-500', border: 'border-blue-500/20' },
    { id: 'incident', label: 'File Incident Report', desc: 'Log facility or neighbor issues', icon: <ShieldAlert size={24} />, color: 'bg-rose-500', accent: 'text-rose-500', border: 'border-rose-500/20' }
  ];

  return (
    <div className="flex flex-col h-full bg-[#020408] animate-in slide-in-from-bottom-6 duration-500">
      <div className="p-6 flex items-center gap-4 border-b border-blue-500/10 sticky top-0 bg-[#020408]/95 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-blue-500/10 rounded-full text-blue-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Support Console</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24">
        <div className="bg-blue-600/5 border border-blue-500/20 rounded-[2.5rem] p-8 text-center relative overflow-hidden">
          <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_50%_0%,rgba(59,130,246,0.15),transparent_70%)]"></div>
          <div className="relative z-10">
              <div className="h-16 w-16 bg-blue-500/20 rounded-full flex items-center justify-center mx-auto mb-4 text-blue-400 shadow-[0_0_30px_rgba(59,130,246,0.2)]">
                  <Headphones size={32} />
              </div>
              <h2 className="text-2xl font-black text-white mb-2">How can we help?</h2>
              <p className="text-blue-400/60 text-[10px] font-black uppercase tracking-widest max-w-[200px] mx-auto">Select a service category below to initiate a ticket</p>
          </div>
        </div>

        <section className="space-y-4">
           {services.map((service) => (
             <button 
                key={service.id} 
                className={`w-full bg-slate-900/40 border ${service.border} p-6 rounded-[2rem] flex items-center gap-5 group hover:bg-slate-800/60 transition-all active:scale-[0.98]`}
             >
                <div className={`h-14 w-14 rounded-2xl flex items-center justify-center text-white shadow-lg ${service.color} group-hover:scale-110 transition-transform duration-300`}>
                    {service.icon}
                </div>
                <div className="text-left flex-1">
                   <h3 className="text-white font-bold text-base mb-1 group-hover:text-white transition-colors">{service.label}</h3>
                   <p className="text-slate-500 text-xs font-medium">{service.desc}</p>
                </div>
                <div className={`h-8 w-8 rounded-full border border-white/5 flex items-center justify-center text-slate-600 group-hover:bg-white/10 group-hover:text-white transition-all`}>
                    <ChevronRight size={16} />
                </div>
             </button>
           ))}
        </section>
        
        <div className="mt-8 pt-8 border-t border-white/5 text-center">
            <button className="inline-flex items-center gap-2 text-slate-500 hover:text-white transition-colors">
                <Phone size={14} />
                <span className="text-xs font-bold uppercase tracking-widest">Emergency Hotline</span>
            </button>
        </div>
      </div>
    </div>
  );
};
