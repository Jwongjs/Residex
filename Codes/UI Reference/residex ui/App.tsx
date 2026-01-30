
import React, { useState } from 'react';
import { SyncHub } from './components/SyncHub';
import { RexInterface } from './components/RexInterface';
import { TenantDashboard } from './components/TenantDashboard';
import { CommunityBoardPage } from './components/CommunityBoardPage';
import { SplashScreen } from './components/SplashScreen';
import { Login } from './components/Login';
import { Register } from './components/Register';
import { User, ViewState, Group } from './types';

// Mock Data
const INITIAL_USER: User = {
  id: 'u1',
  name: 'Ali Rahman',
  avatarInitials: 'AL',
  color: 'bg-gradient-to-br from-indigo-500 to-purple-600',
  phone: '+60123456789',
  fiscalPoints: 850, 
  harmonyPoints: 780,
  syncState: 'SYNCED',
  rank: 'PLATINUM',
  role: 'TENANT',
  stats: {
      streak: 12,
      totalPayments: 47,
      choresCompleted: 85,
      disputesWon: 0,
      ranking: 14
  }
};

const MOCK_FRIENDS: User[] = [
    { id: 'u2', name: 'Sarah Tan', avatarInitials: 'ST', color: 'bg-gradient-to-br from-purple-400 to-indigo-600', phone: '', fiscalPoints: 720, harmonyPoints: 800, syncState: 'SYNCED' },
    { id: 'u3', name: 'Raj Kumar', avatarInitials: 'RK', color: 'bg-gradient-to-br from-amber-400 to-orange-600', phone: '', fiscalPoints: 650, harmonyPoints: 700, syncState: 'DRIFTING' },
    { id: 'u4', name: 'David Wong', avatarInitials: 'DW', color: 'bg-gradient-to-br from-emerald-400 to-teal-600', phone: '', fiscalPoints: 880, harmonyPoints: 900, syncState: 'SYNCED' },
];

const MOCK_GROUPS: Group[] = [
    { id: 'g1', name: 'Verdi House', memberIds: ['u1', 'u2', 'u3', 'u4'], emoji: '🏠', color: 'bg-blue-600' },
    { id: 'g2', name: 'Badminton Gang', memberIds: ['u1', 'u2'], emoji: '🏸', color: 'bg-emerald-500' }
];

export default function App() {
  const [history, setHistory] = useState<ViewState[]>(['LOGIN']);
  const [showSplash, setShowSplash] = useState(true);
  const [currentUser, setCurrentUser] = useState<User>(INITIAL_USER);
  const [rexContext, setRexContext] = useState<string | undefined>(undefined);

  const view = history[history.length - 1];

  const pushView = (newView: ViewState) => {
    setHistory(prev => [...prev, newView]);
  };

  const popView = () => {
    if (history.length <= 1) return;
    setHistory(prev => prev.slice(0, -1));
  };

  // Switch root view (clears history stack for main tabs)
  const switchRootView = (newView: ViewState) => {
      setHistory([newView]);
  };

  const handleLogin = (userData: any) => {
      const randomSync: 'SYNCED' | 'DRIFTING' | 'OUT_OF_SYNC' = Math.random() > 0.6 ? 'DRIFTING' : 'SYNCED';
      
      setCurrentUser({
          ...INITIAL_USER,
          ...userData,
          syncState: randomSync
      });
      setHistory(['SYNC_HUB']);
  };

  const openRex = (context?: string) => {
      setRexContext(context);
      pushView('REX_INTERFACE');
  };

  return (
    <div className="min-h-[100dvh] h-[100dvh] flex justify-center relative font-sans text-white overflow-hidden bg-[#000212]">
      {showSplash && <SplashScreen onSplitStart={() => {}} onFinish={() => setShowSplash(false)} />}

      <div className="w-full max-w-md relative z-10 h-full flex flex-col">
          {view === 'LOGIN' && <Login onLogin={handleLogin} onSwitchToRegister={() => pushView('REGISTER')} />}
          {view === 'REGISTER' && <Register onRegister={handleLogin} onSwitchToLogin={() => popView()} />}
          
          {/* Main Sync Hub (Home) */}
          {view === 'SYNC_HUB' && (
              <SyncHub 
                  user={currentUser} 
                  onAskRex={openRex}
                  onOpenCommunity={() => switchRootView('COMMUNITY')} 
                  onOpenDashboard={() => switchRootView('TENANT_DASHBOARD')}
              />
          )}

          {/* Functional Dashboard */}
          {view === 'TENANT_DASHBOARD' && (
              <TenantDashboard 
                  user={currentUser}
                  friends={MOCK_FRIENDS}
                  groups={MOCK_GROUPS}
                  onOpenSync={() => switchRootView('SYNC_HUB')}
                  onOpenCommunity={() => switchRootView('COMMUNITY')}
              />
          )}

          {/* The AI Core */}
          {view === 'REX_INTERFACE' && (
              <RexInterface 
                  user={currentUser} 
                  onClose={() => popView()} 
                  initialContext={rexContext} 
              />
          )}

          {/* Community Board - Now part of main nav */}
          {view === 'COMMUNITY' && (
              <CommunityBoardPage 
                  onOpenDashboard={() => switchRootView('TENANT_DASHBOARD')}
                  onOpenSync={() => switchRootView('SYNC_HUB')}
              />
          )}
          
          {/* Legacy mappings if needed, or remove them */}
          {/* ... other components ... */}
      </div>
    </div>
  );
}
