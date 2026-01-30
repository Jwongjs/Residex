
import React, { useState } from 'react';
import { Header } from './components/Header';
import { BalanceCard } from './components/BalanceCard';
import { SummaryCards } from './components/SummaryCards';
import { FilterSection } from './components/FilterSection';
import { FriendsList } from './components/FriendsList';
import { AddFriendModal } from './components/AddFriendModal';
import { GroupPickerModal } from './components/GroupPickerModal';
import { NewBillOptions } from './components/NewBillOptions';
import { ScanCamera } from './components/ScanCamera';
import { SelectMembers } from './components/SelectMembers';
import { GroupManagementCard } from './components/GroupManagementCard';
import { GroupEditor } from './components/GroupEditor';
import { Toast } from './components/Toast';
import { PaymentBreakdown } from './components/PaymentBreakdown';
import { GamificationHub } from './components/GamificationHub';
import { Login } from './components/Login';
import { Register } from './components/Register';
import { SplashScreen } from './components/SplashScreen'; 
import { AmbientBackground } from './components/AmbientBackground';
import { ChoreScheduler } from './components/ChoreScheduler';
import { PersonalChoreWidget } from './components/PersonalChoreWidget';
import { BountyBoard } from './components/BountyBoard';
import { MissionControl } from './components/MissionControl';
import { GroupLiquidityDetail } from './components/GroupLiquidityDetail';
import { PaymentsDueDetail } from './components/PaymentsDueDetail';
import { ReportWidget } from './components/ReportWidget';
import { BountyBoardDetail } from './components/BountyBoardDetail';
import { MissionControlDetail } from './components/MissionControlDetail';
import { SupportCenterDetail } from './components/SupportCenterDetail';
import { MyTasksDetail } from './components/MyTasksDetail';
import { CalendarWidget } from './components/CalendarWidget';
import { LiquidityWidget } from './components/LiquidityWidget';
import { LiquidityOverview } from './components/LiquidityOverview';
import { FilterType, User, Group, ViewState } from './types';

const INITIAL_USER: User = {
  id: 'u1',
  name: 'Ali Rahman',
  avatarInitials: 'AL',
  color: 'bg-gradient-to-br from-cyan-400 to-blue-600',
  phone: '+60123456789',
  fiscalPoints: 420,
  harmonyPoints: 380,
  rank: 'PLATINUM',
  stats: {
      streak: 12,
      totalPayments: 47,
      choresCompleted: 85,
      disputesWon: 0,
      ranking: 14
  }
};

const MOCK_TENANTS: User[] = [
  { id: 'u2', name: 'Sarah Tan', avatarInitials: 'ST', color: 'bg-gradient-to-br from-purple-400 to-indigo-600', phone: '+60120000002', fiscalPoints: 490, harmonyPoints: 450, rank: 'GOLD' },
  { id: 'u3', name: 'Raj Kumar', avatarInitials: 'RK', color: 'bg-gradient-to-br from-amber-400 to-orange-600', phone: '+60120000003', fiscalPoints: 310, harmonyPoints: 210, rank: 'SILVER' },
  { id: 'u4', name: 'David Wong', avatarInitials: 'DW', color: 'bg-gradient-to-br from-emerald-400 to-teal-600', phone: '+60120000004', fiscalPoints: 495, harmonyPoints: 480, rank: 'DIAMOND' }
];

const INITIAL_UNITS: Group[] = [
  { id: 'g1', name: 'Suite 4-2', memberIds: ['u1', 'u3', 'u4'], emoji: '🏠', color: 'bg-blue-500', unitAddress: 'Verdi Eco-Dominium' },
  { id: 'g2', name: 'Subang Loft', memberIds: ['u1', 'u2'], emoji: '🏢', color: 'bg-purple-500', unitAddress: 'The Grand Subang' }
];

export default function App() {
  const [history, setHistory] = useState<ViewState[]>(['LOGIN']);
  const [showSplash, setShowSplash] = useState(true);
  const [isRevealing, setIsRevealing] = useState(false);
  const [currentUser, setCurrentUser] = useState<User>(INITIAL_USER);
  const [tenants, setTenants] = useState<User[]>(MOCK_TENANTS);
  const [units, setUnits] = useState<Group[]>(INITIAL_UNITS);
  const [filter, setFilter] = useState<FilterType>(FilterType.ALL);
  const [activeTaskTab, setActiveTaskTab] = useState<'PERSONAL' | 'SHARED' | 'STATUS'>('PERSONAL');
  
  const [toast, setToast] = useState<{message: string, type: 'success' | 'info'} | null>(null);
  const [showAddFriendModal, setShowAddFriendModal] = useState(false);
  const [showGroupPicker, setShowGroupPicker] = useState(false);
  const [showGroupEditor, setShowGroupEditor] = useState(false);
  const [editingGroup, setEditingGroup] = useState<Group | null>(null);

  const view = history[history.length - 1];

  const pushView = (newView: ViewState) => {
    if (view === newView) return;
    setHistory(prev => [...prev, newView]);
  };

  const popView = () => {
    if (history.length <= 1) return;
    setHistory(prev => prev.slice(0, -1));
  };

  const handleLogin = (userData: { name: string; email: string; phone: string }) => {
    setCurrentUser(prev => ({
        ...prev,
        name: userData.name,
        phone: userData.phone,
        avatarInitials: userData.name.split(' ').map(n => n[0]).join('').substring(0, 2).toUpperCase()
    }));
    setHistory(['DASHBOARD']);
  };

  const handleFilterChange = (newFilter: FilterType) => {
      if (newFilter === FilterType.TENANTS) {
          setFilter(FilterType.TENANTS);
      } else if (newFilter === FilterType.UNITS) {
          setShowGroupPicker(true);
      } else {
          setFilter(newFilter);
      }
  };

  return (
    <div className="min-h-[100dvh] h-[100dvh] flex justify-center relative font-sans text-white overflow-hidden transition-all duration-700 bg-[#000212]">
      <AmbientBackground />
      {showSplash && <SplashScreen onSplitStart={() => setIsRevealing(true)} onFinish={() => setShowSplash(false)} />}

      <div className={`w-full max-w-md relative z-10 h-full flex flex-col ${isRevealing || !showSplash ? 'animate-app-reveal' : 'opacity-0'}`}>
        <div key={view} className="w-full h-full flex flex-col overflow-hidden">
          {view === 'LOGIN' && <Login onLogin={handleLogin} onSwitchToRegister={() => pushView('REGISTER')} />}
          {view === 'REGISTER' && <Register onRegister={handleLogin} onSwitchToLogin={() => popView()} />}
          
          {view === 'DASHBOARD' && (
            <div className="flex-1 overflow-y-auto no-scrollbar pb-32 px-4 sm:px-6">
              <Header user={currentUser} onProfileClick={() => pushView('GAMIFICATION')} onGamificationClick={() => pushView('GAMIFICATION')} />
              
              <div className="flex flex-col gap-2 mb-6">
                 <BalanceCard 
                    userName={currentUser.name} fiscalScore={currentUser.fiscalPoints} 
                    harmonyScore={currentUser.harmonyPoints} tenants={tenants}
                    onCreateBill={() => pushView('SELECT_MEMBERS')}
                  />
              </div>

              <div className="grid grid-cols-1 gap-4 mb-8">
                <SummaryCards 
                  youOwe={650.10} pendingTasks={3}
                  onViewYouOwe={() => pushView('PAYMENTS_DUE_DETAIL')}
                  onViewTasks={() => pushView('MY_TASKS_DETAIL')} 
                />
                <ReportWidget onOpenDetail={() => pushView('SUPPORT_CENTER_DETAIL')} />
              </div>

              <section className="rounded-[2.5rem] p-2 mb-8 border transition-all duration-500 shadow-2xl bg-slate-900/40 backdrop-blur-xl border-white/5">
                <div className="flex p-1 gap-1 bg-black/40 rounded-[1.8rem] mb-4">
                  {[
                    { id: 'PERSONAL', label: 'My Protocol' },
                    { id: 'SHARED', label: 'Marketplace' },
                    { id: 'STATUS', label: 'Mission Control' }
                  ].map(tab => (
                    <button
                      key={tab.id}
                      onClick={() => setActiveTaskTab(tab.id as any)}
                      className={`flex-1 py-3 rounded-[1.5rem] text-[10px] font-black uppercase tracking-[0.1em] transition-all duration-300 relative ${
                        activeTaskTab === tab.id 
                          ? 'bg-cyan-500 text-white shadow-lg shadow-cyan-900/40'
                          : 'text-slate-500 hover:text-slate-300'
                      }`}
                    >
                      <span className="relative z-10">{tab.label}</span>
                    </button>
                  ))}
                </div>

                <div className="px-2 pb-4">
                  {activeTaskTab === 'PERSONAL' && <PersonalChoreWidget onOpenDetail={() => pushView('MY_TASKS_DETAIL')} />}
                  {activeTaskTab === 'SHARED' && <BountyBoard onOpenDetail={() => pushView('BOUNTY_BOARD_DETAIL')} />}
                  {activeTaskTab === 'STATUS' && <MissionControl onOpenDetail={() => pushView('MISSION_CONTROL_DETAIL')} />}
                </div>
              </section>

              <CalendarWidget onOpenDetail={() => pushView('CHORE_LOG')} />
              <LiquidityWidget onOpenDetail={() => pushView('LIQUIDITY_OVERVIEW')} />

              <div className="space-y-4 mb-8 mt-8">
                <FriendsList friends={tenants} onAddFriend={() => setShowAddFriendModal(true)} onViewHistory={() => pushView('PAYMENT_BREAKDOWN')} />
                <GroupManagementCard groups={units} onManageGroup={(g) => { setEditingGroup(g); setShowGroupEditor(true); }} onCreateGroup={() => { setEditingGroup(null); setShowGroupEditor(true); }} />
              </div>

              <div className="px-2 mb-4">
                  <FilterSection activeFilter={filter} onFilterChange={handleFilterChange} />
              </div>
            </div>
          )}

          {view === 'CHORE_LOG' && <ChoreScheduler tenants={tenants} isFullPage={true} onBack={() => popView()} />}
          {view === 'LIQUIDITY_OVERVIEW' && <LiquidityOverview groups={units} onBack={() => popView()} onViewDetails={(id) => pushView('LIQUIDITY_DETAIL')} />}
          {view === 'LIQUIDITY_DETAIL' && <GroupLiquidityDetail onBack={() => popView()} />}
          {view === 'PAYMENTS_DUE_DETAIL' && <PaymentsDueDetail onBack={() => popView()} />}
          {view === 'BOUNTY_BOARD_DETAIL' && <BountyBoardDetail onBack={() => popView()} />}
          {view === 'MISSION_CONTROL_DETAIL' && <MissionControlDetail onBack={() => popView()} />}
          {view === 'SUPPORT_CENTER_DETAIL' && <SupportCenterDetail onBack={() => popView()} />}
          {view === 'MY_TASKS_DETAIL' && <MyTasksDetail onBack={() => popView()} />}
          
          {view === 'GAMIFICATION' && <GamificationHub user={currentUser} friends={tenants} onBack={() => popView()} />}
          {view === 'PAYMENT_BREAKDOWN' && <PaymentBreakdown mode="HISTORY" items={[]} users={tenants} groups={units} onBack={() => popView()} onMarkPaid={() => {}} onViewBill={() => {}} />}
          {view === 'SELECT_MEMBERS' && <SelectMembers currentUser={currentUser} existingFriends={tenants} existingGroups={units} onBack={() => popView()} onNext={() => pushView('NEW_BILL_OPTIONS')} onCreateGroup={() => {}} />}
          {view === 'NEW_BILL_OPTIONS' && <div className="px-6 h-full"><NewBillOptions onBack={() => popView()} onScan={() => pushView('SCAN_CAMERA')} onManual={() => {}} onUpload={() => {}} /></div>}
          {view === 'SCAN_CAMERA' && <ScanCamera onBack={() => popView()} onCapture={() => {}} />}
        </div>
      </div>

      {toast && <Toast message={toast.message} type={toast.type} onClose={() => setToast(null)} />}
      {showAddFriendModal && <AddFriendModal onAdd={(f) => setTenants([...tenants, f as User])} onClose={() => setShowAddFriendModal(false)} />}
      {showGroupPicker && <GroupPickerModal groups={units} onSelect={() => setShowGroupPicker(false)} onClose={() => setShowGroupPicker(false)} />}
      {showGroupEditor && <GroupEditor currentUser={currentUser} availableFriends={tenants} existingGroups={units} onSave={() => setShowGroupEditor(false)} onClose={() => setShowGroupEditor(false)} />}
    </div>
  );
}
