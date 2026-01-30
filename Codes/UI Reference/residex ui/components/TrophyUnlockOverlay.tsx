
import React, { useEffect, useState } from 'react';
import { X, Share2, Crown, Sparkles } from 'lucide-react';
import { Achievement } from '../types';
import { Badge } from './Badge';

interface TrophyUnlockOverlayProps {
    achievement: Achievement;
    onClose: () => void;
}

export const TrophyUnlockOverlay: React.FC<TrophyUnlockOverlayProps> = ({ achievement, onClose }) => {
    const [isVisible, setIsVisible] = useState(false);

    useEffect(() => {
        // Trigger enter animation
        setIsVisible(true);
    }, []);

    const handleClose = () => {
        setIsVisible(false);
        setTimeout(onClose, 300); // Wait for exit animation
    };

    const getRarityColor = () => {
        switch(achievement.tier) {
            case 'PLATINUM': return 'text-indigo-300';
            case 'GOLD': return 'text-amber-400';
            case 'SILVER': return 'text-slate-300';
            default: return 'text-orange-400';
        }
    };

    return (
        <div className={`fixed inset-0 z-[100] flex items-center justify-center transition-all duration-300 ${isVisible ? 'bg-black/80 backdrop-blur-xl' : 'bg-transparent pointer-events-none'}`}>
            
            <div className={`relative w-full max-w-sm mx-4 transition-all duration-500 transform ${isVisible ? 'scale-100 opacity-100 translate-y-0' : 'scale-90 opacity-0 translate-y-10'}`}>
                
                {/* Glow Background */}
                <div className={`absolute top-1/2 left-1/2 -translate-x-1/2 -translate-y-1/2 w-[120%] h-[120%] bg-gradient-to-tr from-transparent via-${achievement.tier === 'GOLD' ? 'amber' : 'indigo'}-500/20 to-transparent blur-3xl rounded-full pointer-events-none`}></div>

                {/* Main Card */}
                <div className="bg-[#0f172a] border border-white/10 rounded-[2rem] p-1 shadow-2xl relative overflow-hidden">
                    
                    {/* Top Banner - Tier Indicator */}
                    <div className="bg-slate-900/50 p-6 flex flex-col items-center justify-center relative rounded-t-[1.8rem] border-b border-white/5">
                        <div className="text-xs font-bold tracking-[0.2em] text-slate-400 uppercase mb-4 animate-pulse">Trophy Unlocked!</div>
                        
                        {/* The Illustrated Badge */}
                        <div className="scale-150 mb-4 drop-shadow-2xl">
                             <Badge type={achievement.badgeType} tier={achievement.tier} size="xl" />
                        </div>

                        <h2 className="text-2xl font-black text-white text-center leading-tight mb-1">{achievement.title}</h2>
                        <p className="text-slate-400 text-sm text-center">{achievement.description}</p>
                    </div>

                    {/* Stats & Rarity */}
                    <div className="p-6 space-y-6 bg-gradient-to-b from-[#0f172a] to-[#020617] rounded-b-[1.8rem]">
                        
                        <div className="flex items-center justify-between border-b border-white/10 pb-4">
                            <div className="flex items-center gap-3">
                                <div className={`p-2 rounded-lg bg-white/5 ${getRarityColor()}`}>
                                    <Crown size={20} fill="currentColor" />
                                </div>
                                <div>
                                    <div className={`font-bold text-sm ${getRarityColor()}`}>{achievement.tier} TIER</div>
                                    <div className="text-[10px] text-slate-500 font-bold uppercase">{achievement.rarityPercent}% of players have this</div>
                                </div>
                            </div>
                        </div>

                        {/* Rewards */}
                        <div>
                            <div className="text-[10px] font-bold text-slate-500 uppercase tracking-wider mb-3">Rewards</div>
                            <div className="space-y-2">
                                {achievement.rewards.map((reward, i) => (
                                    <div key={i} className="flex items-center gap-3 bg-white/5 p-3 rounded-xl border border-white/5">
                                        <Sparkles size={14} className="text-indigo-400" />
                                        <span className="text-sm font-bold text-white">{reward}</span>
                                    </div>
                                ))}
                            </div>
                        </div>

                        {/* Actions */}
                        <div className="flex gap-3 pt-2">
                            <button className="flex-1 bg-slate-800 text-white font-bold py-3.5 rounded-xl border border-white/10 hover:bg-slate-700 transition-colors flex items-center justify-center gap-2">
                                <Share2 size={18} /> Share
                            </button>
                            <button 
                                onClick={handleClose}
                                className="flex-1 bg-white text-slate-900 font-bold py-3.5 rounded-xl hover:bg-indigo-50 transition-colors"
                            >
                                Close
                            </button>
                        </div>
                    </div>
                </div>
            </div>
        </div>
    );
};
