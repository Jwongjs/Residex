
import React from 'react';
import { Plus, Users, ShieldCheck, Activity } from 'lucide-react';
import { User } from '../types';

interface BalanceCardProps {
  userName: string;
  fiscalScore: number;
  harmonyScore: number;
  tenants: User[];
  onCreateBill?: () => void;
  onViewScore?: (type: 'FISCAL' | 'HARMONY') => void;
}

export const BalanceCard: React.FC<BalanceCardProps> = ({ 
  userName, 
  fiscalScore, 
  harmonyScore,
  tenants,
  onCreateBill = () => {},
  onViewScore = (_type) => {}
}) => {
  return (
    <div className="relative group mb-6">
       <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-[2.5rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
       <div className="relative overflow-hidden rounded-[2.5rem] p-6 transition-all duration-700 bg-gradient-to-br from-indigo-900/20 via-black to-black border border-indigo-500/20 shadow-2xl backdrop-blur-xl">
       
       <div className="relative z-10">
          <div className="flex justify-between items-start mb-8">
            <div>
                <span className="text-[10px] font-bold uppercase tracking-[0.2em] mb-1 block text-indigo-400">
                  User Dashboard
                </span>
                <h1 className="text-2xl font-black leading-tight tracking-tight text-white">
                    {userName}
                </h1>
            </div>
            <button 
                onClick={onCreateBill}
                className="h-12 px-6 rounded-2xl flex items-center justify-center gap-2 text-white font-black text-xs shadow-lg transition-all active:scale-95 bg-gradient-to-r from-blue-600 to-purple-600 shadow-purple-500/20 hover:shadow-purple-500/40 hover:scale-[1.02]"
            >
                <Plus size={18} strokeWidth={3} />
                New Invoice
            </button>
          </div>

          <div className="grid grid-cols-2 gap-4 mb-8">
             <button 
                onClick={() => onViewScore('FISCAL')}
                className="rounded-2xl p-4 border bg-white/5 border-white/5 transition-all hover:bg-white/10 hover:border-indigo-500/30 backdrop-blur-md text-left active:scale-95 group/card"
             >
                <div className="flex items-center gap-2 mb-2 text-purple-400 group-hover/card:text-purple-300">
                    <Activity size={14} />
                    <span className="text-[10px] font-bold uppercase tracking-widest text-slate-400">
                      Fiscal Score
                    </span>
                </div>
                <div className="text-3xl font-black text-white">{fiscalScore}</div>
             </button>

             <button 
                onClick={() => onViewScore('HARMONY')}
                className="rounded-2xl p-4 border bg-white/5 border-white/5 transition-all hover:bg-white/10 hover:border-blue-500/30 backdrop-blur-md text-left active:scale-95 group/card"
             >
                <div className="flex items-center gap-2 mb-2 text-blue-400 group-hover/card:text-blue-300">
                    <ShieldCheck size={14} />
                    <span className="text-[10px] font-bold uppercase tracking-widest text-slate-400">
                      Harmony Index
                    </span>
                </div>
                <div className="text-3xl font-black text-white">{harmonyScore}</div>
             </button>
          </div>

          <div className="rounded-2xl p-4 border bg-black/40 border-white/5 transition-all">
            <div className="flex items-center justify-between mb-4">
                <div className="flex items-center gap-1.5 text-slate-500">
                    <Users size={12} strokeWidth={3} />
                    <span className="text-[9px] font-black uppercase tracking-widest">
                      Shared Residents
                    </span>
                </div>
            </div>
            <div className="space-y-3">
                {tenants.slice(0, 3).map(tenant => (
                    <div key={tenant.id} className="flex items-center justify-between py-1 border-b last:border-0 border-white/5">
                        <div className="flex items-center gap-3">
                            <div className={`h-8 w-8 rounded-lg flex items-center justify-center text-[10px] font-bold text-white shadow-lg ${tenant.color || 'bg-slate-700'}`}>
                                {tenant.avatarInitials}
                            </div>
                            <span className="text-xs font-black text-slate-300">{tenant.name}</span>
                        </div>
                        <div className="text-right flex flex-col items-end">
                          <span className="text-[10px] font-black text-indigo-400">
                              LVL {Math.floor((tenant.harmonyPoints || 0)/100)}
                          </span>
                          <span className="text-[8px] font-bold text-slate-500 uppercase tracking-tighter">
                              {tenant.harmonyPoints || 0} PTS
                          </span>
                        </div>
                    </div>
                ))}
            </div>
          </div>
       </div>
    </div>
    </div>
  );
};
