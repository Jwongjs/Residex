
import React, { useState } from 'react';
import { Users, Megaphone, Calendar, MessageSquare, Heart, Share2, LayoutGrid, Radio } from 'lucide-react';

interface CommunityBoardPageProps {
  onOpenDashboard: () => void;
  onOpenSync: () => void;
}

export const CommunityBoardPage: React.FC<CommunityBoardPageProps> = ({ onOpenDashboard, onOpenSync }) => {
  const [activeTab, setActiveTab] = useState<'FEED' | 'EVENTS'>('FEED');

  const posts = [
    { 
        id: 1, 
        author: 'Management', 
        avatar: 'M', 
        color: 'bg-indigo-600',
        title: 'Water Disruption Notice: Zone A', 
        desc: 'Scheduled maintenance on Oct 25, 10 AM - 2 PM. Please store water accordingly as supply will be cut off for pipe replacement.', 
        type: 'ALERT', 
        tagColor: 'text-rose-400 bg-rose-500/10 border-rose-500/20',
        time: '2h ago', 
        likes: 45, 
        comments: 12 
    },
    { 
        id: 2, 
        author: 'Sarah Tan', 
        avatar: 'ST', 
        color: 'bg-purple-600',
        title: 'Badminton Session tonight! 🏸', 
        desc: 'Booking court at 8PM tonight. Looking for 2 more players! Intermediate level preferred but open to all.', 
        type: 'EVENT', 
        tagColor: 'text-emerald-400 bg-emerald-500/10 border-emerald-500/20',
        time: '4h ago', 
        likes: 18, 
        comments: 5 
    },
  ];

  return (
    <div className="flex flex-col h-full relative overflow-hidden bg-[#02040a]">
      {/* Sapphire/Amethyst Gradient */}
      <div className="absolute top-0 left-0 right-0 h-[500px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/30 via-[#02040a] to-[#02040a] pointer-events-none"></div>

      {/* Header */}
      <div className="pt-8 pb-4 px-6 sticky top-0 z-30 backdrop-blur-md bg-[#02040a]/80 border-b border-white/5">
        <div className="flex items-center gap-3 mb-6">
            <div className="h-10 w-10 rounded-xl bg-indigo-500/20 text-indigo-300 flex items-center justify-center border border-indigo-500/30 shadow-lg shadow-indigo-900/20">
                <Users size={20} />
            </div>
            <div>
                <h1 className="text-white font-black text-xl tracking-tight">Community</h1>
                <p className="text-indigo-400 text-[10px] font-bold uppercase tracking-widest">Digital Board</p>
            </div>
        </div>
        
        {/* Tabs (Market Removed) */}
        <div className="flex gap-3">
            {[
                { id: 'FEED', label: 'Feed', icon: Megaphone },
                { id: 'EVENTS', label: 'Events', icon: Calendar },
            ].map(tab => (
                <button
                    key={tab.id}
                    onClick={() => setActiveTab(tab.id as any)}
                    className={`flex-1 flex items-center justify-center gap-2 py-3 rounded-xl text-xs font-bold transition-all ${
                        activeTab === tab.id 
                        ? 'bg-indigo-600 text-white shadow-lg shadow-indigo-900/20' 
                        : 'bg-white/5 text-slate-400 hover:bg-white/10'
                    }`}
                >
                    <tab.icon size={14} />
                    {tab.label}
                </button>
            ))}
        </div>
      </div>

      {/* Content - Card Style */}
      <div className="flex-1 overflow-y-auto no-scrollbar p-6 space-y-5 relative z-10 pb-32">
         {posts.map((post) => (
             <div key={post.id} className="bg-[#0f172a] border border-white/5 rounded-[2rem] p-6 shadow-lg relative overflow-hidden group">
                 {/* Header Row */}
                 <div className="flex justify-between items-start mb-4">
                     <div className="flex items-center gap-3">
                         <div className={`h-10 w-10 rounded-full flex items-center justify-center text-xs font-bold text-white shadow-md ${post.color}`}>
                             {post.avatar}
                         </div>
                         <div>
                             <h3 className="text-white font-bold text-sm leading-tight">{post.author}</h3>
                             <p className="text-slate-500 text-[10px] font-medium">{post.time}</p>
                         </div>
                     </div>
                     <span className={`px-2 py-1 rounded-lg text-[9px] font-black uppercase tracking-wider border ${post.tagColor}`}>
                         {post.type}
                     </span>
                 </div>

                 {/* Body */}
                 <div className="mb-5 pl-1">
                     <h4 className="text-white font-bold text-lg leading-tight mb-2">{post.title}</h4>
                     <p className="text-slate-400 text-xs leading-relaxed">{post.desc}</p>
                 </div>

                 {/* Footer Actions */}
                 <div className="flex items-center gap-5 border-t border-white/5 pt-4">
                     <button className="flex items-center gap-2 text-slate-400 hover:text-rose-400 transition-colors group/btn">
                         <Heart size={18} className="group-hover/btn:scale-110 transition-transform" />
                         <span className="text-xs font-bold">{post.likes}</span>
                     </button>
                     <button className="flex items-center gap-2 text-slate-400 hover:text-indigo-400 transition-colors group/btn">
                         <MessageSquare size={18} className="group-hover/btn:scale-110 transition-transform" />
                         <span className="text-xs font-bold">{post.comments}</span>
                     </button>
                     <button className="ml-auto text-slate-500 hover:text-white transition-colors">
                         <Share2 size={18} />
                     </button>
                 </div>
             </div>
         ))}
         
         <div className="py-8 text-center text-slate-600 text-xs font-medium uppercase tracking-widest opacity-50">
             End of Feed
         </div>
      </div>

      {/* Bottom Navigation Bar (Persistent) */}
      <div className="absolute bottom-0 left-0 right-0 h-[15%] z-20 flex flex-col items-center justify-end pb-6 bg-gradient-to-t from-black via-black/90 to-transparent">
            <div className="flex w-full justify-center gap-16 items-center pb-2">
                {/* Left: Dashboard */}
                <button 
                    onClick={onOpenDashboard} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <LayoutGrid size={24} />
                </button>
                
                {/* Middle: Sync */}
                <button 
                    onClick={onOpenSync} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <Radio size={24} />
                </button>

                {/* Right: Community (Active) */}
                <div className="relative">
                    <div className="absolute -inset-4 bg-indigo-500/20 rounded-full blur-lg pointer-events-none"></div>
                    <button className="relative text-indigo-400 p-2">
                        <Users size={28} className="drop-shadow-[0_0_10px_rgba(99,102,241,0.5)]" />
                    </button>
                </div>
            </div>
      </div>

    </div>
  );
};
