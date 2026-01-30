
import React, { useState } from 'react';
import { LayoutGrid, Bell, Activity, FileText, Wrench, Users, DollarSign, ChevronRight, Brain, Plus, Shield, Search, Star, ThumbsUp, Heart, Zap } from 'lucide-react';
import { User, LandlordTab } from '../types';
import { LandlordBottomNavBar } from './LandlordBottomNavBar';
import { LandlordFinance } from './LandlordFinance';

interface LandlordDashboardProps {
  user: User;
  onOpenPulse: () => void;
  onOpenLazyLogger: () => void;
  onOpenMaintenance: () => void;
  onOpenLeaseSentinel: () => void;
}

export const LandlordDashboard: React.FC<LandlordDashboardProps> = ({ 
    user, onOpenPulse, onOpenLazyLogger, onOpenMaintenance, onOpenLeaseSentinel 
}) => {
  const [activeTab, setActiveTab] = useState<LandlordTab>('OVERVIEW');

  // Unified Blue/Cyan Theme
  const themeGradient = 'from-blue-900/40 via-slate-950 to-black';

  // --- Sub-Views ---

  const OverviewView = () => (
      <div className="space-y-8 animate-in fade-in slide-in-from-bottom-4 duration-700 pb-32">
            {/* Property Pulse Hero Widget (Matches BalanceCard) */}
            <div className="relative group cursor-pointer" onClick={onOpenPulse}>
                <div className="absolute -inset-0.5 bg-gradient-to-r from-cyan-500 to-blue-600 rounded-[2.5rem] opacity-30 group-hover:opacity-50 blur transition duration-500"></div>
                <div className="relative bg-gradient-to-br from-slate-900/90 via-black/80 to-black/90 border border-white/10 rounded-[2.5rem] p-6 backdrop-blur-xl overflow-hidden shadow-2xl">
                    
                    {/* Ambient Internal Glow */}
                    <div className="absolute top-[-50%] right-[-50%] w-[100%] h-[100%] bg-blue-500/20 blur-[80px] rounded-full pointer-events-none"></div>

                    <div className="relative z-10">
                        <div className="flex justify-between items-start mb-6">
                            <div className="flex items-center gap-2 text-cyan-400">
                                <div className="p-2 bg-cyan-500/10 rounded-xl border border-cyan-500/20">
                                    <Activity size={18} />
                                </div>
                                <span className="text-[10px] font-black uppercase tracking-widest text-slate-300">System Health</span>
                            </div>
                            <span className="bg-emerald-500/10 text-emerald-400 px-3 py-1 rounded-full text-[9px] font-black uppercase border border-emerald-500/20 flex items-center gap-1 shadow-[0_0_10px_rgba(16,185,129,0.2)]">
                                <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></div> Live
                            </span>
                        </div>
                        
                        <div className="flex items-baseline gap-2 mb-6">
                            <span className="text-6xl font-black text-white tracking-tighter drop-shadow-lg">87</span>
                            <span className="text-slate-500 text-sm font-bold uppercase tracking-wider">/ 100 Score</span>
                        </div>

                        <div className="w-full bg-slate-800/50 h-2 rounded-full overflow-hidden mb-6 border border-white/5">
                            <div className="w-[87%] h-full bg-gradient-to-r from-cyan-400 to-blue-500 shadow-[0_0_20px_rgba(34,211,238,0.5)] relative">
                                <div className="absolute inset-0 bg-white/20 animate-[shimmer_2s_infinite]"></div>
                            </div>
                        </div>

                        <div className="grid grid-cols-2 gap-3">
                            <div className="bg-white/5 rounded-2xl p-3 border border-white/5 flex items-center justify-between group/stat hover:bg-white/10 transition-colors">
                                <span className="text-[9px] text-slate-400 font-bold uppercase tracking-wider">Open Issues</span>
                                <span className="text-white font-black text-sm flex items-center gap-1">2 <span className="w-1.5 h-1.5 rounded-full bg-rose-500"></span></span>
                            </div>
                            <div className="bg-white/5 rounded-2xl p-3 border border-white/5 flex items-center justify-between group/stat hover:bg-white/10 transition-colors">
                                <span className="text-[9px] text-slate-400 font-bold uppercase tracking-wider">Collections</span>
                                <span className="text-cyan-400 font-black text-sm">100%</span>
                            </div>
                        </div>
                    </div>
                </div>
            </div>

            {/* Reputation Card (NEW) */}
            <div className="relative group">
                <div className="absolute -inset-0.5 bg-gradient-to-r from-amber-500 to-yellow-500 rounded-[2.5rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                <div className="relative bg-[#0a0a15]/90 border border-amber-500/20 rounded-[2.5rem] p-6 backdrop-blur-xl shadow-xl overflow-hidden">
                    <div className="flex justify-between items-center mb-6">
                        <div className="flex items-center gap-3">
                            <div className="h-10 w-10 rounded-xl bg-amber-500/20 text-amber-400 flex items-center justify-center border border-amber-500/30">
                                <Star size={20} fill="currentColor" />
                            </div>
                            <div>
                                <h3 className="text-white font-black text-sm uppercase tracking-tight">Reputation</h3>
                                <p className="text-slate-500 text-[10px] font-bold uppercase tracking-wider">Tenant Feedback</p>
                            </div>
                        </div>
                        <div className="text-right">
                            <span className="text-3xl font-black text-white leading-none">4.9</span>
                            <span className="text-amber-400 text-[10px] font-bold block">128 Reviews</span>
                        </div>
                    </div>

                    <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
                        {[
                            { label: 'Steady Lah', icon: <ThumbsUp size={12} />, count: 42, color: 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' },
                            { label: 'Fast Fixer', icon: <Zap size={12} />, count: 35, color: 'bg-yellow-500/10 text-yellow-400 border-yellow-500/20' },
                            { label: 'Friendly', icon: <Heart size={12} />, count: 28, color: 'bg-rose-500/10 text-rose-400 border-rose-500/20' },
                        ].map((badge, i) => (
                            <div key={i} className={`flex items-center gap-2 px-3 py-2 rounded-xl border whitespace-nowrap ${badge.color}`}>
                                {badge.icon}
                                <span className="text-[10px] font-bold uppercase">{badge.label}</span>
                                <span className="bg-black/20 px-1.5 rounded text-[9px] font-black">{badge.count}</span>
                            </div>
                        ))}
                    </div>
                </div>
            </div>

            {/* Management List (Matches ReportWidget) */}
            <div>
                <h3 className="text-slate-500 text-[10px] font-black uppercase tracking-[0.2em] mb-4 px-2">Operations</h3>
                <div className="space-y-4">
                    <div className="relative group">
                        <div className="absolute -inset-0.5 bg-gradient-to-r from-rose-500 to-orange-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                        <button 
                            onClick={onOpenMaintenance}
                            className="relative w-full bg-white/5 border border-white/10 hover:bg-white/10 rounded-[2rem] p-5 flex items-center justify-between backdrop-blur-xl transition-all active:scale-[0.98]"
                        >
                            <div className="flex items-center gap-4">
                                <div className="h-12 w-12 bg-rose-500/10 rounded-2xl flex items-center justify-center text-rose-400 border border-rose-500/20 shadow-lg shadow-rose-900/20 group-hover:scale-110 transition-transform duration-300">
                                    <Wrench size={22} />
                                </div>
                                <div className="text-left">
                                    <span className="text-white font-black text-sm block tracking-tight">Maintenance</span>
                                    <span className="text-rose-400 text-[10px] font-bold uppercase tracking-wider">2 Pending Tickets</span>
                                </div>
                            </div>
                            <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-white transition-colors">
                                <ChevronRight size={16} />
                            </div>
                        </button>
                    </div>

                    <div className="relative group">
                        <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-blue-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                        <button className="relative w-full bg-white/5 border border-white/10 hover:bg-white/10 rounded-[2rem] p-5 flex items-center justify-between backdrop-blur-xl transition-all active:scale-[0.98]">
                            <div className="flex items-center gap-4">
                                <div className="h-12 w-12 bg-indigo-500/10 rounded-2xl flex items-center justify-center text-indigo-400 border border-indigo-500/20 shadow-lg shadow-indigo-900/20 group-hover:scale-110 transition-transform duration-300">
                                    <Users size={22} />
                                </div>
                                <div className="text-left">
                                    <span className="text-white font-black text-sm block tracking-tight">Tenants</span>
                                    <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider">3 Units Occupied</span>
                                </div>
                            </div>
                            <div className="h-8 w-8 rounded-full bg-white/5 flex items-center justify-center text-slate-500 group-hover:text-white transition-colors">
                                <ChevronRight size={16} />
                            </div>
                        </button>
                    </div>
                </div>
            </div>
            
            {/* Quick Actions Grid (Matches SummaryCards) */}
            <div className="grid grid-cols-2 gap-4">
                 <div className="relative group h-full">
                     <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-500 to-cyan-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                     <button 
                        onClick={() => setActiveTab('AI_TOOLS')} 
                        className="relative w-full h-full p-5 rounded-[2rem] bg-white/5 border border-white/10 hover:bg-white/10 backdrop-blur-xl text-left flex flex-col justify-between min-h-[140px] transition-all active:scale-95"
                     >
                         <div className="h-10 w-10 rounded-xl bg-blue-500/20 text-blue-400 flex items-center justify-center mb-3 border border-blue-500/20 shadow-lg">
                            <Brain size={20} />
                         </div>
                         <div>
                            <div className="text-white font-black text-sm mb-1">AI Assistant</div>
                            <div className="text-blue-400/80 text-[10px] uppercase font-bold tracking-wider">Lazy Logger</div>
                         </div>
                     </button>
                 </div>

                 <div className="relative group h-full">
                     <div className="absolute -inset-0.5 bg-gradient-to-r from-emerald-500 to-teal-500 rounded-[2rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
                     <button 
                        onClick={() => setActiveTab('FINANCE')} 
                        className="relative w-full h-full p-5 rounded-[2rem] bg-white/5 border border-white/10 hover:bg-white/10 backdrop-blur-xl text-left flex flex-col justify-between min-h-[140px] transition-all active:scale-95"
                     >
                         <div className="h-10 w-10 rounded-xl bg-emerald-500/20 text-emerald-400 flex items-center justify-center mb-3 border border-emerald-500/20 shadow-lg">
                            <DollarSign size={20} />
                         </div>
                         <div>
                            <div className="text-white font-black text-sm mb-1">Financials</div>
                            <div className="text-emerald-400/80 text-[10px] uppercase font-bold tracking-wider">Revenue</div>
                         </div>
                     </button>
                 </div>
            </div>
      </div>
  );

  const PropertiesView = () => (
      <div className="space-y-6 animate-in fade-in slide-in-from-right-8 duration-500 pb-32">
          <div className="flex justify-between items-center px-1">
              <h3 className="text-slate-500 text-[10px] font-black uppercase tracking-[0.2em]">Portfolio</h3>
              <button className="text-cyan-400 text-[10px] font-black uppercase flex items-center gap-1 hover:text-cyan-300 bg-cyan-500/10 px-3 py-1.5 rounded-full border border-cyan-500/20 transition-all active:scale-95">
                  <Plus size={12} /> Add Unit
              </button>
          </div>
          
          <div className="space-y-4">
            {[
                { name: 'Verdi Eco-Dominium', unit: 'Unit 4-2', status: 'Occupied', tenant: 'Ali Rahman', rent: 'PAID' },
                { name: 'The Grand Subang', unit: 'Block B-12', status: 'Occupied', tenant: 'Sarah Tan', rent: 'PENDING' },
                { name: 'Arcuz Kelana Jaya', unit: 'Unit 08-01', status: 'Vacant', tenant: '-', rent: '-' },
            ].map((prop, i) => (
                <div key={i} className="relative group">
                    <div className="absolute -inset-0.5 bg-gradient-to-r from-blue-600 to-indigo-600 rounded-[2rem] opacity-10 group-hover:opacity-30 blur transition duration-500"></div>
                    <div className="relative bg-white/5 border border-white/10 rounded-[2rem] p-5 hover:bg-white/10 transition-all backdrop-blur-xl">
                        <div className="flex justify-between items-start mb-4">
                            <div className="flex items-center gap-4">
                                <div className="h-12 w-12 rounded-2xl bg-slate-800 border border-white/10 flex items-center justify-center shadow-lg">
                                    <LayoutGrid size={20} className="text-slate-400" />
                                </div>
                                <div>
                                    <h4 className="text-white font-black text-sm tracking-tight">{prop.name}</h4>
                                    <p className="text-slate-400 text-xs font-medium">{prop.unit}</p>
                                </div>
                            </div>
                            <span className={`px-2 py-1 rounded-lg text-[9px] font-black uppercase border ${
                                prop.status === 'Occupied' 
                                    ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' 
                                    : 'bg-slate-800 text-slate-500 border-slate-700'
                            }`}>
                                {prop.status}
                            </span>
                        </div>
                        
                        {prop.status === 'Occupied' && (
                            <div className="flex items-center justify-between pt-4 border-t border-white/5">
                                <div className="flex items-center gap-2">
                                    <div className="h-6 w-6 rounded-full bg-slate-700 flex items-center justify-center text-[9px] font-bold text-white border border-slate-600">
                                        {prop.tenant.substring(0,2)}
                                    </div>
                                    <span className="text-slate-300 text-xs font-bold">{prop.tenant}</span>
                                </div>
                                <span className={`text-[9px] font-black uppercase tracking-wider ${prop.rent === 'PAID' ? 'text-cyan-400' : 'text-amber-400'}`}>
                                    Rent: {prop.rent}
                                </span>
                            </div>
                        )}
                    </div>
                </div>
            ))}
          </div>
      </div>
  );

  const AIToolsView = () => (
      <div className="space-y-6 animate-in fade-in slide-in-from-right-8 duration-500 pb-32">
          {/* Header Card */}
          <div className="relative group">
              <div className="absolute -inset-0.5 bg-gradient-to-r from-indigo-500 to-purple-600 rounded-[2.5rem] opacity-20 group-hover:opacity-40 blur transition duration-500"></div>
              <div className="relative bg-gradient-to-br from-indigo-900/40 to-slate-950 border border-white/10 rounded-[2.5rem] p-8 text-center backdrop-blur-xl shadow-2xl overflow-hidden">
                  <div className="absolute top-[-50%] left-[20%] w-full h-full bg-indigo-500/10 blur-[80px] rounded-full pointer-events-none"></div>
                  <div className="relative z-10">
                      <div className="h-16 w-16 bg-indigo-500/20 rounded-2xl flex items-center justify-center mx-auto mb-4 text-indigo-400 border border-indigo-500/30 shadow-lg shadow-indigo-900/20">
                        <Brain size={32} />
                      </div>
                      <h2 className="text-3xl font-black text-white mb-2 tracking-tight">AI Command</h2>
                      <p className="text-indigo-200/60 text-xs font-medium max-w-xs mx-auto leading-relaxed">
                          Automate property management tasks with our generative AI suite.
                      </p>
                  </div>
              </div>
          </div>

          <div className="grid grid-cols-1 gap-4">
                {/* Lazy Logger Button */}
                <div className="relative group">
                    <div className="absolute -inset-0.5 bg-gradient-to-r from-amber-500 to-orange-500 rounded-[2rem] opacity-10 group-hover:opacity-30 blur transition duration-500"></div>
                    <button 
                        onClick={onOpenLazyLogger}
                        className="relative w-full bg-white/5 border border-white/10 hover:bg-white/10 rounded-[2rem] p-6 text-left flex items-center gap-5 backdrop-blur-xl transition-all active:scale-[0.98]"
                    >
                        <div className="h-14 w-14 bg-amber-500/10 text-amber-400 rounded-2xl flex items-center justify-center border border-amber-500/20 shadow-lg group-hover:scale-110 transition-transform duration-300">
                            <FileText size={24} />
                        </div>
                        <div className="flex-1">
                            <h3 className="text-white font-black text-base mb-1 group-hover:text-amber-200 transition-colors">Lazy Logger</h3>
                            <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wide">Document Indexer</p>
                        </div>
                        <ChevronRight size={20} className="text-slate-500 group-hover:text-white" />
                    </button>
                </div>

                {/* Lease Sentinel Button */}
                <div className="relative group">
                    <div className="absolute -inset-0.5 bg-gradient-to-r from-purple-500 to-pink-500 rounded-[2rem] opacity-10 group-hover:opacity-30 blur transition duration-500"></div>
                    <button 
                        onClick={onOpenLeaseSentinel}
                        className="relative w-full bg-white/5 border border-white/10 hover:bg-white/10 rounded-[2rem] p-6 text-left flex items-center gap-5 backdrop-blur-xl transition-all active:scale-[0.98]"
                    >
                        <div className="h-14 w-14 bg-purple-500/10 text-purple-400 rounded-2xl flex items-center justify-center border border-purple-500/20 shadow-lg group-hover:scale-110 transition-transform duration-300">
                            <Shield size={24} />
                        </div>
                        <div className="flex-1">
                            <h3 className="text-white font-black text-base mb-1 group-hover:text-purple-200 transition-colors">Lease Sentinel</h3>
                            <p className="text-[10px] text-slate-400 font-bold uppercase tracking-wide">Contract Analysis</p>
                        </div>
                        <ChevronRight size={20} className="text-slate-500 group-hover:text-white" />
                    </button>
                </div>
          </div>
      </div>
  );

  return (
    <div className="h-full flex flex-col relative overflow-hidden bg-black font-sans">
        {/* Dynamic Ambient Background - Unified Blue/Cyan Theme */}
        <div 
            className={`absolute top-0 left-0 right-0 h-[600px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] ${themeGradient} pointer-events-none`}
        ></div>

        {/* Content Container */}
        <div className="flex-1 overflow-y-auto no-scrollbar relative z-10 flex flex-col">
            
            {/* Header */}
            <header className="flex flex-col pt-8 pb-6 px-6 gap-6 flex-shrink-0">
                <div className="flex items-center gap-3">
                    <div className="h-10 w-10 rounded-xl bg-blue-600/20 text-blue-400 flex items-center justify-center border border-blue-500/30 shadow-lg shadow-blue-900/20">
                        <LayoutGrid size={20} />
                    </div>
                    <div>
                        <h1 className="text-white font-black text-xl tracking-tight">Asset Command</h1>
                        <p className="text-blue-400/80 text-[10px] font-black uppercase tracking-widest">
                            {activeTab === 'OVERVIEW' ? 'Portfolio Overview' : activeTab === 'FINANCE' ? 'Financial Analytics' : activeTab === 'PROPERTIES' ? 'Property List' : 'AI Tools'}
                        </p>
                    </div>
                </div>

                <div className="flex justify-between items-center">
                    <div className="flex items-center gap-3">
                        <div className={`h-12 w-12 rounded-full flex items-center justify-center text-white font-bold text-sm overflow-hidden border-2 border-blue-500/30 bg-slate-800`}>
                            {user.avatarInitials}
                        </div>
                        <div className="flex flex-col">
                            <span className="text-white font-bold text-lg leading-tight tracking-tight">{user.name}</span>
                            <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider">Property Owner</span>
                        </div>
                    </div>
                    <button className="h-10 w-10 rounded-2xl bg-white/5 border border-white/10 flex items-center justify-center text-slate-400 backdrop-blur-md transition-all active:scale-95 hover:text-white hover:bg-white/10">
                        <Bell size={18} />
                    </button>
                </div>
            </header>

            {/* Dynamic Content */}
            <div className="px-6 flex-1">
                {activeTab === 'OVERVIEW' && <OverviewView />}
                {activeTab === 'FINANCE' && <LandlordFinance />}
                {activeTab === 'PROPERTIES' && <PropertiesView />}
                {activeTab === 'AI_TOOLS' && <AIToolsView />}
            </div>

        </div>

        {/* Bottom Navigation */}
        <LandlordBottomNavBar activeTab={activeTab} onTabChange={setActiveTab} />
    </div>
  );
};
