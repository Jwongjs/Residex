import React, { useState, useMemo } from 'react';
import { ArrowLeft, Divide, RotateCcw, Check, ChevronRight, User as UserIcon, X, Trash2, AlertCircle } from 'lucide-react';
import { User, Assignment } from '../types';
import { ReceiptItem } from './EditReceipt';

interface AssignItemsProps {
  items: ReceiptItem[];
  participants: User[];
  initialAssignments?: Assignment;
  onBack: (assignments: Assignment) => void;
  onComplete: (assignments: Assignment) => void;
}

export const AssignItems: React.FC<AssignItemsProps> = ({ items, participants, initialAssignments = {}, onBack, onComplete }) => {
  // --- State ---
  const [assignments, setAssignments] = useState<Assignment>(initialAssignments);
  const [selectedItemIds, setSelectedItemIds] = useState<Set<string>>(new Set());
  const [activeMemberId, setActiveMemberId] = useState<string | null>(null);
  const [localError, setLocalError] = useState<string | null>(null);
  
  // Reset Confirmation State
  const [showResetConfirm, setShowResetConfirm] = useState(false);

  // --- Computed ---
  const assignableItems = useMemo(() => items.filter(i => i.type !== 'TAX'), [items]);
  const taxItems = useMemo(() => items.filter(i => i.type === 'TAX'), [items]);

  const activeMember = useMemo(() => 
    participants.find(p => p.id === activeMemberId), 
  [participants, activeMemberId]);

  // Helper: Get total assigned quantity for an item
  const getAssignedQty = (itemId: string) => {
    const itemAssignments = assignments[itemId] || {};
    return (Object.values(itemAssignments) as number[]).reduce((sum, qty) => sum + qty, 0);
  };

  // Helper: Calculate user's total share (approximate for display)
  const getUserTotal = (userId: string) => {
    let subtotal = 0;
    let totalBillSubtotal = 0;

    assignableItems.forEach(item => {
      const assignedQty = assignments[item.id]?.[userId] || 0;
      subtotal += item.price * assignedQty;
      totalBillSubtotal += item.price * item.quantity;
    });

    if (subtotal === 0) return 0;

    // Add proportional tax
    const userShareRatio = totalBillSubtotal > 0 ? subtotal / totalBillSubtotal : 0;
    const totalTax = taxItems.reduce((sum, t) => sum + t.price, 0);
    return subtotal + (totalTax * userShareRatio);
  };

  // --- Actions ---

  const updateAssignment = (itemId: string, userId: string, newQty: number) => {
    setAssignments(prev => {
      const newItemAssignments = { ...(prev[itemId] || {}) };
      if (newQty <= 0) {
        delete newItemAssignments[userId];
      } else {
        newItemAssignments[userId] = newQty;
      }
      
      if (Object.keys(newItemAssignments).length === 0) {
        const { [itemId]: _, ...rest } = prev;
        return rest;
      }

      return { ...prev, [itemId]: newItemAssignments };
    });
  };

  const handleResetClick = () => {
    if (showResetConfirm) {
        setAssignments({});
        setSelectedItemIds(new Set());
        setActiveMemberId(null);
        setShowResetConfirm(false);
    } else {
        setShowResetConfirm(true);
        setTimeout(() => setShowResetConfirm(false), 3000);
    }
  };

  const handleSplitRemaining = () => {
    const newAssignments = { ...assignments };
    let hasSkippedItems = false;

    assignableItems.forEach(item => {
        const currentAssignedQty = (Object.values(newAssignments[item.id] || {}) as number[]).reduce((a, b) => a + b, 0);
        const remainingQty = item.quantity - currentAssignedQty;

        if (remainingQty > 0) {
            // STRICT MODE: Only allow splitting if it divides evenly among all participants
            // This prevents "splitting 2 items 3 ways" (0.66 each).
            if (remainingQty % participants.length === 0) {
                const sharePerPerson = remainingQty / participants.length;
                participants.forEach(p => {
                    const current = newAssignments[item.id]?.[p.id] || 0;
                    if (!newAssignments[item.id]) newAssignments[item.id] = {};
                    newAssignments[item.id][p.id] = current + sharePerPerson;
                });
            } else {
                hasSkippedItems = true;
            }
        }
    });

    setAssignments(newAssignments);
    
    if (hasSkippedItems) {
        setLocalError("Some items couldn't be split evenly.");
        setTimeout(() => setLocalError(null), 3000);
    }
  };

  const handleItemClick = (itemId: string) => {
    if (activeMemberId) {
        const item = assignableItems.find(i => i.id === itemId);
        if (!item) return;

        const currentAssigned = assignments[itemId]?.[activeMemberId] || 0;
        const totalAssigned = getAssignedQty(itemId);
        const assignedToOthers = totalAssigned - currentAssigned;
        const maxAvailable = Math.max(0, item.quantity - assignedToOthers);

        // Cycle Logic: 0 -> 1 -> ... -> Max -> 0
        // This is faster and avoids the modal for simple counting
        let newQty = currentAssigned + 1;

        if (newQty > maxAvailable) {
            newQty = 0; // Toggle off if exceeding limit
        }
        
        // Feedback if item is fully claimed by others
        if (maxAvailable === 0 && currentAssigned === 0) {
            setLocalError("Item fully assigned!");
            setTimeout(() => setLocalError(null), 2000);
            return;
        }

        updateAssignment(itemId, activeMemberId, newQty);
        return;
    }

    // Selection Mode (No active member)
    const newSet = new Set(selectedItemIds);
    if (newSet.has(itemId)) {
        newSet.delete(itemId);
    } else {
        newSet.add(itemId);
    }
    setSelectedItemIds(newSet);
  };

  const handleMemberClick = (userId: string) => {
    if (activeMemberId === userId) {
        setActiveMemberId(null);
        return;
    }

    // If items are selected, assign 1 of each to this member
    if (selectedItemIds.size > 0) {
        let assignedCount = 0;
        selectedItemIds.forEach(itemId => {
            const item = assignableItems.find(i => i.id === itemId);
            if (item) {
                const currentTotal = getAssignedQty(itemId);
                // Simple check: Only assign if there is room
                if (currentTotal < item.quantity) {
                    const currentUserQty = assignments[itemId]?.[userId] || 0;
                    updateAssignment(itemId, userId, currentUserQty + 1);
                    assignedCount++;
                }
            }
        });
        
        if (assignedCount < selectedItemIds.size) {
             setLocalError("Some selected items were already full.");
             setTimeout(() => setLocalError(null), 2000);
        }

        setSelectedItemIds(new Set()); 
    }
    
    setActiveMemberId(userId);
  };

  return (
    <div className="flex flex-col h-full animate-in fade-in duration-500 relative">
      
      {/* Error Toast Overlay */}
      {localError && (
        <div className="absolute top-20 left-1/2 -translate-x-1/2 z-50 bg-slate-800/90 backdrop-blur-md border border-red-500/50 text-white px-4 py-2 rounded-xl shadow-2xl flex items-center gap-2 animate-in slide-in-from-top-2 fade-in">
            <AlertCircle size={16} className="text-red-400" />
            <span className="text-xs font-bold">{localError}</span>
        </div>
      )}

      {/* Header */}
      <div className="flex items-center justify-between pt-6 pb-4 px-4 sm:px-6 animate-ios-slide-in-right">
        <button 
          onClick={() => onBack(assignments)}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all duration-300 ease-ios active:scale-95 backdrop-blur-md"
        >
          <ArrowLeft size={20} />
        </button>
        
        <h1 className="text-white font-bold text-lg tracking-tight">Assign Items</h1>

        <button 
          onClick={handleResetClick}
          className={`h-10 px-3 rounded-full border flex items-center justify-center transition-all duration-300 ease-ios active:scale-95 backdrop-blur-md font-bold text-xs gap-2
            ${showResetConfirm 
                ? 'bg-red-500 text-white border-red-400 w-24 shadow-lg shadow-red-900/20' 
                : 'bg-slate-800/50 text-slate-300 border-white/10 hover:bg-white/10 hover:text-white'}`}
        >
          {showResetConfirm ? (
              <span className="animate-ios-pop-in">Confirm?</span>
          ) : (
              <>
                <Trash2 size={16} />
                Reset
              </>
          )}
        </button>
      </div>

      {/* Main Content Area */}
      <div className="flex-1 overflow-y-auto no-scrollbar px-4 sm:px-6 pb-48 animate-ios-fade-in">
        
        {/* Items List */}
        <div className="space-y-3 mb-6">
            {assignableItems.map((item, idx) => {
                const isSelected = selectedItemIds.has(item.id);
                const assignedQty = getAssignedQty(item.id);
                const isFullyAssigned = assignedQty >= item.quantity;
                const myQty = activeMemberId ? (assignments[item.id]?.[activeMemberId] || 0) : 0;

                return (
                    <button
                        key={item.id}
                        onClick={() => handleItemClick(item.id)}
                        style={{ animationDelay: `${idx * 40}ms` }}
                        className={`w-full text-left p-4 rounded-2xl border transition-all duration-300 ease-ios relative overflow-hidden group active:scale-[0.98] animate-in slide-in-from-bottom-2 fade-in fill-mode-forwards
                            ${activeMemberId && myQty > 0 
                                ? 'bg-cyan-900/30 border-cyan-500/50' 
                                : isSelected 
                                    ? 'bg-white/10 border-cyan-400 shadow-[0_0_15px_rgba(34,211,238,0.2)] scale-[1.02]' 
                                    : isFullyAssigned 
                                        ? 'bg-slate-800/30 border-white/5 opacity-60' 
                                        : 'bg-slate-800/60 border-white/10 hover:bg-slate-700/60'
                            }
                        `}
                    >
                        <div className="flex justify-between items-start mb-2">
                            <div className="flex-1">
                                <span className={`font-bold text-sm transition-colors duration-300 ${myQty > 0 ? 'text-cyan-200' : 'text-white'}`}>{item.name}</span>
                                <div className="flex items-center gap-2 mt-1">
                                    <span className="text-xs text-slate-400 font-mono">
                                        {item.quantity}x @ RM{item.price.toFixed(2)}
                                    </span>
                                </div>
                            </div>
                            <div className="text-right">
                                <span className={`font-bold text-base transition-colors duration-300 ${myQty > 0 ? 'text-cyan-400' : 'text-slate-200'}`}>
                                    RM {(item.price * item.quantity).toFixed(2)}
                                </span>
                            </div>
                        </div>

                        {/* Enhanced Sleek Progress Bar */}
                        <div className="w-full h-3 bg-slate-950/80 rounded-full mt-3 overflow-hidden flex ring-1 ring-white/10 shadow-[inset_0_2px_4px_rgba(0,0,0,0.5)] relative">
                            {/* Render segments for each user */}
                            {participants.map(p => {
                                const qty = assignments[item.id]?.[p.id] || 0;
                                if (qty <= 0) return null;
                                const widthPct = (qty / item.quantity) * 100;
                                return (
                                    <div 
                                        key={p.id} 
                                        style={{ width: `${widthPct}%` }} 
                                        className={`${p.color || 'bg-slate-500'} h-full transition-all duration-500 ease-ios hover:brightness-110 relative border-r border-black/20 last:border-0`} 
                                        title={p.name}
                                    >
                                        {/* Subtle shine on each bar segment */}
                                        <div className="absolute inset-0 bg-gradient-to-b from-white/30 to-transparent"></div>
                                    </div>
                                );
                            })}
                        </div>

                        {/* Active Member Badge on Item */}
                        {activeMemberId && myQty > 0 && (
                             <div className="absolute top-0 right-0 bg-cyan-500 text-white text-[10px] font-bold px-2 py-1 rounded-bl-xl shadow-lg shadow-cyan-500/20 animate-ios-pop-in">
                                {myQty % 1 === 0 ? myQty : myQty.toFixed(2)} Assigned
                             </div>
                        )}
                    </button>
                );
            })}
        </div>
      </div>

      {/* Bottom Controls */}
      <div className="absolute bottom-0 left-0 right-0 bg-gradient-to-t from-[#020617] via-[#020617] via-90% to-transparent z-20 pt-16 pb-6 px-6">
         
         {/* Member Selector Scroll - Fixed Cutoff with Padding and Height */}
         <div className="flex gap-4 overflow-x-auto no-scrollbar mb-4 -mx-6 px-6 pt-6 pb-2 items-start min-h-[140px] animate-ios-slide-up">
            {participants.map(p => {
                const isActive = activeMemberId === p.id;
                const currentTotal = getUserTotal(p.id);

                return (
                    <button
                        key={p.id}
                        onClick={() => handleMemberClick(p.id)}
                        className={`flex-shrink-0 flex flex-col items-center gap-2 transition-all duration-300 ease-ios group outline-none
                            ${isActive ? 'opacity-100' : 'opacity-60 hover:opacity-100'}`}
                    >
                        <div className={`
                            relative h-14 w-14 rounded-full flex items-center justify-center text-sm font-bold text-white shadow-lg transition-all duration-300 ease-ios
                            ${p.color || 'bg-slate-600'}
                            ${isActive 
                                ? 'ring-[3px] ring-cyan-400 ring-offset-[3px] ring-offset-[#020617] scale-110 shadow-cyan-500/50 z-10' 
                                : 'ring-1 ring-white/10 group-hover:scale-105 group-hover:ring-white/30'}
                        `}>
                            {p.profileImage ? (
                                <img src={p.profileImage} alt={p.name} className="w-full h-full object-cover rounded-full" />
                            ) : (
                                <span className="z-10">{p.avatarInitials}</span>
                            )}
                            
                            {/* Glassy Overlay for shine */}
                            <div className="absolute inset-0 rounded-full bg-gradient-to-tr from-white/20 to-transparent opacity-0 group-hover:opacity-100 transition-opacity pointer-events-none"></div>
                        </div>

                        <div className={`flex flex-col items-center transition-all duration-300 ease-ios ${isActive ? 'translate-y-1' : ''}`}>
                            <span className={`text-[11px] font-bold truncate max-w-[70px] tracking-wide transition-colors duration-300 ${isActive ? 'text-white' : 'text-slate-400 group-hover:text-slate-200'}`}>
                                {p.name.split(' ')[0]}
                            </span>
                            {currentTotal > 0 && (
                                <div className={`
                                    mt-1 px-1.5 py-0.5 rounded-md border text-[9px] font-mono font-bold transition-all duration-300 ease-ios animate-ios-pop-in
                                    ${isActive 
                                        ? 'bg-cyan-950/80 text-cyan-400 border-cyan-500/30 shadow-sm shadow-cyan-900/20' 
                                        : 'bg-slate-800/50 text-slate-400 border-slate-700'}
                                `}>
                                    RM{currentTotal.toFixed(0)}
                                </div>
                            )}
                        </div>
                    </button>
                );
            })}
         </div>

         <div className="flex gap-3 animate-ios-slide-up" style={{ animationDelay: '100ms' }}>
            <button 
                onClick={handleSplitRemaining}
                className="h-14 w-14 rounded-2xl bg-slate-800 border border-white/10 flex items-center justify-center text-slate-400 hover:text-white hover:bg-slate-700 transition-all duration-300 ease-ios active:scale-95 relative group"
                title="Split Remaining (Evenly only)"
            >
                <Divide size={20} />
            </button>

            <button 
                onClick={() => onComplete(assignments)}
                className="flex-1 bg-gradient-to-r from-cyan-500 to-blue-600 text-white h-14 rounded-2xl font-bold text-sm shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 hover:scale-[1.02] active:scale-95 transition-all duration-300 ease-ios flex items-center justify-center gap-2"
            >
                Select Payment
                <ChevronRight size={18} strokeWidth={3} />
            </button>
         </div>
      </div>

    </div>
  );
};