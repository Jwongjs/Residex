
import React from 'react';
import { LayoutGrid, Users, Radio } from 'lucide-react';
import { User, Group } from '../types';
import { Header } from './Header';
import { BalanceCard } from './BalanceCard';
import { SummaryCards } from './SummaryCards';
import { CalendarWidget } from './CalendarWidget';
import { LiquidityWidget } from './LiquidityWidget';
import { ReportWidget } from './ReportWidget';
import { FriendsList } from './FriendsList';

interface TenantDashboardProps {
  user: User;
  friends: User[];
  groups: Group[];
  onOpenSync: () => void;
  onOpenCommunity: () => void;
}

export const TenantDashboard: React.FC<TenantDashboardProps> = ({ 
  user, friends, groups, onOpenSync, onOpenCommunity 
}) => {
  return (
    <div className="h-full w-full flex flex-col bg-[#000212] relative overflow-hidden">
        {/* Background Ambient */}
        <div className="absolute top-0 left-0 right-0 h-[600px] bg-[radial-gradient(circle_at_top,_var(--tw-gradient-stops))] from-indigo-900/40 via-[#000212] to-[#000212] pointer-events-none"></div>

        {/* Scrollable Content */}
        <div className="flex-1 overflow-y-auto no-scrollbar pb-32 px-6 relative z-10">
            <Header 
                user={user} 
                onProfileClick={() => {}} 
                onGamificationClick={() => {}} 
            />
            
            <BalanceCard 
                userName={user.name} 
                fiscalScore={user.fiscalPoints} 
                harmonyScore={user.harmonyPoints} 
                tenants={friends} 
                onCreateBill={() => {}}
                onViewScore={() => {}}
            />

            <div className="h-32 mb-6">
                <SummaryCards 
                    youOwe={145.50} 
                    pendingTasks={3} 
                    onViewYouOwe={() => {}} 
                    onViewTasks={() => {}} 
                />
            </div>

            <FriendsList 
                friends={friends} 
                onAddFriend={() => {}} 
                onViewHistory={() => {}} 
            />

            <CalendarWidget onOpenDetail={() => {}} />
            <LiquidityWidget onOpenDetail={() => {}} />
            <ReportWidget onOpenDetail={() => {}} />
        </div>

        {/* Bottom Navigation Bar */}
        <div className="absolute bottom-0 left-0 right-0 h-[15%] z-20 flex flex-col items-center justify-end pb-6 bg-gradient-to-t from-black via-black/90 to-transparent">
            <div className="flex w-full justify-center gap-16 items-center pb-2">
                {/* Left: Dashboard (Active) */}
                <div className="relative">
                    <div className="absolute -inset-4 bg-indigo-500/20 rounded-full blur-lg pointer-events-none"></div>
                    <button className="relative text-indigo-400 p-2">
                        <LayoutGrid size={28} fill="currentColor" className="drop-shadow-[0_0_10px_rgba(99,102,241,0.5)]" />
                    </button>
                </div>

                {/* Middle: Sync Hub */}
                <button 
                    onClick={onOpenSync} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <Radio size={24} />
                </button>

                {/* Right: Community */}
                <button 
                    onClick={onOpenCommunity} 
                    className="p-3 rounded-2xl text-slate-500 hover:text-white hover:bg-white/5 transition-all"
                >
                    <Users size={24} />
                </button>
            </div>
        </div>
    </div>
  );
};
