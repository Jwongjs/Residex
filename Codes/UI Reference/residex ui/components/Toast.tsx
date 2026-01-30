import React, { useEffect } from 'react';
import { Check, AlertCircle, X } from 'lucide-react';

interface ToastProps {
  message: string;
  type?: 'success' | 'error' | 'info';
  onClose: () => void;
}

export const Toast: React.FC<ToastProps> = ({ message, type = 'success', onClose }) => {
  useEffect(() => {
    const timer = setTimeout(onClose, 3000);
    return () => clearTimeout(timer);
  }, [onClose]);

  return (
    <div className="fixed top-6 left-1/2 -translate-x-1/2 z-[100] animate-in slide-in-from-top-4 fade-in duration-300">
      <div className="bg-slate-900/95 backdrop-blur-xl border border-white/10 shadow-2xl shadow-black/50 rounded-2xl px-4 py-3 flex items-center gap-3 pr-10 relative min-w-[300px] ring-1 ring-white/10">
        <div className={`p-2 rounded-full ${type === 'success' ? 'bg-emerald-500/20 text-emerald-400' : 'bg-blue-500/20 text-blue-400'}`}>
          {type === 'success' ? <Check size={16} strokeWidth={3} /> : <AlertCircle size={16} />}
        </div>
        <span className="text-white font-medium text-sm tracking-wide">{message}</span>
        <button onClick={onClose} className="absolute right-2 top-1/2 -translate-y-1/2 p-2 text-slate-500 hover:text-white transition-colors">
            <X size={14} />
        </button>
      </div>
    </div>
  );
};