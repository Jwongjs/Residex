import React, { useState } from 'react';
import { X, User, Phone, Check, ArrowRight } from 'lucide-react';
import { User as UserType } from '../types';

interface AddFriendModalProps {
  onClose: () => void;
  onAdd: (friend: Partial<UserType>) => void;
}

export const AddFriendModal: React.FC<AddFriendModalProps> = ({ onClose, onAdd }) => {
  const [name, setName] = useState('');
  const [phone, setPhone] = useState('');
  const [isSubmitting, setIsSubmitting] = useState(false);

  const COLORS = [
    'bg-gradient-to-br from-cyan-400 to-blue-600',
    'bg-gradient-to-br from-purple-400 to-indigo-600',
    'bg-gradient-to-br from-amber-400 to-orange-600',
    'bg-gradient-to-br from-emerald-400 to-teal-600',
    'bg-gradient-to-br from-rose-400 to-red-600',
    'bg-gradient-to-br from-fuchsia-500 to-pink-600'
  ];

  const handleSubmit = (e: React.FormEvent) => {
    e.preventDefault();
    if (!name.trim()) return;

    setIsSubmitting(true);
    
    // Simulate slight delay for effect
    setTimeout(() => {
        const initials = name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase();
        const randomColor = COLORS[Math.floor(Math.random() * COLORS.length)];
        
        onAdd({
            name,
            phone: phone.startsWith('+') ? phone : `+60${phone.replace(/^0+/, '')}`,
            avatarInitials: initials,
            color: randomColor,
            trustScore: 700,
            rank: 'SILVER'
        });
        setIsSubmitting(false);
        onClose();
    }, 600);
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-end sm:items-center justify-center bg-black/80 backdrop-blur-sm animate-in fade-in duration-300">
      <div className="w-full max-w-md bg-[#0f172a] sm:rounded-[2.5rem] rounded-t-[2.5rem] p-8 border border-white/10 shadow-2xl animate-in slide-in-from-bottom-8 duration-500 relative overflow-hidden">
        {/* Glow */}
        <div className="absolute -top-24 -right-24 w-48 h-48 bg-cyan-500/10 rounded-full blur-[60px] pointer-events-none"></div>
        
        <div className="flex justify-between items-center mb-8 relative z-10">
          <div>
            <h2 className="text-white font-black text-2xl tracking-tight">Add Friend</h2>
            <p className="text-slate-400 text-xs font-medium">Save contact to your vault</p>
          </div>
          <button 
            onClick={onClose} 
            className="h-10 w-10 bg-white/5 rounded-full flex items-center justify-center text-slate-400 hover:text-white transition-all active:scale-90"
          >
            <X size={20} />
          </button>
        </div>

        <form onSubmit={handleSubmit} className="space-y-6 relative z-10">
          <div className="space-y-4">
            {/* Name Field */}
            <div className="space-y-1.5">
              <label className="text-[10px] text-slate-500 font-bold uppercase tracking-widest ml-1">Friend's Name</label>
              <div className="relative group">
                <div className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-cyan-400 transition-colors">
                  <User size={18} />
                </div>
                <input 
                  type="text"
                  required
                  autoFocus
                  placeholder="e.g. Raj Kumar"
                  value={name}
                  onChange={(e) => setName(e.target.value)}
                  className="w-full bg-slate-900/50 border border-white/10 rounded-2xl py-4 pl-12 pr-4 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/20 transition-all font-bold"
                />
              </div>
            </div>

            {/* Phone Field */}
            <div className="space-y-1.5">
              <label className="text-[10px] text-slate-500 font-bold uppercase tracking-widest ml-1">Phone Number</label>
              <div className="flex gap-2">
                <div className="bg-slate-900/50 border border-white/10 rounded-2xl px-4 flex items-center gap-1.5 text-slate-300 font-bold font-mono">
                  <span className="text-base">🇲🇾</span>
                  <span>+60</span>
                </div>
                <div className="relative flex-1 group">
                  <div className="absolute left-4 top-1/2 -translate-y-1/2 text-slate-500 group-focus-within:text-cyan-400 transition-colors">
                    <Phone size={18} />
                  </div>
                  <input 
                    type="tel"
                    placeholder="12 345 6789"
                    value={phone}
                    onChange={(e) => setPhone(e.target.value.replace(/\D/g, ''))}
                    className="w-full bg-slate-900/50 border border-white/10 rounded-2xl py-4 pl-12 pr-4 text-white placeholder-slate-600 focus:outline-none focus:border-cyan-500/50 focus:ring-1 focus:ring-cyan-500/20 transition-all font-bold tracking-widest"
                  />
                </div>
              </div>
            </div>
          </div>

          <div className="pt-4">
            <button 
              type="submit"
              disabled={isSubmitting || !name.trim()}
              className="w-full bg-gradient-to-r from-cyan-400 via-blue-500 to-blue-600 text-white h-14 rounded-2xl font-black text-sm shadow-xl shadow-cyan-900/20 hover:shadow-cyan-400/20 hover:scale-[1.02] active:scale-95 transition-all flex items-center justify-center gap-2 disabled:opacity-50 disabled:cursor-not-allowed"
            >
              {isSubmitting ? (
                <div className="h-5 w-5 border-2 border-white/30 border-t-white rounded-full animate-spin"></div>
              ) : (
                <>
                  Save Friend
                  <Check size={20} strokeWidth={3} />
                </>
              )}
            </button>
          </div>
        </form>
      </div>
    </div>
  );
};