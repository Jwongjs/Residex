
import React, { useState, useMemo } from 'react';
import { ArrowLeft, CheckCircle, Circle, DollarSign, PieChart, CreditCard, Share2, Download } from 'lucide-react';
import { Bill, User, PAYMENT_OPTIONS } from '../types';
import { CommentSection } from './CommentSection';

interface BillDetailsProps {
  bill: Bill;
  currentUser: User;
  onBack: () => void;
}

// Mock detailed data generator since we don't have a backend for this demo
const generateMockParticipants = (bill: Bill, currentUser: User) => {
  // Fix: Ensure all properties required by User are present
  const users: (User & { share: number; paid: boolean; paymentMethod: string })[] = [
    { ...currentUser, share: bill.userShare, paid: false, paymentMethod: 'tng' },
    { id: 'u2', name: 'Sarah Tan', avatarInitials: 'ST', color: 'bg-gradient-to-br from-purple-400 to-indigo-600', share: (bill.totalAmount - bill.userShare) * 0.4, paid: true, paymentMethod: 'mae', phone: '012-3333333', fiscalPoints: 400, harmonyPoints: 400 },
    { id: 'u3', name: 'Raj Kumar', avatarInitials: 'RK', color: 'bg-gradient-to-br from-amber-400 to-orange-600', share: (bill.totalAmount - bill.userShare) * 0.3, paid: false, paymentMethod: 'duitnow', phone: '012-4444444', fiscalPoints: 400, harmonyPoints: 400 },
    { id: 'u4', name: 'David Wong', avatarInitials: 'DW', color: 'bg-gradient-to-br from-emerald-400 to-teal-600', share: (bill.totalAmount - bill.userShare) * 0.3, paid: false, paymentMethod: 'cash', phone: '012-5555555', fiscalPoints: 400, harmonyPoints: 400 },
  ].slice(0, bill.participantsCount); 

  const currentTotal = users.reduce((sum, u) => sum + u.share, 0);
  const diff = bill.totalAmount - currentTotal;
  users[0].share += diff;

  return users;
};

export const BillDetails: React.FC<BillDetailsProps> = ({ bill, currentUser, onBack }) => {
  // Initialize mock data
  const [participants, setParticipants] = useState(generateMockParticipants(bill, currentUser));
  const [selectedSlice, setSelectedSlice] = useState<number | null>(null);

  const togglePaidStatus = (userId: string) => {
    setParticipants(prev => prev.map(p => 
      p.id === userId ? { ...p, paid: !p.paid } : p
    ));
  };

  // --- Pie Chart Logic ---
  const totalValue = bill.totalAmount;
  let cumulativePercent = 0;

  const getCoordinatesForPercent = (percent: number) => {
    const x = Math.cos(2 * Math.PI * percent);
    const y = Math.sin(2 * Math.PI * percent);
    return [x, y];
  };

  const chartData = useMemo(() => {
    return participants.map((participant, index) => {
      const startPercent = cumulativePercent;
      const percent = participant.share / totalValue;
      cumulativePercent += percent;
      const endPercent = cumulativePercent;

      // SVG Geometry
      const [startX, startY] = getCoordinatesForPercent(startPercent);
      const [endX, endY] = getCoordinatesForPercent(endPercent);
      const largeArcFlag = percent > 0.5 ? 1 : 0;

      // Path command
      const pathData = [
        `M ${startX} ${startY}`, // Move
        `A 1 1 0 ${largeArcFlag} 1 ${endX} ${endY}`, // Arc
        `L 0 0`, // Line to center
      ].join(' ');

      let fillColor = '#64748b'; 
      if (participant.color?.includes('cyan')) fillColor = '#22d3ee';
      else if (participant.color?.includes('purple')) fillColor = '#a78bfa';
      else if (participant.color?.includes('amber')) fillColor = '#fbbf24';
      else if (participant.color?.includes('emerald')) fillColor = '#34d399';
      else if (participant.color?.includes('rose')) fillColor = '#fb7185';
      else if (participant.color?.includes('fuchsia')) fillColor = '#e879f9';

      return {
        ...participant,
        pathData,
        fillColor,
        percent: (percent * 100).toFixed(1)
      };
    });
  }, [participants, totalValue]);

  const paidCount = participants.filter(p => p.paid).length;
  const progressPercent = (paidCount / participants.length) * 100;

  return (
    <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
      
      {/* Header (Sticky) */}
      <div className="flex items-center gap-4 pt-6 pb-4 sticky top-0 z-30 bg-[#020617]/95 backdrop-blur-sm px-4 sm:px-6 border-b border-white/5">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md group"
        >
          <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
        </button>
        <div className="flex-1">
            <h1 className="text-white font-bold text-lg tracking-tight truncate">{bill.title}</h1>
            <p className="text-slate-400 text-xs flex items-center gap-1">
                {bill.location} • {bill.date}
            </p>
        </div>
        <button className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:text-white transition-all">
            <Share2 size={18} />
        </button>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar pb-32 px-4 sm:px-6">
        
        {/* Pie Chart Section */}
        <div className="flex flex-col items-center justify-center py-6 relative">
            <div className="w-64 h-64 relative">
                {/* SVG Chart */}
                <svg viewBox="-1.2 -1.2 2.4 2.4" className="w-full h-full transform -rotate-90">
                    {chartData.map((slice, i) => (
                        <path
                            key={slice.id}
                            d={slice.pathData}
                            fill={slice.fillColor}
                            stroke="#020617"
                            strokeWidth="0.05"
                            className={`transition-all duration-300 cursor-pointer hover:opacity-100 ${
                                selectedSlice === i ? 'scale-110 opacity-100' : 
                                slice.paid ? 'opacity-30' : 'opacity-90 hover:scale-105'
                            }`}
                            onClick={() => setSelectedSlice(selectedSlice === i ? null : i)}
                        />
                    ))}
                    {/* Inner Circle Hole (Donut) */}
                    <circle cx="0" cy="0" r="0.75" fill="#020617" />
                </svg>

                {/* Center Content */}
                <div className="absolute inset-0 flex flex-col items-center justify-center pointer-events-none">
                    <span className="text-[10px] font-bold text-slate-500 uppercase tracking-widest">Total</span>
                    <span className="text-3xl font-black text-white tracking-tighter">
                        <span className="text-sm text-slate-500 mr-0.5 font-bold align-top mt-1 inline-block">RM</span>
                        {bill.totalAmount.toFixed(2)}
                    </span>
                    <div className="mt-1 flex items-center gap-1 bg-white/5 px-2 py-0.5 rounded-full border border-white/5">
                        <div className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse"></div>
                        <span className="text-[9px] text-emerald-400 font-bold uppercase">{paidCount}/{participants.length} Paid</span>
                    </div>
                </div>
            </div>
        </div>

        {/* Info Cards */}
        <div className="grid grid-cols-2 gap-3 mb-6">
             <div className="bg-slate-800/40 border border-white/5 rounded-2xl p-4 flex flex-col items-center justify-center">
                 <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-1">Tax & Service</span>
                 <span className="text-white font-bold text-lg">RM {(bill.totalAmount * 0.16).toFixed(2)}</span>
             </div>
             <div className="bg-slate-800/40 border border-white/5 rounded-2xl p-4 flex flex-col items-center justify-center">
                 <span className="text-slate-400 text-[10px] font-bold uppercase tracking-wider mb-1">Remaining</span>
                 <span className="text-rose-400 font-bold text-lg">
                    RM {participants.filter(p => !p.paid).reduce((acc, p) => acc + p.share, 0).toFixed(2)}
                 </span>
             </div>
        </div>

        {/* Member List */}
        <h3 className="text-slate-400 text-xs font-bold uppercase tracking-wider mb-3 px-1">Payment Status</h3>
        <div className="space-y-3">
            {participants.map((p, idx) => {
                const isSelected = chartData.findIndex(c => c.id === p.id) === selectedSlice;
                const methodDetails = PAYMENT_OPTIONS.find(opt => opt.id === p.paymentMethod);
                const percent = ((p.share / totalValue) * 100).toFixed(1);

                return (
                    <div 
                        key={p.id}
                        onClick={() => setSelectedSlice(chartData.findIndex(c => c.id === p.id))}
                        className={`relative overflow-hidden rounded-2xl border transition-all duration-300
                            ${p.paid 
                                ? 'bg-slate-800/20 border-white/5' 
                                : isSelected 
                                    ? 'bg-slate-800/80 border-cyan-500/50 shadow-[0_0_15px_rgba(34,211,238,0.1)]'
                                    : 'bg-slate-800/50 border-white/10 hover:bg-slate-800/70'
                            }`}
                    >
                        {/* Progress bar background for visual percentage */}
                        <div 
                            className={`absolute left-0 top-0 bottom-0 opacity-5 transition-all duration-500 pointer-events-none ${p.color}`}
                            style={{ width: `${percent}%` }}
                        ></div>

                        <div className="flex items-center justify-between p-4 relative z-10">
                            <div className="flex items-center gap-3">
                                <div className="relative">
                                    <div className={`h-10 w-10 rounded-full flex items-center justify-center text-xs font-bold text-white shadow-sm ring-2 ring-black/50 ${p.color}`}>
                                        {p.profileImage ? (
                                            <img src={p.profileImage} alt={p.name} className="w-full h-full object-cover rounded-full" />
                                        ) : p.avatarInitials}
                                    </div>
                                    {p.paid && (
                                        <div className="absolute -bottom-1 -right-1 bg-emerald-500 rounded-full p-0.5 border-2 border-slate-900">
                                            <CheckCircle size={10} className="text-white" strokeWidth={3} />
                                        </div>
                                    )}
                                </div>
                                <div className="flex flex-col">
                                    <span className={`text-sm font-bold ${p.paid ? 'text-slate-400 line-through' : 'text-white'}`}>
                                        {p.name} {p.id === currentUser.id ? '(You)' : ''}
                                    </span>
                                    <div className="flex items-center gap-2 text-[10px] text-slate-500">
                                        <span className="font-mono bg-white/5 px-1.5 rounded text-slate-400">{percent}%</span>
                                        <span>•</span>
                                        <span className="flex items-center gap-1">
                                            <CreditCard size={10} />
                                            {methodDetails?.label || 'Cash'}
                                        </span>
                                    </div>
                                </div>
                            </div>

                            <div className="flex items-center gap-4">
                                <div className="text-right">
                                    <span className={`block font-bold text-base ${p.paid ? 'text-slate-500' : 'text-white'}`}>
                                        <span className="text-[10px] text-slate-600 mr-1">RM</span>
                                        {p.share.toFixed(2)}
                                    </span>
                                </div>

                                <button 
                                    onClick={(e) => { e.stopPropagation(); togglePaidStatus(p.id); }}
                                    className={`h-8 w-8 rounded-full flex items-center justify-center border transition-all duration-300
                                        ${p.paid 
                                            ? 'bg-emerald-500/20 border-emerald-500/50 text-emerald-400' 
                                            : 'bg-white/5 border-white/20 text-slate-500 hover:bg-white/10 hover:text-white hover:border-white/40'}`}
                                >
                                    {p.paid ? <CheckCircle size={16} strokeWidth={2.5} /> : <Circle size={16} />}
                                </button>
                            </div>
                        </div>
                    </div>
                );
            })}
        </div>

        {/* Download Receipt Button */}
        <button className="w-full mt-6 mb-8 py-4 rounded-2xl border-2 border-dashed border-white/10 text-slate-400 font-bold text-sm hover:border-cyan-500/30 hover:text-cyan-400 hover:bg-cyan-500/5 transition-all flex items-center justify-center gap-2 group">
             <Download size={16} className="group-hover:translate-y-0.5 transition-transform" />
             Download Detailed Receipt
        </button>

        {/* Comment Section (Reusable) */}
        <CommentSection currentUser={currentUser} participants={participants} billId={bill.id} />

      </div>
    </div>
  );
};
