
import React, { useState } from 'react';
import { X, Star, ThumbsUp, Zap, Heart, Shield, MessageSquare } from 'lucide-react';

interface LandlordRatingModalProps {
  ticketTitle: string;
  onClose: () => void;
  onSubmit: () => void;
}

const BADGES = [
  { id: 'speed', label: 'Lightning Fast', icon: <Zap size={14} />, color: 'bg-yellow-500/20 text-yellow-400 border-yellow-500/50' },
  { id: 'friendly', label: 'Very Friendly', icon: <Heart size={14} />, color: 'bg-rose-500/20 text-rose-400 border-rose-500/50' },
  { id: 'pro', label: 'Professional', icon: <Shield size={14} />, color: 'bg-blue-500/20 text-blue-400 border-blue-500/50' },
  { id: 'steady', label: 'Steady Lah', icon: <ThumbsUp size={14} />, color: 'bg-emerald-500/20 text-emerald-400 border-emerald-500/50' },
];

export const LandlordRatingModal: React.FC<LandlordRatingModalProps> = ({ ticketTitle, onClose, onSubmit }) => {
  const [rating, setRating] = useState(0);
  const [selectedBadges, setSelectedBadges] = useState<Set<string>>(new Set());
  const [comment, setComment] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const toggleBadge = (id: string) => {
    const newSet = new Set(selectedBadges);
    if (newSet.has(id)) newSet.delete(id);
    else newSet.add(id);
    setSelectedBadges(newSet);
  };

  const handleSubmit = () => {
    setIsSubmitting(true);
    setTimeout(() => {
      setIsSubmitting(false);
      onSubmit();
    }, 1500);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="w-full max-w-md bg-[#0f172a] sm:rounded-[2.5rem] rounded-t-[2.5rem] p-8 border border-white/10 shadow-2xl animate-in slide-in-from-bottom-8 duration-500 relative overflow-hidden">
        {/* Glow Effects */}
        <div className="absolute -top-24 -left-24 w-48 h-48 bg-amber-500/10 rounded-full blur-[60px] pointer-events-none"></div>
        <div className="absolute top-0 right-0 w-32 h-32 bg-indigo-500/10 rounded-full blur-[50px] pointer-events-none"></div>

        <div className="flex justify-between items-center mb-6 relative z-10">
          <div>
            <h2 className="text-white font-black text-2xl tracking-tight">Rate Service</h2>
            <p className="text-slate-400 text-xs font-medium mt-1">Ticket: {ticketTitle}</p>
          </div>
          <button 
            onClick={onClose} 
            className="h-10 w-10 bg-white/5 rounded-full flex items-center justify-center text-slate-400 hover:text-white transition-all active:scale-90"
          >
            <X size={20} />
          </button>
        </div>

        <div className="space-y-8 relative z-10">
          
          {/* Star Rating */}
          <div className="flex justify-center gap-3">
            {[1, 2, 3, 4, 5].map((star) => (
              <button
                key={star}
                onClick={() => setRating(star)}
                className={`transition-all duration-300 transform hover:scale-110 active:scale-95 ${rating >= star ? 'text-amber-400 drop-shadow-[0_0_10px_rgba(251,191,36,0.5)]' : 'text-slate-700'}`}
              >
                <Star size={36} fill={rating >= star ? "currentColor" : "none"} strokeWidth={rating >= star ? 0 : 2} />
              </button>
            ))}
          </div>

          {/* Badges (Only show if rating is high enough, e.g. > 3, or just always show for this demo) */}
          <div className={`transition-all duration-500 ${rating > 0 ? 'opacity-100 translate-y-0' : 'opacity-50 translate-y-4 pointer-events-none grayscale'}`}>
            <p className="text-center text-[10px] font-bold text-slate-500 uppercase tracking-widest mb-3">What was great?</p>
            <div className="grid grid-cols-2 gap-3">
              {BADGES.map((badge) => {
                const isSelected = selectedBadges.has(badge.id);
                return (
                  <button
                    key={badge.id}
                    onClick={() => toggleBadge(badge.id)}
                    className={`
                      flex items-center justify-center gap-2 p-3 rounded-2xl border transition-all duration-300
                      ${isSelected 
                        ? `${badge.color} shadow-lg scale-[1.02] border-opacity-100` 
                        : 'bg-slate-800/50 border-white/5 text-slate-400 hover:bg-slate-800 hover:border-white/10'}
                    `}
                  >
                    {badge.icon}
                    <span className="text-xs font-bold">{badge.label}</span>
                  </button>
                );
              })}
            </div>
          </div>

          {/* Comment */}
          <div className="relative group">
             <div className="absolute top-3 left-4 text-slate-500"><MessageSquare size={16} /></div>
             <textarea 
               value={comment}
               onChange={(e) => setComment(e.target.value)}
               placeholder="Additional comments (optional)..."
               className="w-full bg-slate-900/50 border border-white/10 rounded-2xl py-3 pl-11 pr-4 text-white placeholder-slate-600 focus:outline-none focus:border-indigo-500/50 focus:ring-1 focus:ring-indigo-500/20 transition-all text-sm h-24 resize-none"
             />
          </div>

          <button 
            onClick={handleSubmit}
            disabled={rating === 0 || isSubmitting}
            className="w-full bg-gradient-to-r from-amber-500 to-orange-600 text-white h-14 rounded-2xl font-black text-sm shadow-xl shadow-amber-900/20 hover:shadow-amber-500/20 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
          >
            {isSubmitting ? (
               <div className="flex items-center gap-2">
                 <div className="h-4 w-4 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
                 <span>Submitting...</span>
               </div>
            ) : (
               "Submit Feedback"
            )}
          </button>
        </div>
      </div>
    </div>
  );
};
