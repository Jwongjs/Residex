
import React from 'react';
import { TrophyTier, BadgeType } from '../types';

interface BadgeProps {
    type: BadgeType;
    tier: TrophyTier;
    size?: 'sm' | 'md' | 'lg' | 'xl';
    className?: string;
}

export const Badge: React.FC<BadgeProps> = ({ type, tier, size = 'md', className = '' }) => {
    
    // Size Mapping
    const sizePx = size === 'sm' ? 32 : size === 'md' ? 48 : size === 'lg' ? 64 : 128;
    const fontSize = size === 'sm' ? 10 : size === 'md' ? 14 : size === 'lg' ? 20 : 32;

    // Color Mapping based on Tier
    const getColors = () => {
        switch (tier) {
            case 'PLATINUM': return { 
                fill: 'url(#grad_plat)', 
                stroke: '#818cf8', // Indigo-400
                text: '#e0e7ff', // Indigo-50
                glow: 'rgba(99, 102, 241, 0.5)' // Indigo Glow
            };
            case 'GOLD': return { 
                fill: 'url(#grad_gold)', 
                stroke: '#fcd34d', 
                text: '#fef3c7',
                glow: 'rgba(251, 191, 36, 0.4)'
            };
            case 'SILVER': return { 
                fill: 'url(#grad_silver)', 
                stroke: '#e2e8f0', 
                text: '#f8fafc',
                glow: 'rgba(203, 213, 225, 0.4)'
            };
            case 'BRONZE': return { 
                fill: 'url(#grad_bronze)', 
                stroke: '#fdba74', 
                text: '#fff7ed',
                glow: 'rgba(194, 65, 12, 0.4)'
            };
        }
    };

    const colors = getColors();

    const renderShape = () => {
        switch (type) {
            case 'SHIELD':
                return (
                    <path d="M50 5 L90 20 V50 C90 75 50 95 50 95 C50 95 10 75 10 50 V20 L50 5 Z" />
                );
            case 'LIGHTNING':
                return (
                    <path d="M55 5 L20 50 H45 L35 95 L80 40 H50 L65 5 H55 Z" />
                );
            case 'DIAMOND':
                return (
                    <path d="M50 5 L95 50 L50 95 L5 50 Z" />
                );
            case 'STAR':
                return (
                   <path d="M50 5 L63 35 L95 38 L71 58 L78 90 L50 73 L22 90 L29 58 L5 38 L37 35 Z" />
                );
            default: // TROPHY
                return (
                    <path d="M20 20 H80 L70 70 C70 85 50 95 50 95 C50 95 30 85 30 70 L20 20 Z M10 25 H20 M80 25 H90" />
                );
        }
    };

    return (
        <div 
            className={`relative flex items-center justify-center ${className}`}
            style={{ width: sizePx, height: sizePx }}
        >
            <svg 
                viewBox="0 0 100 100" 
                width="100%" 
                height="100%" 
                className="drop-shadow-lg"
                style={{ filter: `drop-shadow(0 0 10px ${colors.glow})` }}
            >
                <defs>
                    <linearGradient id="grad_plat" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#3b82f6" /> {/* Blue */}
                        <stop offset="50%" stopColor="#6366f1" /> {/* Indigo */}
                        <stop offset="100%" stopColor="#818cf8" /> {/* Light Indigo */}
                    </linearGradient>
                    <linearGradient id="grad_gold" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#fcd34d" />
                        <stop offset="50%" stopColor="#d97706" />
                        <stop offset="100%" stopColor="#b45309" />
                    </linearGradient>
                    <linearGradient id="grad_silver" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#f1f5f9" />
                        <stop offset="50%" stopColor="#94a3b8" />
                        <stop offset="100%" stopColor="#475569" />
                    </linearGradient>
                    <linearGradient id="grad_bronze" x1="0%" y1="0%" x2="100%" y2="100%">
                        <stop offset="0%" stopColor="#fed7aa" />
                        <stop offset="50%" stopColor="#c2410c" />
                        <stop offset="100%" stopColor="#7c2d12" />
                    </linearGradient>
                    
                    {/* Inner Shine */}
                    <linearGradient id="shine" x1="0%" y1="0%" x2="100%" y2="0%">
                         <stop offset="0%" stopColor="white" stopOpacity="0.1" />
                         <stop offset="50%" stopColor="white" stopOpacity="0.4" />
                         <stop offset="100%" stopColor="white" stopOpacity="0.1" />
                    </linearGradient>
                </defs>

                {/* Base Shape */}
                <g fill={colors.fill} stroke={colors.stroke} strokeWidth="2">
                    {renderShape()}
                </g>

                {/* Shine Overlay */}
                <g fill="url(#shine)" style={{ mixBlendMode: 'overlay' }}>
                     {renderShape()}
                </g>
                
                {/* Internal Icon / Symbol logic could go here, simplified to just shape for now */}
            </svg>
            
            {/* Sparkles for High Tiers */}
            {(tier === 'GOLD' || tier === 'PLATINUM') && (
                <>
                    <div className="absolute top-0 right-0 w-2 h-2 bg-white rounded-full animate-pulse shadow-[0_0_5px_white]"></div>
                    <div className="absolute bottom-1 left-1 w-1.5 h-1.5 bg-white rounded-full animate-pulse delay-300 shadow-[0_0_5px_white]"></div>
                </>
            )}
        </div>
    );
};
