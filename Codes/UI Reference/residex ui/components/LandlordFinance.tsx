
import React from 'react';
import { TrendingUp, TrendingDown, DollarSign, Wallet, ArrowUpRight, PieChart } from 'lucide-react';

export const LandlordFinance: React.FC = () => {
  const chartData = [65, 78, 45, 92, 85, 100]; // Revenue percentages for last 6 months
  const months = ['May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct'];

  return (
    <div className="space-y-6 animate-in fade-in slide-in-from-right-8 duration-500 pb-32">
        {/* Total Balance Card (Matches BalanceCard style) */}
        <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-[2.5rem] opacity-30 group-hover:opacity-50 blur transition duration-500"></div>
            <div className="relative bg-gradient-to-br from-indigo-900/40 via-black to-black border border-white/10 rounded-[2.5rem] p-8 overflow-hidden shadow-2xl backdrop-blur-xl">
                <div className="absolute top-0 right-0 p-6 opacity-20">
                    <Wallet size={120} className="text-blue-500" />
                </div>
                
                <div className="relative z-10">
                    <span className="text-blue-300 text-[10px] font-black uppercase tracking-[0.2em] mb-2 block">Net Income (Oct)</span>
                    <h2 className="text-5xl font-black text-white tracking-tighter mb-6 flex items-baseline">
                        <span className="text-lg text-slate-500 mr-1 font-bold">RM</span>
                        14,250.00
                    </h2>
                    
                    <div className="flex gap-4">
                        <div className="flex items-center gap-2 bg-emerald-500/10 px-4 py-2 rounded-xl border border-emerald-500/20 backdrop-blur-md">
                            <div className="bg-emerald-500/20 p-1 rounded-full">
                                <ArrowUpRight size={12} className="text-emerald-400" />
                            </div>
                            <span className="text-[10px] font-black text-emerald-400 uppercase tracking-wide">+12.5% vs Sept</span>
                        </div>
                    </div>
                </div>
            </div>
        </div>

        {/* Stats Grid (Matches SummaryCards style) */}
        <div className="grid grid-cols-2 gap-4">
            <div className="relative group h-full">
                <div className="absolute -inset-0.5 bg-gradient-to-r from-cyan-500 to-emerald-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                <div className="relative bg-white/5 border border-white/10 backdrop-blur-xl rounded-[2rem] p-5 shadow-lg flex flex-col justify-between h-32 hover:bg-white/10 transition-colors">
                    <div className="flex items-center gap-2 text-slate-400">
                        <div className="p-1.5 rounded-full bg-cyan-500/20 text-cyan-400 border border-cyan-500/20">
                            <TrendingUp size={12} strokeWidth={3} />
                        </div>
                        <span className="text-[9px] font-black uppercase tracking-widest">Collected</span>
                    </div>
                    <p className="text-white font-black text-2xl">RM 13.8k</p>
                </div>
            </div>

            <div className="relative group h-full">
                <div className="absolute -inset-0.5 bg-gradient-to-r from-rose-500 to-orange-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                <div className="relative bg-white/5 border border-white/10 backdrop-blur-xl rounded-[2rem] p-5 shadow-lg flex flex-col justify-between h-32 hover:bg-white/10 transition-colors">
                    <div className="flex items-center gap-2 text-slate-400">
                        <div className="p-1.5 rounded-full bg-rose-500/20 text-rose-400 border border-rose-500/20">
                            <TrendingDown size={12} strokeWidth={3} />
                        </div>
                        <span className="text-[9px] font-black uppercase tracking-widest">Pending</span>
                    </div>
                    <p className="text-white font-black text-2xl">RM 450.00</p>
                </div>
            </div>
        </div>

        {/* Revenue Chart - Wrapped in Glass Container */}
        <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-900 to-indigo-900 rounded-[2rem] opacity-20 group-hover:opacity-30 blur transition duration-500"></div>
            <div className="relative bg-white/5 border border-white/5 rounded-[2rem] p-6 backdrop-blur-xl shadow-xl">
                <div className="flex justify-between items-center mb-6">
                    <h3 className="text-white font-black text-sm uppercase tracking-widest flex items-center gap-2">
                        <TrendingUp size={16} className="text-cyan-400" /> Revenue Trend
                    </h3>
                    <span className="text-[9px] bg-white/5 px-2 py-1 rounded text-slate-400 font-bold border border-white/5">6 MONTHS</span>
                </div>
                
                <div className="h-40 flex items-end justify-between gap-3 px-2">
                    {chartData.map((val, i) => (
                        <div key={i} className="flex flex-col items-center gap-2 flex-1 group/bar cursor-pointer">
                            <div className="relative w-full bg-slate-800/30 rounded-t-lg h-32 flex items-end overflow-hidden">
                                <div 
                                    className="w-full bg-gradient-to-t from-blue-600 to-cyan-400 transition-all duration-700 ease-spring group-hover/bar:brightness-110"
                                    style={{ height: `${val}%`, opacity: 0.8 }}
                                ></div>
                            </div>
                            <span className="text-[9px] font-bold text-slate-500 uppercase group-hover/bar:text-white transition-colors">{months[i]}</span>
                        </div>
                    ))}
                </div>
            </div>
        </div>

        {/* Expense Breakdown */}
        <div className="relative group">
            <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-900 to-purple-900 rounded-[2rem] opacity-20 group-hover:opacity-30 blur transition duration-500"></div>
            <div className="relative bg-white/5 border border-white/5 rounded-[2rem] p-6 backdrop-blur-xl shadow-xl">
                <h3 className="text-white font-black text-sm uppercase tracking-widest flex items-center gap-2 mb-6">
                    <PieChart size={16} className="text-indigo-400" /> Expense Breakdown
                </h3>
                
                <div className="space-y-5">
                    {[
                        { label: 'Maintenance', val: 45, color: 'bg-rose-500', amount: '2,400' },
                        { label: 'Utilities', val: 30, color: 'bg-cyan-500', amount: '1,600' },
                        { label: 'Insurance', val: 15, color: 'bg-blue-600', amount: '800' },
                        { label: 'Services', val: 10, color: 'bg-slate-500', amount: '530' },
                    ].map((item, i) => (
                        <div key={i} className="group/item">
                            <div className="flex justify-between text-xs font-bold mb-1.5 text-slate-400 group-hover/item:text-white transition-colors">
                                <span>{item.label}</span>
                                <span className="font-mono">RM {item.amount}</span>
                            </div>
                            <div className="h-1.5 w-full bg-slate-800/50 rounded-full overflow-hidden">
                                <div className={`h-full ${item.color} rounded-full shadow-[0_0_10px_currentColor]`} style={{ width: `${item.val}%` }}></div>
                            </div>
                        </div>
                    ))}
                </div>
            </div>
        </div>
    </div>
  );
};
