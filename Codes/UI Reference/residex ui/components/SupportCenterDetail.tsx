
import React, { useState } from 'react';
import { ArrowLeft, Headphones, Wrench, Truck, ShieldAlert, ChevronRight, Phone, CheckCircle2, Clock, Star } from 'lucide-react';
import { LandlordRatingModal } from './LandlordRatingModal';
import { Toast } from './Toast';

export const SupportCenterDetail: React.FC<{ onBack: () => void }> = ({ onBack }) => {
  const [showRatingModal, setShowRatingModal] = useState(false);
  const [selectedTicket, setSelectedTicket] = useState<string>('');
  const [showToast, setShowToast] = useState(false);

  const services = [
    { id: 'maintenance', label: 'Maintenance Request', desc: 'Schedule facility repairs', icon: <Wrench size={24} />, color: 'bg-indigo-500', accent: 'text-indigo-500', border: 'border-indigo-500/30', glow: 'from-indigo-600 to-purple-600' },
    { id: 'cleaning', label: 'Cleaning Service', desc: 'Book professional sanitization', icon: <Truck size={24} />, color: 'bg-blue-500', accent: 'text-blue-500', border: 'border-blue-500/30', glow: 'from-blue-600 to-cyan-600' },
    { id: 'incident', label: 'File Incident Report', desc: 'Log facility or neighbor issues', icon: <ShieldAlert size={24} />, color: 'bg-rose-500', accent: 'text-rose-500', border: 'border-rose-500/30', glow: 'from-rose-600 to-red-600' }
  ];

  const handleRateClick = (ticketName: string) => {
      setSelectedTicket(ticketName);
      setShowRatingModal(true);
  };

  const handleRatingSubmit = () => {
      setShowRatingModal(false);
      setShowToast(true);
      setTimeout(() => setShowToast(false), 3000);
  };

  return (
    <div className="flex flex-col h-full bg-[#02040a] animate-in slide-in-from-bottom-6 duration-500 relative overflow-hidden">
      {/* Top Ambient Glow - Sapphire */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/50 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      <div className="p-6 flex items-center gap-4 border-b border-indigo-500/20 sticky top-0 bg-[#02040a]/80 backdrop-blur-md z-10">
        <button onClick={onBack} className="p-2 bg-indigo-500/10 rounded-full text-indigo-400 active:scale-90 transition-transform"><ArrowLeft size={20}/></button>
        <h1 className="text-white font-black text-xl uppercase italic tracking-tight">Support Console</h1>
      </div>
      
      <div className="flex-1 overflow-y-auto p-6 space-y-8 no-scrollbar pb-24 relative z-10">
        <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-[2.5rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
            <div className="relative bg-[#0a0a15]/60 border border-indigo-500/30 rounded-[2.5rem] p-8 text-center overflow-hidden shadow-2xl backdrop-blur-md">
            <div className="absolute top-0 left-0 w-full h-full bg-[radial-gradient(circle_at_50%_0%,rgba(59,130,246,0.1),transparent_70%)]"></div>
            <div className="relative z-10">
                <div className="h-16 w-16 bg-indigo-500/20 rounded-full flex items-center justify-center mx-auto mb-4 text-indigo-300 shadow-[0_0_30px_rgba(99,102,241,0.4)] border border-indigo-500/30">
                    <Headphones size={32} />
                </div>
                <h2 className="text-2xl font-black text-white mb-2">How can we help?</h2>
                <p className="text-indigo-400/80 text-[10px] font-black uppercase tracking-widest max-w-[200px] mx-auto">Select a service category below to initiate a ticket</p>
            </div>
            </div>
        </div>

        <section className="space-y-4">
           {services.map((service, index) => (
             <div key={service.id} className="relative group">
                 <div className={`absolute -inset-0.5 bg-gradient-to-r ${service.glow} rounded-[2rem] opacity-10 group-hover:opacity-30 blur transition duration-500`}></div>
                 <button 
                    className={`relative w-full bg-[#0a0a15]/60 border ${service.border} p-6 rounded-[2rem] flex items-center gap-5 hover:bg-[#0a0a15]/80 transition-all active:scale-[0.98] backdrop-blur-sm`}
                 >
                    <div className={`h-14 w-14 rounded-2xl flex items-center justify-center text-white shadow-lg ${service.color} group-hover:scale-110 transition-transform duration-300 shadow-[0_0_15px_rgba(0,0,0,0.3)]`}>
                        {service.icon}
                    </div>
                    <div className="text-left flex-1">
                    <h3 className="text-white font-bold text-base mb-1 group-hover:text-white transition-colors">{service.label}</h3>
                    <p className="text-slate-400 text-xs font-medium">{service.desc}</p>
                    </div>
                    <div className={`h-8 w-8 rounded-full border border-white/10 flex items-center justify-center text-slate-500 group-hover:bg-white/10 group-hover:text-white transition-all`}>
                        <ChevronRight size={16} />
                    </div>
                 </button>
             </div>
           ))}
        </section>

        {/* Recent Activity / Ratings Trigger */}
        <section>
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
                <Clock size={16} className="text-indigo-400" /> Recent Activity
            </h3>
            <div className="space-y-3">
                {/* Resolved Ticket - Action Required */}
                <div className="bg-gradient-to-r from-emerald-900/20 to-slate-900 border border-emerald-500/20 p-5 rounded-[2rem] flex flex-col gap-3 relative overflow-hidden">
                    <div className="absolute top-0 right-0 w-20 h-20 bg-emerald-500/10 blur-[40px] rounded-full pointer-events-none"></div>
                    <div className="flex justify-between items-start relative z-10">
                        <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-xl bg-emerald-500/10 text-emerald-400 flex items-center justify-center border border-emerald-500/20">
                                <CheckCircle2 size={18} />
                            </div>
                            <div>
                                <h4 className="text-white font-bold text-sm">Broken Tile Fixed</h4>
                                <p className="text-slate-400 text-[10px] font-medium">Ticket #4922 • Resolved Today</p>
                            </div>
                        </div>
                    </div>
                    <div className="relative z-10">
                        <button 
                            onClick={() => handleRateClick('Broken Tile (Balcony)')}
                            className="w-full py-3 mt-1 bg-emerald-500 text-slate-900 font-bold text-xs uppercase tracking-wider rounded-xl shadow-lg shadow-emerald-500/20 active:scale-95 transition-all flex items-center justify-center gap-2 hover:bg-emerald-400 animate-pulse-glow"
                        >
                            <Star size={14} fill="black" /> Rate Service
                        </button>
                    </div>
                </div>

                {/* Pending Ticket */}
                <div className="bg-slate-900/40 border border-white/5 p-5 rounded-[2rem] flex items-center justify-between opacity-80">
                    <div className="flex items-center gap-3">
                        <div className="h-10 w-10 rounded-xl bg-slate-800 text-slate-400 flex items-center justify-center border border-white/5">
                            <Clock size={18} />
                        </div>
                        <div>
                            <h4 className="text-slate-300 font-bold text-sm">Leaking Sink</h4>
                            <p className="text-slate-500 text-[10px] font-medium">Ticket #4920 • Processing</p>
                        </div>
                    </div>
                    <span className="text-[10px] font-bold text-amber-500 bg-amber-500/10 px-2 py-1 rounded">PENDING</span>
                </div>
            </div>
        </section>
        
        <div className="mt-8 pt-8 border-t border-white/5 text-center">
            <button className="inline-flex items-center gap-2 text-slate-400 hover:text-white transition-colors group">
                <div className="p-2 bg-white/5 rounded-full group-hover:bg-white/10 transition-colors">
                    <Phone size={14} />
                </div>
                <span className="text-xs font-bold uppercase tracking-widest">Emergency Hotline</span>
            </button>
        </div>
      </div>

      {showRatingModal && (
          <LandlordRatingModal 
            ticketTitle={selectedTicket} 
            onClose={() => setShowRatingModal(false)}
            onSubmit={handleRatingSubmit}
          />
      )}

      {showToast && (
          <Toast message="Feedback submitted successfully!" type="success" onClose={() => setShowToast(false)} />
      )}
    </div>
  );
};
