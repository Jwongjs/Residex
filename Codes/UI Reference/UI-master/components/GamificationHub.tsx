
import React, { useState, useEffect } from 'react';
import { ArrowLeft, Share2, Globe, Shield, Zap, Target, Crown, Award, ChevronRight, Info } from 'lucide-react';
import { User, Achievement } from '../types';
import { Badge } from './Badge';

interface GamificationHubProps {
  user: User;
  friends: User[];
  onBack: () => void;
}

interface AgentSlide {
  id: string;
  name: string;
  role: string;
  color: string;
  accent: string;
  description: string;
  mainAsset: React.ReactNode;
  stats: { label: string; value: string | number }[];
  abilities: { name: string; desc: string; icon: React.ReactNode }[];
}

export const GamificationHub: React.FC<GamificationHubProps> = ({ user, onBack }) => {
  const [activeAgentIdx, setActiveAgentIdx] = useState(0);
  const [isChanging, setIsChanging] = useState(false);

  const agents: AgentSlide[] = [
    {
      id: 'profile',
      name: user.name.toUpperCase(),
      role: 'MASTER SPLITTER',
      color: 'from-checkpointGreen/20 to-transparent',
      accent: 'text-checkpointGreen',
      description: "A legendary figure in the Malaysian splitting scene. Known for precise calculations at Restoran Nasi Kandar and lightning-fast DuitNow confirmations.",
      mainAsset: (
        <div className="relative w-64 h-64">
           <div className="absolute inset-0 bg-checkpointGreen/10 rounded-full blur-[80px] animate-pulse"></div>
           <div className="relative w-full h-full border-4 border-checkpointGreen p-2 rotate-3 animate-float bg-slate-900 overflow-hidden shadow-[0_0_50px_rgba(35,255,141,0.3)]">
              {user.profileImage ? (
                  <img src={user.profileImage} alt={user.name} className="w-full h-full object-cover grayscale contrast-125" />
              ) : (
                  <div className="w-full h-full flex items-center justify-center bg-slate-800 text-6xl font-black text-checkpointGreen">
                    {user.avatarInitials}
                  </div>
              )}
              <div className="absolute top-0 right-0 bg-checkpointGreen text-black px-2 py-1 font-black text-xs">RANK #{user.stats?.ranking || 47}</div>
           </div>
        </div>
      ),
      stats: [
        { label: 'TRUST SCORE', value: user.trustScore || 850 },
        { label: 'GLOBAL RANK', value: `#${user.stats?.ranking || 47}` }
      ],
      abilities: [
        { name: 'Precision Split', desc: 'Can calculate service tax up to 3 decimal places.', icon: <Target size={18} /> },
        { name: 'Social Magnet', desc: 'Invites are 40% more likely to be accepted instantly.', icon: <Award size={18} /> }
      ]
    },
    {
      id: 'ironbank',
      name: 'IRON BANK',
      role: 'SENTINEL',
      color: 'from-checkpointYellow/20 to-transparent',
      accent: 'text-checkpointYellow',
      description: "Awarded to those with unwavering financial integrity. This badge signifies a user who has never disputed a bill and maintains a massive Trust Score.",
      mainAsset: (
        <div className="scale-[2.5] animate-float drop-shadow-[0_0_30px_rgba(255,216,35,0.4)]">
           <Badge type="SHIELD" tier="GOLD" size="xl" />
        </div>
      ),
      stats: [
        { label: 'TIER', value: 'GOLD' },
        { label: 'RARITY', value: '12.5%' }
      ],
      abilities: [
        { name: 'Debt Immunity', desc: 'Debts are highlighted in gold for better visibility.', icon: <Shield size={18} /> },
        { name: 'Merchant Trust', desc: 'Faster verification for high-value mamak bills.', icon: <Crown size={18} /> }
      ]
    },
    {
      id: 'speedy',
      name: 'SPEEDY SETTLER',
      role: 'DUELIST',
      color: 'from-checkpointPink/20 to-transparent',
      accent: 'text-checkpointPink',
      description: "The fastest hands in the West (of Malaysia). You settle your debts before the receipt ink is even dry. Truly a DuitNow speedrun champion.",
      mainAsset: (
        <div className="scale-[2.5] animate-float drop-shadow-[0_0_30px_rgba(255,35,177,0.4)]">
           <Badge type="LIGHTNING" tier="SILVER" size="xl" />
        </div>
      ),
      stats: [
        { label: 'AVG SPEED', value: '< 1 HR' },
        { label: 'RARITY', value: '18.5%' }
      ],
      abilities: [
        { name: 'Sonic Settle', desc: 'Confirmation time reduced by 90% globally.', icon: <Zap size={18} /> },
        { name: 'Mamak Dash', desc: 'Unlock special high-contrast themes for night bills.', icon: <Target size={18} /> }
      ]
    }
  ];

  const current = agents[activeAgentIdx];

  const handleAgentSwitch = (idx: number) => {
    if (idx === activeAgentIdx) return;
    setIsChanging(true);
    setTimeout(() => {
      setActiveAgentIdx(idx);
      setIsChanging(false);
    }, 400);
  };

  return (
    <div className={`flex flex-col h-full bg-black font-sans relative overflow-hidden select-none`}>
      {/* Dynamic Background Glow */}
      <div className={`absolute inset-0 bg-gradient-to-t ${current.color} transition-all duration-700 ease-ios`}></div>
      <div className="absolute inset-0 grid-overlay opacity-20 pointer-events-none"></div>
      
      {/* Scanning Line */}
      <div className="absolute inset-0 pointer-events-none overflow-hidden z-10 opacity-[0.05]">
          <div className="w-full h-32 bg-white animate-scanline"></div>
      </div>

      {/* Header Bar */}
      <div className="flex items-center justify-between p-6 z-30">
        <div className="flex items-center gap-3">
            <Globe size={20} className={current.accent} />
            <span className="text-sm font-black tracking-[0.3em] uppercase italic">CHECKPOINT // 2025</span>
        </div>
        <button onClick={onBack} className="p-2 bg-white/5 rounded-full hover:bg-white/10 transition-all active:scale-90">
            <ArrowLeft size={24} strokeWidth={3} />
        </button>
      </div>

      {/* Main Agent Content Area */}
      <div className={`flex-1 flex flex-col items-center justify-center p-8 transition-all duration-400 relative z-20 ${isChanging ? 'opacity-0 scale-95 translate-x-10' : 'opacity-100 scale-100 translate-x-0'}`}>
        
        {/* Background Name Text (Agent Backing) */}
        <div className="absolute inset-0 flex items-center justify-center pointer-events-none overflow-hidden">
            <h2 className={`text-[12rem] font-black italic opacity-[0.03] uppercase tracking-tighter whitespace-nowrap`}>
                {current.name}
            </h2>
        </div>

        {/* Large Main Graphic */}
        <div className="mb-12 relative">
            <div className="animate-in zoom-in-75 duration-700 ease-spring">
                {current.mainAsset}
            </div>
        </div>

        {/* Name and Role Labels */}
        <div className="text-center space-y-2">
            <div className={`inline-block px-3 py-1 bg-white/5 border border-white/10 rounded uppercase text-[10px] font-black tracking-[0.2em] mb-2 ${current.accent}`}>
                {current.role}
            </div>
            <h1 className="text-5xl font-black italic tracking-tighter uppercase leading-none drop-shadow-2xl">
                {current.name}
            </h1>
            <p className="text-slate-400 text-sm max-w-[280px] font-medium leading-relaxed mt-4">
                {current.description}
            </p>
        </div>
      </div>

      {/* Abilities Drawer (Slide Up) */}
      <div className={`p-6 bg-slate-900/40 backdrop-blur-xl border-t border-white/5 z-30 transition-transform duration-500 ${isChanging ? 'translate-y-full' : 'translate-y-0'}`}>
          <div className="flex justify-between items-center mb-6">
              <div className="flex gap-10">
                  {current.stats.map((stat, i) => (
                      <div key={i} className="flex flex-col">
                          <span className="text-[10px] font-black text-slate-500 uppercase tracking-widest">{stat.label}</span>
                          <span className="text-xl font-mono font-black">{stat.value}</span>
                      </div>
                  ))}
              </div>
              <button className={`p-2 rounded-xl bg-white/5 hover:bg-white/10 transition-all ${current.accent}`}>
                  <Share2 size={20} />
              </button>
          </div>

          <div className="grid grid-cols-2 gap-4">
              {current.abilities.map((ability, i) => (
                  <div key={i} className="flex gap-4 p-4 bg-black/40 border border-white/5 rounded-2xl group hover:border-white/20 transition-all">
                      <div className={`h-10 w-10 rounded-xl flex items-center justify-center bg-white/5 ${current.accent}`}>
                          {ability.icon}
                      </div>
                      <div>
                          <h4 className="text-[11px] font-black uppercase tracking-wider mb-1">{ability.name}</h4>
                          <p className="text-[9px] text-slate-500 font-bold leading-tight uppercase">{ability.desc}</p>
                      </div>
                  </div>
              ))}
          </div>
      </div>

      {/* Bottom Character Selector Carousel */}
      <div className="p-6 bg-black z-40 border-t border-white/10 flex justify-center gap-4">
          {agents.map((agent, i) => (
              <button
                key={agent.id}
                onClick={() => handleAgentSwitch(i)}
                className={`
                    relative w-16 h-20 border-2 transition-all duration-300 overflow-hidden
                    ${activeAgentIdx === i 
                        ? `border-current ${agent.accent} scale-110 shadow-[0_0_20px_currentColor]` 
                        : 'border-white/10 grayscale opacity-40 hover:grayscale-0 hover:opacity-100 hover:border-white/30'}
                `}
              >
                  {/* Avatar Preview */}
                  <div className="w-full h-full bg-slate-900 flex items-center justify-center p-1">
                       {i === 0 ? (
                           <div className="w-full h-full bg-slate-800 flex items-center justify-center text-xs font-black">USER</div>
                       ) : (
                           <div className="scale-50">
                               <Badge type={i === 1 ? 'SHIELD' : 'LIGHTNING'} tier={i === 1 ? 'GOLD' : 'SILVER'} size="md" />
                           </div>
                       )}
                  </div>
                  {/* Active Indicator Bar */}
                  {activeAgentIdx === i && (
                      <div className="absolute bottom-0 left-0 right-0 h-1 bg-current"></div>
                  )}
              </button>
          ))}
      </div>

      {/* Music Credit Footer */}
      <div className="absolute bottom-1 left-1/2 -translate-x-1/2 text-[8px] font-black opacity-30 uppercase tracking-[0.3em] italic pointer-events-none">
          SPLITLAH PROTOCOL // SYSTEM_ONLINE
      </div>
    </div>
  );
};
