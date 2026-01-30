
import React from 'react';
import { ArrowLeft, Users, CreditCard, ChevronRight } from 'lucide-react';

interface PaymentMethodChoiceProps {
  onBack: () => void;
  onSelectSingle: () => void;
  onSelectIndividual: () => void;
}

export const PaymentMethodChoice: React.FC<PaymentMethodChoiceProps> = ({ onBack, onSelectSingle, onSelectIndividual }) => {
  return (
    <div className="flex flex-col h-full animate-in fade-in slide-in-from-right-4 duration-500">
      {/* Header */}
      <div className="flex items-center gap-4 pt-6 pb-8">
        <button 
          onClick={onBack}
          className="h-10 w-10 rounded-full bg-slate-800/50 border border-white/10 flex items-center justify-center text-slate-300 hover:bg-white/10 hover:text-white transition-all backdrop-blur-md group"
        >
          <ArrowLeft size={20} className="group-hover:-translate-x-0.5 transition-transform" />
        </button>
        <h1 className="text-white font-bold text-xl tracking-tight">Payment Method</h1>
      </div>

      <div className="flex flex-col gap-6">
        <p className="text-slate-400 text-sm font-medium px-1">How will everyone pay you?</p>

        {/* Option 1: Single Method */}
        <button 
          onClick={onSelectSingle}
          className="group relative w-full text-left overflow-hidden rounded-[2.5rem] bg-gradient-to-br from-slate-800 to-slate-900 border border-white/10 hover:border-cyan-500/50 transition-all duration-300 hover:-translate-y-1 shadow-lg shadow-black/30"
        >
          {/* Glow */}
          <div className="absolute top-0 right-0 w-40 h-40 bg-cyan-500/10 rounded-full blur-[60px] group-hover:bg-cyan-400/20 transition-colors duration-500"></div>
          
          <div className="relative p-8 z-10">
            <div className="h-16 w-16 rounded-2xl bg-gradient-to-br from-cyan-400 to-blue-600 flex items-center justify-center text-white shadow-lg shadow-cyan-900/20 mb-6 group-hover:scale-110 transition-transform duration-500">
                <CreditCard size={32} strokeWidth={1.5} />
            </div>

            <h3 className="text-white font-bold text-2xl mb-2 group-hover:text-cyan-200 transition-colors">Single Method</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
                Everyone pays using the same method (e.g. everyone transfers to your bank).
            </p>

            <div className="flex items-center gap-2 text-cyan-400 text-sm font-bold group-hover:translate-x-2 transition-transform duration-300">
              <span>Select Method</span>
              <ChevronRight size={16} />
            </div>
          </div>
        </button>

        {/* Option 2: Individual Methods */}
        <button 
          onClick={onSelectIndividual}
          className="group relative w-full text-left overflow-hidden rounded-[2.5rem] bg-gradient-to-br from-slate-800 to-slate-900 border border-white/10 hover:border-cyan-500/50 transition-all duration-300 hover:-translate-y-1 shadow-lg shadow-black/30"
        >
            {/* Glow */}
           <div className="absolute top-0 right-0 w-40 h-40 bg-blue-600/10 rounded-full blur-[60px] group-hover:bg-blue-500/20 transition-colors duration-500"></div>

           <div className="relative p-8 z-10">
            <div className="h-16 w-16 rounded-2xl bg-gradient-to-br from-cyan-400 to-blue-600 flex items-center justify-center text-white shadow-lg shadow-cyan-900/20 mb-6 group-hover:scale-110 transition-transform duration-500">
                <Users size={32} strokeWidth={1.5} />
            </div>

            <h3 className="text-white font-bold text-2xl mb-2 group-hover:text-cyan-200 transition-colors">Individual Methods</h3>
            <p className="text-slate-400 text-sm leading-relaxed mb-6">
                Assign different payment methods to different people.
            </p>

            <div className="flex items-center gap-2 text-cyan-400 text-sm font-bold group-hover:translate-x-2 transition-transform duration-300">
              <span>Assign Individually</span>
              <ChevronRight size={16} />
            </div>
          </div>
        </button>

      </div>
    </div>
  );
};
