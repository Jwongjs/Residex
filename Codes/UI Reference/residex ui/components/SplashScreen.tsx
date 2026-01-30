
import React, { useEffect, useState } from 'react';
import { Logo } from './Logo';

interface SplashScreenProps {
    onFinish: () => void;
    onSplitStart: () => void;
}

export const SplashScreen: React.FC<SplashScreenProps> = ({ onFinish, onSplitStart }) => {
  const [animationStage, setAnimationStage] = useState<'playing' | 'fading' | 'finished'>('playing');

  useEffect(() => {
    // Sequence:
    // 0s: Logo Animations Start (CSS handled in Logo.tsx)
    // 2s: Text fades in fully (CSS handled below)
    // 3.5s: Trigger app reveal (SplitStart)
    // 4.5s: Remove splash (Finish)

    const revealTimer = setTimeout(() => {
        setAnimationStage('fading');
        onSplitStart();
    }, 3500);

    const finishTimer = setTimeout(() => {
        setAnimationStage('finished');
        onFinish();
    }, 4500);

    return () => {
        clearTimeout(revealTimer);
        clearTimeout(finishTimer);
    };
  }, [onFinish, onSplitStart]);

  if (animationStage === 'finished') return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-hidden pointer-events-none">
        
        {/* Background Layer */}
        <div className={`absolute inset-0 bg-[#000212] transition-opacity duration-1000 ease-out
            ${animationStage === 'fading' ? 'opacity-0' : 'opacity-100'}
        `} />

        {/* Ambient Light for depth - Updated to Purple/Indigo */}
        <div className={`absolute top-[-20%] left-[-20%] w-[80vw] h-[80vw] bg-purple-600/10 rounded-full blur-[100px] transition-opacity duration-1000 ${animationStage === 'fading' ? 'opacity-0' : 'opacity-100'}`}></div>
        <div className={`absolute bottom-[-20%] right-[-20%] w-[80vw] h-[80vw] bg-indigo-600/10 rounded-full blur-[100px] transition-opacity duration-1000 ${animationStage === 'fading' ? 'opacity-0' : 'opacity-100'}`}></div>

        <div className={`relative z-10 w-full h-full flex flex-col items-center justify-center transition-all duration-1000 transform
             ${animationStage === 'fading' ? 'scale-110 opacity-0' : 'scale-100 opacity-100'}
        `}>
            
            {/* Logo Container */}
            <div className="relative mb-8">
                {/* Center Glow behind logo */}
                <div className="absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-40 h-40 bg-indigo-500/20 blur-[50px] rounded-full animate-pulse"></div>
                
                {/* The Animated Logo */}
                <Logo size={240} animate={true} />
            </div>

            {/* Brand Text - Fades in after logo starts */}
            <div className="text-center opacity-0 animate-[fadeIn_1s_ease-out_forwards_1.5s]">
                <h1 className="text-5xl font-black text-white tracking-tighter drop-shadow-2xl mb-2">
                    RESIDEX
                </h1>
                <p className="text-slate-400 text-[10px] font-black uppercase tracking-[0.4em] bg-gradient-to-r from-transparent via-white/10 to-transparent py-1 rounded-full">
                    Ecosystem for Living
                </p>
            </div>
        </div>
        
        <style>{`
            @keyframes fadeIn {
                from { opacity: 0; transform: translateY(10px); }
                to { opacity: 1; transform: translateY(0); }
            }
        `}</style>
    </div>
  );
};
