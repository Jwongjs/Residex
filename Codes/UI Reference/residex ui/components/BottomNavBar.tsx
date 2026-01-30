
import React from 'react';
import { Home, Users, Menu } from 'lucide-react';
import { DashboardTab } from '../types';

interface BottomNavBarProps {
  activeTab: DashboardTab;
  onTabChange: (tab: DashboardTab) => void;
}

export const BottomNavBar: React.FC<BottomNavBarProps> = ({ activeTab, onTabChange }) => {
  // This component is now largely hidden/integrated into SyncHub, 
  // but we keep it for structure if needed, or render null if handled in SyncHub.
  // Based on the spec "No Tab Bar ... minimized to just 3 dots", this is handled visually in SyncHub.tsx
  // We will return null here to avoid double rendering, as SyncHub handles the bottom layout.
  return null; 
};
