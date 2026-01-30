import React from 'react';
import { Bill } from '../types';
import { Users, Calendar, FileText } from 'lucide-react';

interface ActiveBillsProps {
  bills: Bill[];
  onViewDetails: (bill: Bill) => void;
  showHeader?: boolean;
}

export const ActiveBills: React.FC<ActiveBillsProps> = ({ bills, onViewDetails, showHeader = true }) => {
  return (
    <section>
      {showHeader && (
        <div className="flex justify-between items-center mb-5 px-2">
            <h2 className="text-white font-bold text-xl tracking-tight">Active Bills</h2>
            <button className="text-cyan-400 text-sm font-bold hover:text-cyan-300 transition-colors">View All</button>
        </div>
      )}

      <div className="space-y-5 pb-24">
        {bills.map((bill) => (
          <div key={bill.id} className="bg-slate-800/50 backdrop-blur-xl rounded-[2.5rem] overflow-hidden shadow-lg shadow-black/30 border border-white/15 hover:border-white/25 hover:bg-slate-700/50 transition-all duration-300 transform hover:-translate-y-1 group ring-1 ring-white/5">
            {/* Image Section */}
            <div className="h-40 relative overflow-hidden">
              <div className="absolute inset-0 bg-gradient-to-t from-slate-900/80 via-transparent to-transparent z-10"></div>
              <img 
                src={bill.imageUrl} 
                alt={bill.title}
                className="w-full h-full object-cover transition-transform duration-700 group-hover:scale-105 opacity-90"
              />
              <div className="absolute top-4 right-4 z-20">
                 {bill.status === 'PENDING' && (
                    <div className="bg-orange-500/90 backdrop-blur-sm text-white text-[10px] font-extrabold px-3 py-1.5 rounded-full uppercase tracking-wider shadow-lg shadow-orange-900/20 border border-white/10">
                        Pending
                    </div>
                 )}
                 {bill.status === 'SETTLED' && (
                    <div className="bg-emerald-500/90 backdrop-blur-sm text-white text-[10px] font-extrabold px-3 py-1.5 rounded-full uppercase tracking-wider shadow-lg shadow-emerald-900/20 border border-white/10">
                        Settled
                    </div>
                 )}
              </div>
              <div className="absolute top-4 left-4 z-20">
                 <div className="bg-black/40 backdrop-blur-md text-white p-2 rounded-2xl border border-white/10 shadow-sm">
                    <FileText size={18} />
                 </div>
              </div>
            </div>

            {/* Content Section */}
            <div className="p-6 relative">
                <div className="mb-4">
                    <h3 className="text-white font-extrabold text-lg mb-1 tracking-tight">{bill.title}</h3>
                    <p className="text-slate-400 text-sm font-medium">{bill.location}</p>
                </div>

                <div className="flex items-center gap-6 mb-6">
                    <div className="flex items-center gap-2 text-slate-400">
                        <Users size={16} />
                        <span className="text-xs font-semibold">{bill.participantsCount} people</span>
                    </div>
                    <div className="flex items-center gap-2 text-slate-400">
                        <Calendar size={16} />
                        <span className="text-xs font-semibold">{bill.date}</span>
                    </div>
                </div>

                <div className="flex items-end justify-between">
                    <div>
                        <p className="text-slate-500 text-[10px] font-extrabold uppercase tracking-wider mb-1">Your Share</p>
                        <p className="text-white font-black text-2xl">
                            <span className="text-sm font-bold mr-1 text-slate-500">RM</span>
                            {bill.userShare.toFixed(2)}
                        </p>
                    </div>
                    <button 
                      onClick={() => onViewDetails(bill)}
                      className="bg-white text-slate-900 px-8 py-3 rounded-2xl font-bold text-sm hover:bg-cyan-50 transition-all shadow-[0_0_20px_-5px_rgba(255,255,255,0.3)] active:scale-95 group-hover:shadow-cyan-500/20"
                    >
                        Details
                    </button>
                </div>
            </div>
          </div>
        ))}
      </div>
    </section>
  );
};