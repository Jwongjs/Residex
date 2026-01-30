
import React from 'react';
import { ArrowLeft, Wallet, QrCode, Landmark, Banknote, Smartphone } from 'lucide-react';
import { PAYMENT_OPTIONS, PaymentMethodOption } from '../types';

interface SelectSinglePaymentProps {
  onBack: () => void;
  onSelect: (methodId: string) => void;
}

export const SelectSinglePayment: React.FC<SelectSinglePaymentProps> = ({ onBack, onSelect }) => {
  
  const getIcon = (iconName?: string) => {
    switch(iconName) {
        case 'wallet': return <Wallet size={24} />;
        case 'qr': return <QrCode size={24} />;
        case 'bank': return <Landmark size={24} />;
        case 'cash': return <Banknote size={24} />;
        case 'app': return <Smartphone size={24} />;
        default: return <Wallet size={24} />;
    }
  };

  return (
    <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
      <div className="flex items-center gap-4 pt-6 pb-6">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md group"
        >
          <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
        </button>
        <div>
            <h1 className="text-white font-bold text-xl tracking-tight">Select Payment</h1>
            <p className="text-slate-400 text-xs">How should everyone pay?</p>
        </div>
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar -mx-2 px-2 space-y-3 pb-20">
        {PAYMENT_OPTIONS.map((option) => (
            <button
                key={option.id}
                onClick={() => onSelect(option.id)}
                className="w-full group relative overflow-hidden rounded-2xl bg-slate-800/40 border border-white/5 hover:bg-slate-800/80 hover:border-white/20 transition-all duration-300 p-4 flex items-center gap-4"
            >
                <div className={`h-14 w-14 rounded-xl bg-gradient-to-br ${option.color || 'from-slate-600 to-slate-800'} flex items-center justify-center text-white shadow-lg group-hover:scale-105 transition-transform`}>
                    {getIcon(option.iconName)}
                </div>
                
                <div className="flex-1 text-left">
                    <h3 className="text-white font-bold text-lg">{option.label}</h3>
                    <p className="text-slate-400 text-xs">{option.description}</p>
                </div>

                <div className="h-8 w-8 rounded-full border border-white/10 flex items-center justify-center opacity-0 group-hover:opacity-100 transition-opacity bg-white/5">
                     <ArrowLeft size={16} className="rotate-180 text-white" />
                </div>
            </button>
        ))}
      </div>
    </div>
  );
};
