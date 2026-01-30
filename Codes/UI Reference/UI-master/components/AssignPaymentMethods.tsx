
import React, { useState } from 'react';
import { ArrowLeft, Wallet, QrCode, Landmark, Banknote, Smartphone, Check, Trash2, X, ChevronRight } from 'lucide-react';
import { PAYMENT_OPTIONS, PaymentMethodOption, User, PaymentAssignment } from '../types';

interface AssignPaymentMethodsProps {
  participants: User[];
  onBack: () => void;
  onComplete: (assignments: PaymentAssignment) => void;
}

export const AssignPaymentMethods: React.FC<AssignPaymentMethodsProps> = ({ participants, onBack, onComplete }) => {
  const [assignments, setAssignments] = useState<PaymentAssignment>({});
  const [showResetConfirm, setShowResetConfirm] = useState(false);
  const [selectedMethod, setSelectedMethod] = useState<PaymentMethodOption | null>(null);
  
  // Temporary selection for the modal
  const [tempSelectedUserIds, setTempSelectedUserIds] = useState<Set<string>>(new Set());

  const getIcon = (iconName?: string, size = 24) => {
    switch(iconName) {
        case 'wallet': return <Wallet size={size} />;
        case 'qr': return <QrCode size={size} />;
        case 'bank': return <Landmark size={size} />;
        case 'cash': return <Banknote size={size} />;
        case 'app': return <Smartphone size={size} />;
        default: return <Wallet size={size} />;
    }
  };

  const handleReset = () => {
      if (showResetConfirm) {
          setAssignments({});
          setShowResetConfirm(false);
      } else {
          setShowResetConfirm(true);
          setTimeout(() => setShowResetConfirm(false), 3000);
      }
  };

  const openMethodModal = (method: PaymentMethodOption) => {
      // Pre-select users who are already assigned to this method
      const currentUsers = participants
        .filter(p => assignments[p.id] === method.id)
        .map(p => p.id);
      
      setTempSelectedUserIds(new Set(currentUsers));
      setSelectedMethod(method);
  };

  const toggleUserInModal = (userId: string) => {
      const newSet = new Set(tempSelectedUserIds);
      if (newSet.has(userId)) {
          newSet.delete(userId);
      } else {
          newSet.add(userId);
      }
      setTempSelectedUserIds(newSet);
  };

  const saveMethodAssignments = () => {
      if (!selectedMethod) return;

      const newAssignments = { ...assignments };
      
      // 1. Remove this method from anyone who was deselected (or not selected)
      participants.forEach(p => {
          if (assignments[p.id] === selectedMethod.id && !tempSelectedUserIds.has(p.id)) {
              delete newAssignments[p.id];
          }
      });

      // 2. Assign this method to selected users
      tempSelectedUserIds.forEach(userId => {
          newAssignments[userId] = selectedMethod.id;
      });

      setAssignments(newAssignments);
      setSelectedMethod(null);
      setTempSelectedUserIds(new Set());
  };

  // Check if all participants have a method assigned
  const allAssigned = participants.every(p => assignments[p.id]);

  return (
    <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500 relative">
      {/* Header */}
      <div className="flex items-center justify-between pt-6 pb-4">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md"
        >
          <ArrowLeft size={20} />
        </button>
        
        <h1 className="text-white font-bold text-lg tracking-tight">Assign Methods</h1>

        <button 
          onClick={handleReset}
          className={`h-10 px-3 rounded-full border flex items-center justify-center transition-all backdrop-blur-md font-bold text-xs gap-2
            ${showResetConfirm 
                ? 'bg-red-500 text-white border-red-400 w-24' 
                : 'bg-slate-800/50 text-slate-300 border-white/10 hover:bg-white/10 hover:text-white'}`}
        >
          {showResetConfirm ? 'Confirm?' : <><Trash2 size={16} /> Reset</>}
        </button>
      </div>

      <p className="text-slate-400 text-xs mb-4 px-1">Tap a payment method to assign members to it.</p>

      {/* Method Grid */}
      <div className="grid grid-cols-2 gap-3 overflow-y-auto no-scrollbar pb-32">
        {PAYMENT_OPTIONS.map(option => {
            // Count users assigned to this method
            const count = Object.values(assignments).filter(id => id === option.id).length;

            return (
                <button
                    key={option.id}
                    onClick={() => openMethodModal(option)}
                    className="relative bg-slate-800/40 border border-white/5 rounded-3xl p-4 flex flex-col items-center gap-3 hover:bg-slate-800/70 hover:border-white/20 transition-all group overflow-hidden"
                >
                    <div className={`h-12 w-12 rounded-2xl bg-gradient-to-br ${option.color} flex items-center justify-center text-white shadow-lg mb-1 group-hover:scale-110 transition-transform`}>
                        {getIcon(option.iconName, 20)}
                    </div>
                    <div className="text-center z-10">
                        <h3 className="text-white font-bold text-sm">{option.label}</h3>
                        <span className={`text-xs font-bold ${count > 0 ? 'text-cyan-400' : 'text-slate-500'}`}>
                            {count} assigned
                        </span>
                    </div>

                    {/* Users Preview Avatars */}
                    {count > 0 && (
                        <div className="flex -space-x-2 mt-1 opacity-80">
                            {participants.filter(p => assignments[p.id] === option.id).slice(0,3).map(p => (
                                <div key={p.id} className={`h-6 w-6 rounded-full border border-slate-800 ${p.color || 'bg-slate-600'} flex items-center justify-center text-[8px] text-white`}>
                                    {p.avatarInitials}
                                </div>
                            ))}
                            {count > 3 && <div className="h-6 w-6 rounded-full bg-slate-700 text-[8px] text-white flex items-center justify-center">+{count-3}</div>}
                        </div>
                    )}
                </button>
            );
        })}
      </div>

      {/* Bottom Complete Button */}
      <div className="absolute bottom-0 left-0 right-0 p-6 bg-gradient-to-t from-[#020617] via-[#020617] via-85% to-transparent z-20">
         <button 
            onClick={() => onComplete(assignments)}
            className="w-full bg-gradient-to-r from-cyan-500 to-blue-600 text-white h-14 rounded-2xl font-bold text-sm shadow-lg shadow-cyan-500/20 hover:shadow-cyan-500/40 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2"
         >
            Finish & View Summary
            <ChevronRight size={18} strokeWidth={3} />
         </button>
      </div>

      {/* Member Assignment Modal */}
      {selectedMethod && (
          <div className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-200">
             <div className="w-full max-w-md bg-[#0f172a] sm:rounded-3xl rounded-t-3xl p-6 border border-white/10 shadow-2xl h-[80vh] flex flex-col animate-in slide-in-from-bottom-4 duration-300">
                
                <div className="flex justify-between items-center mb-6">
                    <div className="flex items-center gap-3">
                        <div className={`h-10 w-10 rounded-xl bg-gradient-to-br ${selectedMethod.color} flex items-center justify-center text-white`}>
                            {getIcon(selectedMethod.iconName, 20)}
                        </div>
                        <div>
                            <h3 className="text-white font-bold text-lg">{selectedMethod.label}</h3>
                            <p className="text-slate-400 text-xs">Who is paying with this?</p>
                        </div>
                    </div>
                    <button onClick={() => setSelectedMethod(null)} className="p-2 bg-white/5 rounded-full hover:bg-white/10 text-slate-400">
                        <X size={20} />
                    </button>
                </div>

                <div className="flex-1 overflow-y-auto no-scrollbar space-y-2 -mx-2 px-2">
                    {participants.map(user => {
                        // Check if assigned to ANOTHER method
                        const assignedToOther = assignments[user.id] && assignments[user.id] !== selectedMethod.id;
                        const isSelected = tempSelectedUserIds.has(user.id);
                        
                        // Find name of other method if applicable
                        const otherMethodName = assignedToOther ? PAYMENT_OPTIONS.find(o => o.id === assignments[user.id])?.label : '';

                        return (
                            <button
                                key={user.id}
                                onClick={() => !assignedToOther && toggleUserInModal(user.id)}
                                disabled={!!assignedToOther}
                                className={`w-full flex items-center justify-between p-3 rounded-xl border transition-all
                                    ${assignedToOther 
                                        ? 'bg-slate-800/30 border-transparent opacity-40 cursor-not-allowed' 
                                        : isSelected 
                                            ? 'bg-cyan-900/20 border-cyan-500/50' 
                                            : 'bg-slate-800/60 border-transparent hover:bg-slate-700'}`}
                            >
                                <div className="flex items-center gap-3">
                                    <div className={`h-10 w-10 rounded-full flex items-center justify-center text-xs font-bold ${user.color || 'bg-slate-600'} text-white`}>
                                        {user.avatarInitials}
                                    </div>
                                    <div className="text-left">
                                        <div className={`text-sm font-bold ${isSelected ? 'text-white' : 'text-slate-300'}`}>{user.name}</div>
                                        {assignedToOther && (
                                            <div className="text-[10px] text-slate-500">Assigned to {otherMethodName}</div>
                                        )}
                                    </div>
                                </div>
                                
                                {!assignedToOther && (
                                    <div className={`h-6 w-6 rounded-full border flex items-center justify-center transition-all ${isSelected ? 'bg-cyan-500 border-cyan-400' : 'border-slate-600'}`}>
                                        {isSelected && <Check size={14} className="text-white" />}
                                    </div>
                                )}
                            </button>
                        );
                    })}
                </div>

                <div className="pt-4 mt-4 border-t border-white/10">
                    <button 
                        onClick={saveMethodAssignments}
                        className="w-full bg-white text-slate-900 font-bold py-4 rounded-2xl hover:bg-cyan-50 transition-colors"
                    >
                        Done
                    </button>
                </div>

             </div>
          </div>
      )}
    </div>
  );
};
