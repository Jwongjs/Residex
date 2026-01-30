import React from 'react';

interface LogoProps {
  size?: number;
  className?: string;
  variant?: 'solid' | 'split';
}

export const Logo: React.FC<LogoProps> = ({ size = 40, className = "", variant = 'split' }) => {
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
        <linearGradient id="logo_gradient" x1="0" y1="0" x2="100" y2="100" gradientUnits="userSpaceOnUse">
          <stop stopColor="#22d3ee" /> {/* cyan-400 */}
          <stop offset="1" stopColor="#2563eb" /> {/* blue-600 */}
        </linearGradient>
        
        {/* The Split Mask - Only used if variant is 'split' */}
        <mask id="split_mask">
          <rect width="100" height="100" fill="white" />
          {/* Diagonal cut from Top-Left to Bottom-Right (\). Matches standard slash direction. */}
          <path d="M-20 -20 L120 120" stroke="black" strokeWidth="6" />
        </mask>
      </defs>
      
      {/* 
         If variant is 'split', we apply the mask. 
         If 'solid', we render without mask (for the splash animation to handle the split).
      */}
      <g mask={variant === 'split' ? "url(#split_mask)" : undefined}>
        
        {/* Main Shape: Radius 32 for a fuller look while maintaining shadow safety */}
        <circle 
            cx="50" cy="50" r="32" 
            fill="url(#logo_gradient)" 
            className="drop-shadow-2xl" 
        />
        
        {/* Inner Ring */}
        <circle 
            cx="50" cy="50" r="28" 
            stroke="white" 
            strokeOpacity="0.2" 
            strokeWidth="1.5" 
        />
        
        {/* Dollar Sign - Perfectly Centered */}
        <text 
            x="50" 
            y="50" 
            dominantBaseline="central"
            fontFamily="Inter, sans-serif" 
            fontWeight="900" 
            fontSize="38" 
            fill="white" 
            textAnchor="middle"
            className="select-none"
            style={{ textShadow: '0 2px 4px rgba(0,0,0,0.2)' }}
        >
            $
        </text>
      </g>
    </svg>
  );
};