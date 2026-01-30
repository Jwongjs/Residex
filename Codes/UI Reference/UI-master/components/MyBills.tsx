import React, { useState } from 'react';
import { ArrowLeft, Search, Users, Calendar, FileText } from 'lucide-react';
import { Bill, FilterType } from '../types';
import { FilterSection } from './FilterSection';

interface MyBillsProps {
  bills: Bill[];
  onBack: () => void;
  onViewDetails: (bill: Bill) => void;
}

export const MyBills: React.FC<MyBillsProps> = ({ bills, onBack, onViewDetails }) => {
  const [filter, setFilter] = useState<FilterType>(FilterType.ALL);
  const [searchQuery, setSearchQuery] = useState('');

  const filteredBills = bills.filter(bill => {
    // 1. Text Search
    if (searchQuery && !bill.title.toLowerCase().includes(searchQuery.toLowerCase()) && !bill.location.toLowerCase().includes(searchQuery.toLowerCase())) {
        return false;
    }

    // 2. Category Filter
    if (filter === FilterType.ALL) return true;
    if (filter === FilterType.GROUPS) return true; // Mock logic, assuming all for now
    if (filter === FilterType.PENDING) return bill.status === 'PENDING';
    if (filter === FilterType.SETTLED) return bill.status === 'SETTLED';
    return true;
  });

  return (
    <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
        {/* Header Section (Sticky) */}
        <div className="flex flex-col pt-6 pb-2 gap-4 sticky top-0 z-30 bg-[#020617]/95 backdrop-blur-sm transition-all px-4 sm:px-6 border-b border-white/5">
             {/* Top Bar */}
             <div className="flex items-center gap-4">
                <button
                    onClick={onBack}
                    className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md group"
                >
                    <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
                </button>
                <div>
                    <h1 className="text-white font-bold text-xl tracking-tight">My Bills</h1>
                    <p className="text-slate-400 text-xs">Track payments & expenses</p>
                </div>
             </div>

             {/* Search */}
             <div className="relative">
                <div className="absolute left-4 top-3.5 text-slate-500">
                    <Search size={18} />
                </div>
                <input
                    type="text"
                    value={searchQuery}
                    onChange={(e) => setSearchQuery(e.target.value)}
                    placeholder="Search bills..."
                    className="w-full bg-slate-800/50 border border-white/10 rounded-2xl py-3.5 pl-11 pr-4 text-white placeholder-slate-500 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/50 transition-all shadow-inner shadow-black/20"
                />
             </div>

             {/* Filters */}
             <div className="-mx-2">
                <FilterSection activeFilter={filter} onFilterChange={setFilter} />
             </div>
        </div>

        {/* List */}
        <div className="flex-1 overflow-y-auto no-scrollbar px-4 sm:px-6 pb-10 space-y-5 pt-4">
            {filteredBills.length === 0 ? (
                <div className="flex flex-col items-center justify-center py-20 opacity-50 space-y-4">
                    <div className="h-20 w-20 bg-slate-800 rounded-full flex items-center justify-center text-slate-600">
                        <FileText size={32} />
                    </div>
                    <p className="text-slate-400 font-medium">No bills found.</p>
                </div>
            ) : (
                filteredBills.map((bill, index) => (
                    <div 
                        key={bill.id} 
                        className="bg-slate-800/50 backdrop-blur-xl rounded-[2.5rem] overflow-hidden shadow-lg shadow-black/30 border border-white/15 hover:border-white/25 hover:bg-slate-700/50 transition-all duration-300 transform hover:-translate-y-1 group ring-1 ring-white/5 animate-in slide-in-from-bottom-4" 
                        style={{ animationDelay: `${index * 50}ms`}}
                    >
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
                ))
            )}
        </div>
    </div>
  );
};