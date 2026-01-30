import React, { useState } from 'react';
import { X, Camera, Upload, Check, AlertCircle, ShieldCheck, ThumbsUp, Users } from 'lucide-react';

interface ChoreVerificationModalProps {
  choreName: string;
  onClose: () => void;
  onSuccess: () => void;
}

export const ChoreVerificationModal: React.FC<ChoreVerificationModalProps> = ({ choreName, onClose, onSuccess }) => {
  const [step, setStep] = useState<'CONFIRM' | 'UPLOAD' | 'SENT'>('CONFIRM');
  const [isUploading, setIsUploading] = useState(false);

  const handleUpload = () => {
    setIsUploading(true);
    // Simulate system processing
    setTimeout(() => {
      setIsUploading(false);
      setStep('SENT');
    }, 2000);
  };

  const handleFinish = () => {
    onSuccess();
    onClose();
  };

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center p-6 bg-black/90 backdrop-blur-xl animate-in fade-in">
      <div className="w-full max-w-sm bg-slate-900 border border-white/10 rounded-[2.5rem] overflow-hidden shadow-2xl relative">
        {/* Progress Bar */}
        <div className="h-1 bg-slate-800 w-full overflow-hidden">
            <div 
                className="h-full bg-cyan-500 transition-all duration-500" 
                style={{ width: step === 'CONFIRM' ? '33%' : step === 'UPLOAD' ? '66%' : '100%' }}
            ></div>
        </div>

        <div className="p-8">
            {step === 'CONFIRM' && (
                <div className="text-center animate-in zoom-in-95">
                    <div className="h-20 w-20 bg-cyan-500/10 text-cyan-400 rounded-3xl flex items-center justify-center mx-auto mb-6 border border-cyan-500/20">
                        <AlertCircle size={40} />
                    </div>
                    <h2 className="text-white font-black text-2xl mb-2">Execute Protocol?</h2>
                    <p className="text-slate-400 text-sm mb-8 leading-relaxed">
                        You are marking <span className="text-cyan-400 font-bold">"{choreName}"</span> as complete. This requires visual evidence for peer review.
                    </p>
                    <div className="flex gap-3">
                        <button onClick={onClose} className="flex-1 py-4 rounded-2xl bg-slate-800 text-slate-400 font-bold text-sm">Abort</button>
                        <button onClick={() => setStep('UPLOAD')} className="flex-1 py-4 rounded-2xl bg-cyan-500 text-white font-bold text-sm shadow-lg shadow-cyan-900/20">Proceed</button>
                    </div>
                </div>
            )}

            {step === 'UPLOAD' && (
                <div className="text-center animate-in slide-in-from-right-4">
                    <div className="h-20 w-20 bg-blue-500/10 text-blue-400 rounded-3xl flex items-center justify-center mx-auto mb-6 border border-blue-500/20">
                        <Camera size={40} />
                    </div>
                    <h2 className="text-white font-black text-2xl mb-2">Proof of Work</h2>
                    <p className="text-slate-400 text-sm mb-8">
                        Upload a photo of the completed area.
                    </p>
                    
                    <button 
                        onClick={handleUpload}
                        disabled={isUploading}
                        className="w-full mb-4 py-8 border-2 border-dashed border-white/10 rounded-3xl flex flex-col items-center justify-center gap-3 hover:bg-white/5 transition-all text-slate-500 hover:text-cyan-400 group"
                    >
                        {isUploading ? (
                            <div className="h-10 w-10 border-4 border-cyan-500 border-t-transparent rounded-full animate-spin"></div>
                        ) : (
                            <>
                                <Upload size={32} className="group-hover:-translate-y-1 transition-transform" />
                                <span className="text-xs font-bold uppercase tracking-widest">Select Imagery</span>
                            </>
                        )}
                    </button>

                    <button onClick={onClose} className="text-slate-600 text-xs font-bold uppercase tracking-widest">Cancel</button>
                </div>
            )}

            {step === 'SENT' && (
                <div className="text-center animate-in zoom-in-95">
                    <div className="h-20 w-20 bg-emerald-500/10 text-emerald-400 rounded-full flex items-center justify-center mx-auto mb-6 border border-emerald-500/20 relative">
                        <Check size={40} strokeWidth={3} />
                        <div className="absolute inset-0 rounded-full animate-ping bg-emerald-500/20"></div>
                    </div>
                    <h2 className="text-white font-black text-2xl mb-2">Relay Complete</h2>
                    <p className="text-slate-400 text-sm mb-8 leading-relaxed">
                        Evidence has been broadcasted. Awaiting <span className="text-white font-bold italic">Harmony Consensus</span> from remaining tenants.
                    </p>
                    
                    <div className="bg-slate-800/50 rounded-2xl p-4 mb-8 flex items-center gap-4 text-left border border-white/5">
                        <div className="flex -space-x-2">
                            <div className="h-8 w-8 rounded-full bg-slate-700 border border-slate-900 flex items-center justify-center text-[10px] font-bold">ST</div>
                            <div className="h-8 w-8 rounded-full bg-slate-700 border border-slate-900 flex items-center justify-center text-[10px] font-bold">RK</div>
                        </div>
                        <div className="flex-1">
                            <span className="text-[10px] font-black text-slate-500 uppercase block leading-none">Status</span>
                            <span className="text-xs font-bold text-emerald-400">Awaiting 2 Votes</span>
                        </div>
                        <ThumbsUp size={16} className="text-emerald-400 animate-bounce" />
                    </div>

                    <button onClick={handleFinish} className="w-full py-4 rounded-2xl bg-white text-slate-900 font-bold text-sm shadow-xl active:scale-95 transition-all">Understood</button>
                </div>
            )}
        </div>
      </div>
    </div>
  );
};