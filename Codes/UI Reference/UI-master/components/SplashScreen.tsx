import React, { useEffect, useState } from 'react';
import { Logo } from './Logo';

interface SplashScreenProps {
    onFinish: () => void;
    onSplitStart: () => void;
}

export const SplashScreen: React.FC<SplashScreenProps> = ({ onFinish, onSplitStart }) => {
  const [animationStage, setAnimationStage] = useState<'loading' | 'splitting' | 'finished'>('loading');

  useEffect(() => {
    // 1. Hold the solid logo (Loading)
    const splitTimer = setTimeout(() => {
        setAnimationStage('splitting');
        onSplitStart(); // Trigger the App layer to start revealing itself behind
        
        // 2. Transition to app view
        // Animation duration is 1.8s. We finish slightly before end to avoid empty screen pause.
        setTimeout(() => {
             onFinish();
        }, 1500); 
    }, 1500);

    return () => {
        clearTimeout(splitTimer);
    };
  }, [onFinish, onSplitStart]);

  if (animationStage === 'finished') return null;

  return (
    <div className="fixed inset-0 z-[100] flex items-center justify-center overflow-hidden pointer-events-none">
        
        {/* Background Layer: Plain Black -> Swift Fade to Reveal Ambient Glow */}
        <div className={`absolute inset-0 bg-black transition-all duration-[2400ms] ease-in-out
            ${animationStage === 'splitting' ? 'animate-fade-out-swift' : 'gpu-accelerated'}
        `} />

        <div className={`relative z-10 w-full h-full flex flex-col items-center justify-center
             ${animationStage === 'splitting' ? 'animate-zoom-out-fade' : 'gpu-accelerated'}
        `}>
            
            {/* 
                THE LOGO CONTAINER (w-80 = 320px)
            */}
            <div className="relative w-80 h-80 mb-8">
                
                {/* 
                    Center Glow 
                */}
                <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-60 h-60 bg-cyan-500/30 blur-[80px] rounded-full transition-opacity duration-700 gpu-accelerated ${animationStage === 'splitting' ? 'opacity-0' : 'opacity-100 animate-pulse'}`}></div>

                {/* 
                    PHASE 1: SOLID LOGO (Loading)
                    This is the "One Big Coin". 
                    We remove it INSTANTLY when splitting starts to avoid ghosting/doubling with the split parts.
                */}
                <div className={`absolute inset-0 z-30 flex items-center justify-center ${animationStage === 'splitting' ? 'opacity-0' : 'opacity-100'}`}>
                    <Logo size={320} variant="solid" />
                </div>

                {/* 
                    PHASE 2: SPLIT PARTS (Splitting)
                    Crucial Fix: These are opacity-0 until the EXACT moment of splitting.
                    This prevents the "2 coins" look caused by drop-shadows stacking underneath the solid logo.
                */}
                
                {/* 
                   Piece 1: Bottom-Left Half
                   Clip Path: Triangle (Top-Left 0,0 -> Bottom-Left 0,100 -> Bottom-Right 100,100)
                */}
                <div className={`absolute inset-0 z-20 overflow-hidden gpu-accelerated ${animationStage === 'splitting' ? 'opacity-100 animate-split-bottom-left' : 'opacity-0'}`}>
                    <div className="w-full h-full" style={{ clipPath: 'polygon(0% 0%, 0% 100%, 100% 100%)' }}>
                        <Logo size={320} variant="solid" />
                    </div>
                </div>

                {/* 
                   Piece 2: Top-Right Half
                   Clip Path: Triangle (Top-Left 0,0 -> Top-Right 100,0 -> Bottom-Right 100,100)
                */}
                <div className={`absolute inset-0 z-20 overflow-hidden gpu-accelerated ${animationStage === 'splitting' ? 'opacity-100 animate-split-top-right' : 'opacity-0'}`}>
                     <div className="w-full h-full" style={{ clipPath: 'polygon(0% 0%, 100% 0%, 100% 100%)' }}>
                        <Logo size={320} variant="solid" />
                    </div>
                </div>

            </div>

            {/* Title - Fades out slowly */}
            <div className={`transition-all duration-1000 transform gpu-accelerated ${animationStage === 'splitting' ? 'opacity-0 scale-90 translate-y-10 blur-sm' : 'opacity-100 scale-100 translate-y-0'}`}>
                <h1 className="text-5xl font-black text-white tracking-tighter drop-shadow-2xl">
                    SplitLah
                </h1>
            </div>
        </div>
    </div>
  );
};