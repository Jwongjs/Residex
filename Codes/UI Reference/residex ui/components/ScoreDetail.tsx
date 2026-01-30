
import React, { useState, useEffect } from 'react';
import { ArrowLeft, ShieldCheck, Activity, TrendingUp, Info, Lock, Globe, EyeOff, Users, ChevronRight, Zap } from 'lucide-react';
import { User } from '../types';

interface ScoreDetailProps {
  user: User;
  initialTab?: 'FISCAL' | 'HARMONY';
  onBack: () => void;
}

type TabType = 'FISCAL' | 'HARMONY';

export const ScoreDetail: React.FC<ScoreDetailProps> = ({ user, initialTab = 'FISCAL', onBack }) => {
  const [activeTab, setActiveTab] = useState<TabType>(initialTab);
  const [isVisible, setIsVisible] = useState(false);
  
  // Privacy Settings State
  const [visibility, setVisibility] = useState<'PUBLIC' | 'HOUSE' | 'PRIVATE'>('HOUSE');
  const [anonymousReviews, setAnonymousReviews] = useState(true);

  useEffect(() => {
    setIsVisible(true);
  }, []);

  const getScoreData = () => {
    if (activeTab === 'FISCAL') {
      return {
        score: user.fiscalPoints,
        max: 1000,
        title: 'Fiscal Score',
        desc: 'Measures financial reliability and payment habits.',
        color: 'from-indigo-500 to-purple-600',
        accent: 'text-indigo-400',
        bgGlow: 'bg-indigo-500/20',
        icon: <Activity size={24} />,
        tier: getTier(user.fiscalPoints),
        history: [750, 780, 810, 825, 830, 850],
        breakdown: [
          { label: 'Payment Punctuality', weight: '40%', value: 95, color: 'bg-emerald-500' },
          { label: 'Consistency Streaks', weight: '25%', value: 80, color: 'bg-blue-500' },
          { label: 'Contribution Fairness', weight: '20%', value: 100, color: 'bg-purple-500' },
          { label: 'Method Reliability', weight: '10%', value: 90, color: 'bg-amber-500' },
          { label: 'Historical Trend', weight: '5%', value: 70, color: 'bg-rose-500' },
        ],
        tips: [
            "Maintain a 3-month streak of paying within 1 hour.",
            "Verify payments faster to boost reliability score."
        ]
      };
    } else {
      return {
        score: user.harmonyPoints,
        max: 1000,
        title: 'Harmony Score',
        desc: 'Reflects household responsibility and social standing.',
        color: 'from-blue-500 to-cyan-500',
        accent: 'text-blue-400',
        bgGlow: 'bg-blue-500/20',
        icon: <ShieldCheck size={24} />,
        tier: getTier(user.harmonyPoints),
        history: [600, 650, 700, 720, 780, 800],
        breakdown: [
          { label: 'Chore Completion', weight: '35%', value: 85, color: 'bg-cyan-500' },
          { label: 'Housemate Ratings', weight: '30%', value: 92, color: 'bg-indigo-500' },
          { label: 'Rule Adherence', weight: '20%', value: 98, color: 'bg-emerald-500' },
          { label: 'Tenure Stability', weight: '10%', value: 100, color: 'bg-amber-500' },
          { label: 'Community Contrib.', weight: '5%', value: 60, color: 'bg-rose-500' },
        ],
        tips: [
            "Complete 5 chores in a row without reminders.",
            "Host a community event to boost contribution."
        ]
      };
    }
  };

  const getTier = (score: number) => {
      if (score >= 900) return { label: 'PERFECT', color: 'text-emerald-400' };
      if (score >= 800) return { label: 'EXCELLENT', color: 'text-indigo-400' };
      if (score >= 700) return { label: 'GOOD', color: 'text-blue-400' };
      if (score >= 600) return { label: 'FAIR', color: 'text-amber-400' };
      return { label: 'POOR', color: 'text-rose-400' };
  };

  const data = getScoreData();
  const percentage = (data.score / data.max) * 100;
  const radius = 80;
  const circumference = 2 * Math.PI * radius;
  const strokeDashoffset = circumference - (percentage / 100) * circumference;

  return (
    <div className="flex flex-col h-full bg-[#02040a] relative overflow-hidden font-sans">
      {/* Dynamic Background Glow */}
      <div className={`absolute top-0 left-0 right-0 h-[600px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] ${activeTab === 'FISCAL' ? 'from-indigo-900/60' : 'from-blue-900/60'} via-[#02040a] to-[#02040a] transition-colors duration-700 pointer-events-none`}></div>

      {/* Header */}
      <div className="flex items-center justify-between p-6 relative z-10">
        <button 
            onClick={onBack} 
            className="h-10 w-10 rounded-full bg-white/5 border border-white/10 flex items-center justify-center text-slate-300 hover:text-white transition-all active:scale-90"
        >
            <ArrowLeft size={20} />
        </button>
        <h1 className="text-white font-black text-lg uppercase tracking-widest">Reputation</h1>
        <div className="h-10 w-10"></div> 
      </div>

      <div className="flex-1 overflow-y-auto no-scrollbar px-6 pb-24 relative z-10 space-y-8">
        
        {/* Tab Switcher */}
        <div className="flex p-1 bg-white/5 backdrop-blur-md rounded-2xl border border-white/5">
            <button 
                onClick={() => setActiveTab('FISCAL')}
                className={`flex-1 py-3 rounded-xl text-xs font-black uppercase tracking-widest flex items-center justify-center gap-2 transition-all duration-300 ${activeTab === 'FISCAL' ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-500/20' : 'text-slate-500 hover:text-slate-300'}`}
            >
                <Activity size={14} /> Fiscal
            </button>
            <button 
                onClick={() => setActiveTab('HARMONY')}
                className={`flex-1 py-3 rounded-xl text-xs font-black uppercase tracking-widest flex items-center justify-center gap-2 transition-all duration-300 ${activeTab === 'HARMONY' ? 'bg-blue-600 text-white shadow-lg shadow-blue-500/20' : 'text-slate-500 hover:text-slate-300'}`}
            >
                <ShieldCheck size={14} /> Harmony
            </button>
        </div>

        {/* Main Score Visualizer */}
        <div className="flex flex-col items-center justify-center py-4">
            <div className="relative w-64 h-64 flex items-center justify-center group">
                {/* Glow behind */}
                <div className={`absolute inset-0 rounded-full blur-[60px] opacity-20 ${data.color.replace('from-', 'bg-').split(' ')[0]} animate-pulse`}></div>
                
                <svg className="w-full h-full transform -rotate-90 drop-shadow-2xl" viewBox="0 0 256 256">
                    {/* Background Track */}
                    <circle
                        cx="128"
                        cy="128"
                        r={radius}
                        stroke="rgba(255,255,255,0.05)"
                        strokeWidth="12"
                        fill="none"
                    />
                    {/* Progress Track */}
                    <circle
                        cx="128"
                        cy="128"
                        r={radius}
                        stroke="url(#gradient)"
                        strokeWidth="12"
                        fill="none"
                        strokeDasharray={circumference}
                        strokeDashoffset={isVisible ? strokeDashoffset : circumference}
                        strokeLinecap="round"
                        className="transition-all duration-1000 ease-out"
                    />
                    <defs>
                        <linearGradient id="gradient" x1="0%" y1="0%" x2="100%" y2="0%">
                            <stop offset="0%" stopColor={activeTab === 'FISCAL' ? '#6366f1' : '#3b82f6'} />
                            <stop offset="100%" stopColor={activeTab === 'FISCAL' ? '#a855f7' : '#22d3ee'} />
                        </linearGradient>
                    </defs>
                </svg>

                <div className="absolute inset-0 flex flex-col items-center justify-center text-center">
                    <span className={`text-[10px] font-black uppercase tracking-widest mb-1 ${data.tier.color}`}>{data.tier.label}</span>
                    <span className="text-6xl font-black text-white tracking-tighter drop-shadow-lg leading-none">{data.score}</span>
                    <span className="text-slate-500 text-xs font-bold mt-1">/ {data.max}</span>
                </div>
            </div>
            <p className="text-center text-slate-400 text-xs max-w-[200px] leading-relaxed mt-2">{data.desc}</p>
        </div>

        {/* Breakdown Section */}
        <div className="bg-slate-900/40 backdrop-blur-md border border-white/5 rounded-[2rem] p-6">
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-6 flex items-center gap-2">
                <TrendingUp size={16} className={data.accent} /> Score Breakdown
            </h3>
            <div className="space-y-5">
                {data.breakdown.map((item, idx) => (
                    <div key={idx} className="group">
                        <div className="flex justify-between items-end mb-1.5">
                            <div>
                                <span className="text-slate-300 text-xs font-bold block">{item.label}</span>
                                <span className="text-[9px] text-slate-500 font-bold uppercase tracking-wider">{item.weight} Weight</span>
                            </div>
                            <span className="text-white font-mono font-bold text-xs">{item.value}/100</span>
                        </div>
                        <div className="w-full bg-slate-800 h-1.5 rounded-full overflow-hidden">
                            <div 
                                className={`h-full ${item.color} transition-all duration-1000 ease-out shadow-[0_0_10px_currentColor]`} 
                                style={{ width: isVisible ? `${item.value}%` : '0%' }}
                            ></div>
                        </div>
                    </div>
                ))}
            </div>
        </div>

        {/* History Graph (Simplified visual) */}
        <div className="bg-slate-900/40 backdrop-blur-md border border-white/5 rounded-[2rem] p-6">
             <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4">6 Month Trend</h3>
             <div className="h-32 flex items-end justify-between gap-2 px-2">
                 {data.history.map((val, i) => {
                     const hPercent = (val / 1000) * 100;
                     return (
                         <div key={i} className="flex-1 flex flex-col items-center gap-2 group">
                             <div className="relative w-full flex justify-center">
                                 <div 
                                    className={`w-2 rounded-t-full transition-all duration-700 ${activeTab === 'FISCAL' ? 'bg-indigo-500 group-hover:bg-indigo-400' : 'bg-blue-500 group-hover:bg-blue-400'}`}
                                    style={{ height: `${hPercent}%`, opacity: 0.3 + (i * 0.1) }}
                                 ></div>
                             </div>
                             <span className="text-[8px] font-bold text-slate-500 uppercase">M{i+1}</span>
                         </div>
                     )
                 })}
             </div>
        </div>

        {/* Improvement Tips */}
        <div className={`rounded-[2rem] p-6 border border-white/5 ${data.bgGlow}`}>
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-4 flex items-center gap-2">
                <Zap size={16} className="text-yellow-400" /> Boost Your Score
            </h3>
            <div className="space-y-3">
                {data.tips.map((tip, i) => (
                    <div key={i} className="flex gap-3 items-start">
                        <div className="mt-1 h-1.5 w-1.5 rounded-full bg-yellow-400 shrink-0"></div>
                        <p className="text-xs text-slate-300 font-medium leading-relaxed">{tip}</p>
                    </div>
                ))}
            </div>
        </div>

        {/* Privacy Controls */}
        <div className="border-t border-white/5 pt-6">
            <h3 className="text-white font-black text-sm uppercase tracking-widest mb-6 flex items-center gap-2">
                <Lock size={16} className="text-slate-400" /> Privacy & Visibility
            </h3>
            
            <div className="space-y-4">
                <div className="bg-black/40 rounded-2xl p-4 flex items-center justify-between border border-white/5">
                    <div className="flex items-center gap-3">
                        <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-slate-400">
                            {visibility === 'PUBLIC' ? <Globe size={20} /> : visibility === 'HOUSE' ? <Users size={20} /> : <EyeOff size={20} />}
                        </div>
                        <div>
                            <span className="text-white font-bold text-xs block mb-0.5">Score Visibility</span>
                            <span className="text-[9px] text-slate-500 font-bold uppercase tracking-wider">{visibility}</span>
                        </div>
                    </div>
                    <button 
                        onClick={() => setVisibility(prev => prev === 'PUBLIC' ? 'HOUSE' : prev === 'HOUSE' ? 'PRIVATE' : 'PUBLIC')}
                        className="px-3 py-1.5 bg-white/10 rounded-lg text-[10px] font-bold text-white hover:bg-white/20 transition-colors uppercase"
                    >
                        Change
                    </button>
                </div>

                <div className="bg-black/40 rounded-2xl p-4 flex items-center justify-between border border-white/5">
                    <div className="flex items-center gap-3">
                        <div className="h-10 w-10 rounded-xl bg-white/5 flex items-center justify-center text-slate-400">
                            <Info size={20} />
                        </div>
                        <div>
                            <span className="text-white font-bold text-xs block mb-0.5">Anonymous Reviews</span>
                            <span className="text-[9px] text-slate-500 font-bold uppercase tracking-wider">{anonymousReviews ? 'Enabled' : 'Disabled'}</span>
                        </div>
                    </div>
                    <button 
                        onClick={() => setAnonymousReviews(!anonymousReviews)}
                        className={`w-10 h-6 rounded-full p-1 transition-colors ${anonymousReviews ? 'bg-emerald-500' : 'bg-slate-700'}`}
                    >
                        <div className={`w-4 h-4 bg-white rounded-full transition-transform ${anonymousReviews ? 'translate-x-4' : 'translate-x-0'}`}></div>
                    </button>
                </div>
            </div>
            
            <p className="text-[9px] text-slate-500 mt-6 text-center leading-relaxed max-w-xs mx-auto">
                Your Fiscal Score is portable and can be used for future rental applications. Harmony Score remains private to your household unless shared.
            </p>
        </div>

      </div>
    </div>
  );
};
