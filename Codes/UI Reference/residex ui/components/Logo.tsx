
import React from 'react';
import { SyncState } from '../types';

interface LogoProps {
  size?: number;
  className?: string;
  animate?: boolean;
  syncState?: SyncState;
}

export const Logo: React.FC<LogoProps> = ({ size = 40, className = "", animate = false, syncState }) => {
  
  // Dynamic color configuration based on Sync State
  // Official Brand: Blue -> Purple gradient
  const getStateConfig = () => {
    switch (syncState) {
        case 'SYNCED':
            return {
                startColor: '#3b82f6', // Blue-500
                endColor: '#a855f7',   // Purple-500
                pulseSpeed: '4s'
            };
        case 'DRIFTING':
            return {
                startColor: '#fbbf24', // Amber-400
                endColor: '#f59e0b',   // Amber-500
                pulseSpeed: '2s'
            };
        case 'OUT_OF_SYNC':
            return {
                startColor: '#fb7185', // Rose-400
                endColor: '#e11d48',   // Rose-600
                pulseSpeed: '0.8s'
            };
        default:
            return {
                startColor: '#3b82f6', // Blue-500
                endColor: '#a855f7',   // Purple-500
                pulseSpeed: '3s'
            };
    }
  };

  const config = getStateConfig();

  return (
    <svg 
      width={size} 
      height={size} 
      viewBox="0 0 100 100" 
      fill="none" 
      xmlns="http://www.w3.org/2000/svg"
      className={className}
      style={{ overflow: 'visible' }}
    >
      <defs>
        <linearGradient id={`arch_gradient_${syncState || 'default'}`} x1="20" y1="80" x2="80" y2="80" gradientUnits="userSpaceOnUse">
          <stop stopColor={config.startColor} /> 
          <stop offset="1" stopColor={config.endColor} /> 
        </linearGradient>

        <linearGradient id={`diamond_gradient_${syncState || 'default'}`} x1="50" y1="35" x2="50" y2="65" gradientUnits="userSpaceOnUse">
          <stop stopColor={config.endColor} />
          <stop offset="1" stopColor={config.startColor} />
        </linearGradient>
      </defs>
      
      {/* 
         Center Diamond (The Core)
         Animate: Fade in + Scale Up + Rotate slightly
      */}
      <g 
        className={animate ? "animate-diamond-in origin-center" : ""} 
        style={{ transformBox: 'fill-box' }}
      >
        {/* Main Body */}
        <path 
            d="M50 38 L62 50 L50 62 L38 50 Z" 
            fill={`url(#diamond_gradient_${syncState || 'default'})`} 
            className="drop-shadow-lg"
        />
        {/* Top Facet Highlight */}
        <path 
            d="M50 38 L62 50 L50 50 Z" 
            fill="white" 
            fillOpacity="0.3" 
        />
        {/* Bottom Facet Shadow */}
        <path 
            d="M38 50 L50 62 L50 50 Z" 
            fill="black" 
            fillOpacity="0.2" 
        />
        
        {/* Pulse Effect Wrapper (Dynamic Speed) */}
        {animate && (
            <animateTransform 
                attributeName="transform" 
                type="scale" 
                values="1; 1.1; 1" 
                dur={config.pulseSpeed} 
                repeatCount="indefinite" 
                begin="1s"
                additive="sum"
            />
        )}
      </g>

      {/* 
         Archway (The Shelter)
      */}
      <path 
        d="M25 85 V45 C25 31.19 36.19 20 50 20 C63.81 20 75 31.19 75 45 V85" 
        stroke={`url(#arch_gradient_${syncState || 'default'})`} 
        strokeWidth="14" 
        strokeLinecap="round" 
        fill="none"
        pathLength="1"
        strokeDasharray="1"
        strokeDashoffset={animate ? "1" : "0"}
        className={animate ? "animate-arch-draw" : ""}
      />

    </svg>
  );
};
