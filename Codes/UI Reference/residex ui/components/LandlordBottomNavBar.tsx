
import React from 'react';
import { LayoutGrid, TrendingUp, Building2, Bot } from 'lucide-react';
import { LandlordTab } from '../types';

interface LandlordBottomNavBarProps {
  activeTab: LandlordTab;
  onTabChange: (tab: LandlordTab) => void;
}

export const LandlordBottomNavBar: React.FC<LandlordBottomNavBarProps> = ({ activeTab, onTabChange }) => {
  const tabs = [
    { 
      id: 'OVERVIEW', 
      icon: LayoutGrid, 
      label: 'Command', 
      // All tabs use unified Blue/Cyan theme
      color: 'text-blue-300', 
      glow: 'bg-blue-500',
      shadow: 'drop-shadow-[0_0_8px_rgba(59,130,246,0.6)]'
    },
    { 
      id: 'FINANCE', 
      icon: TrendingUp, 
      label: 'Finance', 
      color: 'text-cyan-300', 
      glow: 'bg-cyan-500',
      shadow: 'drop-shadow-[0_0_8px_rgba(34,211,238,0.6)]'
    },
    { 
      id: 'PROPERTIES', 
      icon: Building2, 
      label: 'Assets', 
      color: 'text-blue-300', 
      glow: 'bg-blue-500',
      shadow: 'drop-shadow-[0_0_8px_rgba(59,130,246,0.6)]'
    },
    { 
      id: 'AI_TOOLS', 
      icon: Bot, 
      label: 'AI Ops', 
      color: 'text-indigo-300', 
      glow: 'bg-indigo-500',
      shadow: 'drop-shadow-[0_0_8px_rgba(99,102,241,0.6)]'
    },
  ];

  return (
    <div className="fixed bottom-0 left-0 right-0 z-50">
      <div className="bg-[#020617]/90 backdrop-blur-xl border-t border-white/5 pb-6 pt-4 px-6 flex justify-between items-center shadow-[0_-10px_40px_rgba(0,0,0,0.5)]">
        {tabs.map((tab) => {
          const isActive = activeTab === tab.id;
          const Icon = tab.icon;
          
          return (
            <button
              key={tab.id}
              onClick={() => onTabChange(tab.id as LandlordTab)}
              className={`relative flex flex-col items-center justify-center gap-1.5 px-2 transition-all duration-300 group`}
            >
              <div className="relative">
                <Icon 
                  size={24} 
                  className={`transition-all duration-500 ease-spring ${isActive ? `${tab.color} ${tab.shadow} scale-110` : 'text-slate-600 group-hover:text-slate-400'}`} 
                  strokeWidth={isActive ? 2.5 : 2}
                />
                
                {/* Dynamic Colored Glow */}
                {isActive && (
                    <div className={`absolute inset-0 blur-[12px] opacity-60 ${tab.glow} animate-pulse`}></div>
                )}
              </div>
              
              <span className={`text-[9px] font-bold tracking-wide transition-all duration-300 ${isActive ? `opacity-100 ${tab.color}` : 'opacity-0 scale-90 hidden'}`}>
                {tab.label}
              </span>
            </button>
          );
        })}
      </div>
    </div>
  );
};
