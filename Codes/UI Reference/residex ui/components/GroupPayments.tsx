import React from 'react';
import { Layers, ArrowRight, Wallet, CheckCircle2, TrendingUp } from 'lucide-react';
import { Group } from '../types';

interface GroupPaymentPool {
  id: string;
  groupId: string;
  totalPool: number;
  clearedPool: number;
  status: 'PENDING' | 'SETTLED';
}

interface GroupPaymentsProps {
  groups: Group[];
  onViewDetails: (groupId: string) => void;
}

export const GroupPayments: React.FC<GroupPaymentsProps> = ({ groups, onViewDetails }) => {
  const mockPools: GroupPaymentPool[] = [
    { id: 'p1', groupId: 'g1', totalPool: 1800.00, clearedPool: 1200.00, status: 'PENDING' },
    { id: 'p2', groupId: 'g2', totalPool: 450.50, clearedPool: 450.50, status: 'SETTLED' }
  ];

  return (
    <div className="mt-8 pb-32">
      <div className="flex justify-between items-center mb-5 px-2">
        <div className="flex items-center gap-3">
          <div className="h-10 w-10 rounded-2xl bg-emerald-500/20 text-emerald-400 border border-emerald-500/30 flex items-center justify-center">
            <Layers size={22} />
          </div>
          <div>
            <h2 className="text-white font-black text-xl uppercase tracking-tight">Group Liquidity</h2>
            <p className="text-[10px] font-black text-slate-500 uppercase tracking-widest leading-none">Shared Financial Nodes</p>
          </div>
        </div>
        <button className="text-emerald-400 text-[10px] font-black tracking-widest uppercase hover:opacity-80 transition-opacity">
          History
        </button>
      </div>

      <div className="space-y-4">
        {mockPools.map((pool) => {
          const group = groups.find(g => g.id === pool.groupId);
          const percent = (pool.clearedPool / pool.totalPool) * 100;
          
          return (
            <button 
              key={pool.id}
              onClick={() => onViewDetails(pool.groupId)}
              className="w-full text-left bg-slate-900/40 border border-white/5 rounded-[2rem] p-5 hover:border-emerald-500/30 transition-all group overflow-hidden relative"
            >
              {/* Background Progress Glow */}
              <div 
                className="absolute left-0 bottom-0 h-1 bg-emerald-500/20 transition-all duration-1000" 
                style={{ width: `${percent}%` }}
              ></div>

              <div className="flex justify-between items-center mb-4">
                <div className="flex items-center gap-4">
                  <div className={`h-12 w-12 rounded-2xl flex items-center justify-center text-2xl shadow-lg ring-1 ring-white/10 ${group?.color || 'bg-slate-700'}`}>
                    {group?.emoji || '👥'}
                  </div>
                  <div>
                    <h3 className="text-white font-bold text-base leading-none mb-1">{group?.name}</h3>
                    <div className="flex items-center gap-1.5">
                      <div className={`h-1.5 w-1.5 rounded-full ${pool.status === 'SETTLED' ? 'bg-emerald-400' : 'bg-amber-400 animate-pulse'}`}></div>
                      <span className="text-[9px] font-black text-slate-500 uppercase tracking-widest">
                        {pool.status === 'SETTLED' ? 'Liquidity Secured' : 'Clearing Pool'}
                      </span>
                    </div>
                  </div>
                </div>
                <div className="text-right">
                   <div className="text-white font-black text-lg leading-none mb-1">
                     <span className="text-[10px] text-slate-500 mr-0.5 font-bold">RM</span>
                     {pool.totalPool.toFixed(2)}
                   </div>
                   <span className="text-[9px] font-black text-emerald-400/70 uppercase">Total Liability</span>
                </div>
              </div>

              <div className="flex items-center justify-between gap-4">
                <div className="flex-1">
                   <div className="flex justify-between items-end mb-1.5">
                      <span className="text-[9px] font-black text-slate-500 uppercase">Pool Saturation</span>
                      <span className="text-[10px] font-mono font-bold text-white">{percent.toFixed(0)}%</span>
                   </div>
                   <div className="h-1.5 bg-slate-800 rounded-full overflow-hidden">
                      <div 
                        className="h-full bg-emerald-500 shadow-[0_0_8px_rgba(52,211,153,0.5)] transition-all duration-1000" 
                        style={{ width: `${percent}%` }}
                      ></div>
                   </div>
                </div>
                
                <div className="h-10 w-10 rounded-xl bg-white/5 border border-white/5 flex items-center justify-center text-slate-500 group-hover:text-white group-hover:bg-emerald-500/20 transition-all">
                  <ArrowRight size={18} />
                </div>
              </div>
            </button>
          );
        })}
      </div>
    </div>
  );
};