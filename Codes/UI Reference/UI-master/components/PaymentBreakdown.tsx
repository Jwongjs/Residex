import React, { useState, useMemo, useEffect } from 'react';
import { ArrowLeft, Wallet, Zap, User as UserIcon, Users, FileText, CheckCircle, ArrowUpRight, ArrowDownLeft, History, Calendar, Clock, ChevronRight, CheckSquare, Square, Filter, SlidersHorizontal, Layers } from 'lucide-react';
import { PAYMENT_OPTIONS, User, BreakdownItem, Group } from '../types';

interface PaymentBreakdownProps {
    mode: 'OWE' | 'OWED' | 'HISTORY';
    items: BreakdownItem[];
    users: User[];
    groups?: Group[];
    onBack: () => void;
    onMarkPaid: (itemId: string) => void;
    onViewBill: (billId: string) => void;
    initialTab?: 'PENDING' | 'HISTORY';
    initialSelectedEntityId?: string | null;
}

type FilterView = 'ALL' | 'PERSON' | 'GROUP' | 'BILL';

export const PaymentBreakdown: React.FC<PaymentBreakdownProps> = ({ 
    mode, items, users, groups = [], onBack, onMarkPaid, onViewBill, initialTab = 'PENDING', initialSelectedEntityId = null
}) => {
    
    const [activeTab, setActiveTab] = useState<'PENDING' | 'HISTORY'>(mode === 'HISTORY' ? 'HISTORY' : initialTab || 'PENDING');
    const [filterView, setFilterView] = useState<FilterView>(initialSelectedEntityId ? (groups.some(g => g.id === initialSelectedEntityId) ? 'GROUP' : 'PERSON') : 'ALL');
    const [selectedEntityId, setSelectedEntityId] = useState<string | null>(initialSelectedEntityId);
    const [exitingItems, setExitingItems] = useState<Set<string>>(new Set());
    
    // Batch Payment State
    const [selectedBatchIds, setSelectedBatchIds] = useState<Set<string>>(new Set());
    const [isSelectionMode, setIsSelectionMode] = useState(false);
    
    // Simplification Toggle
    const [isSimplified, setIsSimplified] = useState(false);

    useEffect(() => {
        setExitingItems(new Set());
        setSelectedBatchIds(new Set());
        setIsSelectionMode(false);
    }, [activeTab, filterView, selectedEntityId]);

    const getMethodDetails = (id: string) => PAYMENT_OPTIONS.find(p => p.id === id);
    const getUser = (id: string) => users.find(u => u.id === id);
    const getGroup = (id: string) => groups.find(g => g.id === id);

    const handleMarkPaidClick = (itemId: string) => {
        setExitingItems(prev => new Set(prev).add(itemId));
        setTimeout(() => {
            onMarkPaid(itemId);
        }, 400); 
    };

    const handleBatchPay = () => {
        selectedBatchIds.forEach(id => {
            handleMarkPaidClick(id);
        });
        setIsSelectionMode(false);
        setSelectedBatchIds(new Set());
    };

    const toggleBatchSelection = (id: string) => {
        const newSet = new Set(selectedBatchIds);
        if (newSet.has(id)) newSet.delete(id);
        else newSet.add(id);
        setSelectedBatchIds(newSet);
    };

    const statusFilteredItems = items.filter(item => {
        // If we have an entity selected in "History" mode (like Group Summary), show everything.
        if (selectedEntityId && activeTab === 'HISTORY') return true;
        if (mode === 'HISTORY') return true;
        return activeTab === 'PENDING' ? item.status === 'PENDING' : item.status !== 'PENDING';
    });

    const displayItems: BreakdownItem[] = useMemo(() => {
        if (!selectedEntityId) return statusFilteredItems;
        if (filterView === 'PERSON') return statusFilteredItems.filter(i => i.userId === selectedEntityId);
        if (filterView === 'GROUP') return statusFilteredItems.filter(i => i.groupId === selectedEntityId);
        if (filterView === 'BILL') return statusFilteredItems.filter(i => i.billId === selectedEntityId);
        return statusFilteredItems;
    }, [statusFilteredItems, selectedEntityId, filterView]);

    const totalAmount = displayItems.reduce((sum, item) => sum + item.amount, 0);

    // --- Branching Tree View Component ---
    const BranchingTree = () => {
        const entityDetails = useMemo(() => {
            if (filterView === 'PERSON') {
                const u = getUser(selectedEntityId!);
                return { name: u?.name, icon: u?.avatarInitials, color: u?.color, type: 'person', img: u?.profileImage };
            }
            if (filterView === 'GROUP') {
                const g = getGroup(selectedEntityId!);
                return { name: g?.name, icon: g?.emoji, color: g?.color, type: 'group' };
            }
            return null;
        }, [selectedEntityId, filterView]);

        if (!entityDetails) return null;

        // Simplified View Logic
        const showSimplified = isSimplified && displayItems.length > 1;
        
        return (
            <div className="relative pt-4 pb-32 px-2 min-h-[600px]">
                
                {/* 1. Core Node (Top Center) */}
                <div className="flex justify-center mb-0 relative z-20">
                    <div className="flex flex-col items-center gap-3 animate-in zoom-in-50 fade-in duration-700 ease-spring">
                         <div className={`
                            h-24 w-24 rounded-full flex items-center justify-center text-3xl font-bold text-white 
                            shadow-[0_0_60px_rgba(34,211,238,0.3)] ring-4 ring-black z-20 relative
                            ${entityDetails.color || 'bg-slate-700'}
                         `}>
                            {entityDetails.img ? (
                                <img src={entityDetails.img} alt={entityDetails.name} className="w-full h-full object-cover rounded-full" />
                            ) : entityDetails.icon}
                         </div>
                         
                         <div className="text-center bg-slate-900/80 backdrop-blur-md px-5 py-2 rounded-2xl border border-white/10 shadow-xl transform translate-y-[-10px]">
                             <h2 className="text-lg font-bold text-white leading-tight">{entityDetails.name}</h2>
                             <p className="text-cyan-400 text-xs font-mono font-bold mt-0.5">Total RM: {totalAmount.toFixed(2)}</p>
                         </div>
                    </div>
                </div>

                {/* Batch Actions Bar */}
                {!showSimplified && activeTab === 'PENDING' && (
                    <div className="flex justify-center my-6 z-20 relative">
                        <button 
                            onClick={() => setIsSelectionMode(!isSelectionMode)}
                            className={`flex items-center gap-2 px-4 py-2 rounded-full border text-xs font-bold transition-all
                                ${isSelectionMode ? 'bg-cyan-500 text-white border-cyan-400' : 'bg-slate-800/50 text-slate-300 border-white/10 hover:bg-white/10'}
                            `}
                        >
                            <CheckSquare size={14} />
                            {isSelectionMode ? 'Cancel Selection' : 'Select to Pay'}
                        </button>
                    </div>
                )}

                {/* 2. Central Trunk */}
                <div className="relative">
                    <div className="absolute left-1/2 -translate-x-1/2 top-[-20px] bottom-0 w-[2px] z-0">
                        <div className="w-full h-full bg-gradient-to-b from-cyan-400 via-blue-600 to-transparent shadow-[0_0_15px_rgba(34,211,238,0.6)] origin-top animate-[growHeight_1s_ease-out_forwards]"></div>
                    </div>

                    {/* Simplified View Card */}
                    {showSimplified ? (
                        <div className="pt-12 relative z-10 flex justify-center animate-in fade-in slide-in-from-bottom-8">
                            <div className="bg-gradient-to-br from-slate-800 to-slate-900 border border-cyan-500/30 p-6 rounded-[2rem] shadow-2xl w-[90%] text-center relative overflow-hidden">
                                <div className="absolute top-0 right-0 w-32 h-32 bg-cyan-500/10 rounded-full blur-[40px]"></div>
                                <h3 className="text-slate-400 text-xs font-bold uppercase tracking-wider mb-2">Simplified Debt</h3>
                                <p className="text-sm text-slate-300 mb-4">Instead of {displayItems.length} transactions, you just pay:</p>
                                <div className="text-4xl font-black text-white mb-6">RM {totalAmount.toFixed(2)}</div>
                                
                                {activeTab === 'PENDING' && (
                                    <button 
                                        onClick={() => {
                                             displayItems.forEach(i => handleMarkPaidClick(i.id));
                                        }}
                                        className="w-full bg-cyan-500 hover:bg-cyan-400 text-white font-bold py-3 rounded-xl shadow-lg shadow-cyan-500/20 transition-all active:scale-95"
                                    >
                                        Settle Net Amount
                                    </button>
                                )}
                            </div>
                        </div>
                    ) : (
                        /* Standard Item Grid */
                        <div className="space-y-6 relative z-10 pt-8">
                            {displayItems.map((item, idx) => {
                                const method = getMethodDetails(item.paymentMethodId);
                                const isLeft = idx % 2 === 0;
                                const isExiting = exitingItems.has(item.id);
                                const isSelected = selectedBatchIds.has(item.id);
                                const delay = idx * 100 + 200; 

                                return (
                                    <div 
                                        key={item.id} 
                                        className={`relative flex w-full ${isLeft ? 'justify-start' : 'justify-end'} ${isExiting ? 'opacity-0 scale-95 transition-all duration-300' : ''}`}
                                    >
                                        {/* Connection Branch */}
                                        <div 
                                            className={`absolute top-[40px] h-[2px] bg-gradient-to-r from-cyan-500/50 to-cyan-400/20 shadow-[0_0_8px_rgba(34,211,238,0.4)]
                                                ${isLeft ? 'right-1/2 w-[10%] sm:w-[15%] origin-right' : 'left-1/2 w-[10%] sm:w-[15%] origin-left'}
                                            `}
                                            style={{ 
                                                animation: `growWidth 0.6s ease-out forwards ${delay}ms`,
                                                transform: 'scaleX(0)' 
                                            }}
                                        >
                                            <div className={`absolute w-1.5 h-1.5 bg-cyan-400 rounded-full shadow-[0_0_10px_cyan] top-1/2 -translate-y-1/2 ${isLeft ? 'right-0' : 'left-0'}`}></div>
                                        </div>

                                        {/* The Card */}
                                        <button 
                                            onClick={() => {
                                                if (isSelectionMode) toggleBatchSelection(item.id);
                                                else if(item.billId) onViewBill(item.billId);
                                            }}
                                            className={`
                                                w-[45%] sm:w-[42%] bg-slate-900/60 backdrop-blur-xl border p-3.5 rounded-2xl shadow-lg relative group text-left transition-all duration-300
                                                ${isSelected 
                                                    ? 'border-cyan-400 bg-cyan-950/30 shadow-[0_0_15px_rgba(34,211,238,0.1)] scale-105' 
                                                    : 'border-white/10 hover:bg-slate-800/80 hover:border-cyan-500/30 hover:scale-[1.02]'}
                                            `}
                                            style={{ 
                                                animation: `fadeInUp 0.6s cubic-bezier(0.16, 1, 0.3, 1) forwards ${delay + 100}ms`
                                            }}
                                        >
                                            {/* Status Badge */}
                                            {item.status === 'PAID' && (
                                                <div className="absolute top-2 right-2 text-emerald-400">
                                                    <CheckCircle size={12} />
                                                </div>
                                            )}

                                            <div className="mb-2">
                                                <div className="flex items-start justify-between">
                                                    <h3 className="text-white font-bold text-xs leading-snug line-clamp-2 mb-1 flex-1 pr-2">{item.billTitle || 'Bill'}</h3>
                                                </div>
                                                <div className="text-lg font-black text-white leading-none">
                                                    <span className="text-[10px] text-slate-500 mr-0.5">RM</span>
                                                    {item.amount.toFixed(2)}
                                                </div>
                                            </div>

                                            <div className="space-y-1.5 border-t border-white/5 pt-2">
                                                <div className="flex items-center gap-1.5 text-[10px] text-slate-400">
                                                    <Calendar size={10} className="text-cyan-600" />
                                                    <span className="truncate">{item.date}</span>
                                                </div>
                                            </div>

                                            {/* Action Button (Only for Pending & Not Selection Mode) */}
                                            {!isSelectionMode && item.status === 'PENDING' && (
                                                <div 
                                                    onClick={(e) => {
                                                        e.stopPropagation();
                                                        handleMarkPaidClick(item.id);
                                                    }}
                                                    className="w-full mt-3 py-1.5 bg-white/5 hover:bg-cyan-500/20 text-slate-400 hover:text-cyan-300 rounded-lg text-[10px] font-bold transition-all border border-transparent hover:border-cyan-500/30 flex items-center justify-center gap-1.5 cursor-pointer"
                                                >
                                                    Mark Paid
                                                </div>
                                            )}
                                        </button>
                                    </div>
                                );
                            })}
                        </div>
                    )}
                </div>

                <style>{`
                    @keyframes growHeight {
                        from { height: 0; opacity: 0; }
                        to { height: 100%; opacity: 1; }
                    }
                    @keyframes growWidth {
                        from { transform: scaleX(0); opacity: 0; }
                        to { transform: scaleX(1); opacity: 1; }
                    }
                    @keyframes fadeInUp {
                        from { opacity: 0; transform: translateY(20px) scale(0.95); }
                        to { opacity: 1; transform: translateY(0) scale(1); }
                    }
                `}</style>
            </div>
        );
    };

    // --- Render List View Logic ---
    const renderListView = () => {
        let content;

        if (filterView === 'PERSON') {
             const personIds = Array.from(new Set(displayItems.map(i => i.userId))) as string[];
             content = (
                <div className="grid grid-cols-2 gap-3">
                    {personIds.map(uid => {
                        const user = getUser(uid);
                        const userTotal = displayItems.filter(i => i.userId === uid).reduce((sum, i) => sum + i.amount, 0);
                        return (
                            <button 
                                key={uid} 
                                onClick={() => setSelectedEntityId(uid)}
                                className="bg-slate-800/40 border border-white/10 rounded-2xl p-4 flex flex-col items-center gap-3 hover:bg-slate-700/50 transition-all active:scale-95 group"
                            >
                                <div className={`h-14 w-14 rounded-full flex items-center justify-center text-lg font-bold text-white shadow-lg ${user?.color || 'bg-slate-600'} group-hover:scale-110 transition-transform`}>
                                    {user?.avatarInitials}
                                </div>
                                <div className="text-center">
                                    <div className="text-white font-bold text-sm truncate w-full">{user?.name.split(' ')[0]}</div>
                                    <div className="text-cyan-400 font-mono text-xs font-bold mt-1">RM{userTotal.toFixed(2)}</div>
                                </div>
                            </button>
                        );
                    })}
                </div>
             );
        } else if (filterView === 'GROUP') {
             const groupIds = Array.from(new Set(displayItems.map(i => i.groupId).filter((id): id is string => typeof id === 'string')));
             content = (
                <div className="space-y-3">
                    {groupIds.map(gid => {
                        const group = getGroup(gid);
                        const groupTotal = displayItems.filter(i => i.groupId === gid).reduce((sum, i) => sum + i.amount, 0);
                        return (
                             <button 
                                key={gid} 
                                onClick={() => setSelectedEntityId(gid)}
                                className="w-full bg-slate-800/40 border border-white/10 rounded-2xl p-4 flex items-center justify-between hover:bg-slate-700/50 transition-all active:scale-95 group"
                            >
                                <div className="flex items-center gap-3">
                                    <div className={`h-12 w-12 rounded-xl flex items-center justify-center text-xl shadow-lg ${group?.color || 'bg-slate-600'} group-hover:scale-110 transition-transform`}>
                                        {group?.emoji || '👥'}
                                    </div>
                                    <div className="text-left">
                                        <div className="text-white font-bold text-base">{group?.name || 'Unknown Group'}</div>
                                        <div className="text-slate-400 text-xs">{displayItems.filter(i => i.groupId === gid).length} items</div>
                                    </div>
                                </div>
                                <div className="text-cyan-400 font-mono text-base font-bold">RM{groupTotal.toFixed(2)}</div>
                            </button>
                        );
                    })}
                </div>
             );
        } else {
             content = (
                 <div className="space-y-4">
                    {displayItems.map((item, index) => {
                        const user = getUser(item.userId);
                        const method = getMethodDetails(item.paymentMethodId);
                        if (!user || !method) return null;
                        const isExiting = exitingItems.has(item.id);

                        return (
                            <button 
                                key={item.id}
                                onClick={() => item.billId && onViewBill(item.billId)}
                                className={`
                                    w-full text-left group relative overflow-hidden rounded-[2rem] bg-slate-800/40 border border-white/10 hover:border-white/20 transition-all duration-300 active:scale-[0.98]
                                    ${isExiting ? 'translate-x-full opacity-0' : 'animate-in slide-in-from-bottom-4'}
                                `}
                                style={{ animationDelay: `${index * 75}ms` }}
                            >
                                <div className={`absolute left-0 top-0 bottom-0 w-1.5 bg-gradient-to-b ${method.color || 'from-slate-500 to-slate-700'}`}></div>
                                <div className="p-5 pl-6 relative z-10">
                                    <div className="flex items-center justify-between mb-2">
                                        <div className="flex items-center gap-3">
                                            <div className={`h-10 w-10 rounded-full flex items-center justify-center text-xs font-bold text-white shadow-lg ring-1 ring-white/10 ${user.color || 'bg-slate-600'}`}>
                                                {user.avatarInitials}
                                            </div>
                                            <div>
                                                <div className="font-bold text-white text-base leading-tight">{user.name}</div>
                                                <div className="text-[10px] text-slate-500 mt-0.5">{item.date}</div>
                                            </div>
                                        </div>
                                        <div className="text-right">
                                            <span className={`block font-black text-lg tracking-tight ${mode === 'OWE' ? 'text-rose-200' : 'text-emerald-200'}`}>
                                                <span className="text-xs text-slate-500 mr-1 font-bold">RM</span>
                                                {item.amount.toFixed(2)}
                                            </span>
                                        </div>
                                    </div>
                                     {activeTab === 'PENDING' && (
                                        <div 
                                            onClick={(e) => {
                                                e.stopPropagation();
                                                handleMarkPaidClick(item.id);
                                            }}
                                            className="mt-2 ml-14 w-fit px-3 py-1 bg-white/5 hover:bg-cyan-500/20 text-slate-400 hover:text-cyan-300 rounded-lg text-[10px] font-bold transition-all cursor-pointer border border-transparent hover:border-cyan-500/30"
                                        >
                                            Mark Paid
                                        </div>
                                    )}
                                </div>
                            </button>
                        );
                    })}
                 </div>
             )
        }

        return content;
    };

    return (
        <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500 relative">
            <div className="fixed inset-0 z-0 pointer-events-none overflow-hidden">
                <div className="absolute top-[-10%] left-[-20%] w-[120vw] h-[100vw] bg-purple-600/10 rounded-full blur-[100px] animate-pulse-simple mix-blend-screen"></div>
                <div className="absolute bottom-[-10%] right-[-20%] w-[120vw] h-[100vw] bg-blue-600/10 rounded-full blur-[100px] animate-pulse-simple mix-blend-screen" style={{ animationDelay: '1s' }}></div>
            </div>

            <div className="flex flex-col pt-6 pb-2 sticky top-0 z-30 bg-[#020617]/90 backdrop-blur-xl gap-4 px-4 sm:px-6 border-b border-white/5 transition-all">
                <div className="flex items-center justify-between">
                    <div className="flex items-center gap-4">
                        <button
                            onClick={() => {
                                if (selectedEntityId) setSelectedEntityId(null);
                                else onBack();
                            }}
                            className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md"
                        >
                            <ArrowLeft size={20} />
                        </button>
                        <div>
                            <h1 className="text-white font-bold text-xl tracking-tight">{selectedEntityId ? 'Armoury' : (mode === 'OWE' ? 'Outgoing' : 'Incoming')}</h1>
                            <p className="text-slate-400 text-xs">{selectedEntityId ? 'Group Summary' : (mode === 'HISTORY' ? 'Transaction Log' : 'Payments')}</p>
                        </div>
                    </div>
                    
                    {selectedEntityId && (
                        <div className="flex gap-2">
                             <button 
                                onClick={() => setIsSimplified(!isSimplified)}
                                className={`h-10 px-3 rounded-full border flex items-center gap-2 text-xs font-bold transition-all ${isSimplified ? 'bg-cyan-500/20 border-cyan-500 text-cyan-400' : 'bg-slate-800 border-white/10 text-slate-400'}`}
                                title="Simplify Debt"
                             >
                                <Layers size={16} />
                                {isSimplified ? 'Simple' : 'Full'}
                             </button>
                        </div>
                    )}
                </div>

                {!selectedEntityId && (
                    <div className="flex gap-2 overflow-x-auto no-scrollbar pb-1">
                        {[
                            { id: 'ALL', label: 'All', icon: <Zap size={14} /> },
                            { id: 'PERSON', label: 'People', icon: <UserIcon size={14} /> },
                            { id: 'GROUP', label: 'Groups', icon: <Users size={14} /> },
                        ].map(tab => (
                            <button
                                key={tab.id}
                                onClick={() => setFilterView(tab.id as FilterView)}
                                className={`
                                    flex items-center gap-1.5 px-4 py-2 rounded-xl text-xs font-bold whitespace-nowrap border transition-all
                                    ${filterView === tab.id 
                                        ? 'bg-cyan-950 text-cyan-400 border-cyan-500/50 shadow-lg shadow-cyan-900/20' 
                                        : 'bg-slate-800/50 text-slate-400 border-white/5 hover:bg-white/10'}
                                `}
                            >
                                {tab.icon}
                                {tab.label}
                            </button>
                        ))}
                    </div>
                )}
            </div>

            <div className="flex-1 overflow-y-auto no-scrollbar px-4 sm:px-6 pb-24 space-y-6 pt-4 relative z-10">
                {selectedEntityId && (filterView === 'PERSON' || filterView === 'GROUP') ? (
                    <BranchingTree />
                ) : (
                    renderListView()
                )}
            </div>
            
            {isSelectionMode && selectedBatchIds.size > 0 && (
                <div className="absolute bottom-6 left-6 right-6 z-40 animate-in slide-in-from-bottom-4">
                    <button 
                        onClick={handleBatchPay}
                        className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 text-white font-bold py-4 rounded-2xl shadow-xl shadow-cyan-500/30 flex justify-between px-6 items-center"
                    >
                        <span>Pay {selectedBatchIds.size} Bills</span>
                        <span className="bg-black/20 px-2 py-1 rounded text-sm">
                            RM {items.filter(i => selectedBatchIds.has(i.id)).reduce((a,b) => a+b.amount, 0).toFixed(2)}
                        </span>
                    </button>
                </div>
            )}
        </div>
    );
};