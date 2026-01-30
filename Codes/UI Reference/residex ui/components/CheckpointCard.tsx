import React from 'react';
import { Globe, Zap, Shield, Crown, Star } from 'lucide-react';
import { Achievement } from '../types';
import { Badge } from './Badge';

interface CheckpointCardProps {
    achievement: Achievement;
    colorClass?: string; // e.g. "text-checkpointGreen"
}

export const CheckpointCard: React.FC<CheckpointCardProps> = ({ achievement, colorClass = "text-checkpointGreen" }) => {
    return (
        <div className={`relative w-72 group animate-float`}>
            {/* 3D Container */}
            <div className="relative transition-transform duration-700 transform group-hover:scale-105 animate-tilt-slow">
                
                {/* Main Card Body */}
                <div className={`bg-black p-1 border-2 border-current ${colorClass} rounded-sm overflow-hidden shadow-[12px_12px_0px_0px_rgba(0,0,0,0.8)]`}>
                    
                    {/* Header bar */}
                    <div className={`flex justify-between items-center p-2 border-b-2 border-current ${colorClass} bg-black`}>
                        <div className="flex gap-1.5">
                            <div className="w-2 h-2 bg-current rounded-full opacity-50"></div>
                            <div className="w-2 h-2 bg-current rounded-full"></div>
                        </div>
                        <span className="text-[10px] font-mono font-black uppercase tracking-widest">
                            {achievement.tier} TIER
                        </span>
                    </div>

                    {/* Image Area - The Badge */}
                    <div className="p-8 flex items-center justify-center bg-zinc-900 aspect-square relative overflow-hidden">
                        {/* Background Texture */}
                        <div className="absolute inset-0 opacity-20 bg-[url('https://grainy-gradients.vercel.app/noise.svg')] pointer-events-none"></div>
                        <div className="absolute inset-0 bg-gradient-to-t from-black/40 to-transparent"></div>
                        
                        {/* The Badge Graphic */}
                        <div className="scale-[1.8] drop-shadow-[0_0_20px_currentColor] z-10">
                             <Badge type={achievement.badgeType} tier={achievement.tier} size="lg" />
                        </div>
                        
                        {/* ID Overlays */}
                        <div className="absolute top-3 left-3 flex flex-col z-20">
                             <span className="text-[8px] font-mono opacity-50 uppercase tracking-tighter">SplitLah 2025</span>
                             <span className="text-[10px] font-mono font-black">#ACH-{achievement.id.padStart(4, '0')}</span>
                        </div>

                        <div className="absolute bottom-3 right-3 z-20">
                             <div className="flex items-center gap-1.5 bg-black/60 px-2 py-1 rounded border border-white/10 backdrop-blur-sm">
                                <Star size={10} className="fill-current" />
                                <span className="text-[10px] font-mono font-black">{achievement.rarityPercent}%</span>
                             </div>
                        </div>
                    </div>

                    {/* Footer Info */}
                    <div className={`p-5 bg-current ${colorClass} text-black`}>
                        <h3 className="text-2xl font-black italic uppercase leading-[0.9] mb-3 break-words">{achievement.title}</h3>
                        <div className="flex justify-between items-center">
                            <div className="flex gap-3">
                                <Globe size={18} strokeWidth={3} />
                                <Zap size={18} strokeWidth={3} />
                                <Shield size={18} strokeWidth={3} />
                            </div>
                            <div className="bg-black text-white px-2 py-1 rounded text-[8px] font-black uppercase">
                                Verified
                            </div>
                        </div>
                    </div>
                </div>

                {/* Content Rating Style Box - Recreating the "WUMP" rating box */}
                <div className="absolute -bottom-6 -left-6 bg-black border-2 border-white p-2 w-16 h-20 flex flex-col items-center justify-center rotate-[-8deg] shadow-xl z-30">
                    <div className="text-[8px] font-black uppercase text-center leading-none mb-1">RANK</div>
                    <div className="flex-1 flex items-center justify-center text-white border-y border-white/20 w-full my-1">
                        <Crown size={24} className="animate-pulse" />
                    </div>
                    <div className="text-[6px] font-black uppercase text-center opacity-70 leading-tight">Split rated by<br/>SplitLah</div>
                </div>
            </div>
        </div>
    );
};