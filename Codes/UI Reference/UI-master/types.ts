
import React from 'react';

export enum AppMode { 
  RPG = 'RPG', 
  EXECUTIVE = 'EXECUTIVE' 
}

export interface User {
  id: string;
  name: string;
  avatarInitials: string;
  profileImage?: string;
  color?: string;
  phone: string;
  studentId?: string;
  fiscalPoints: number;
  harmonyPoints: number;
  rank?: 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM' | 'DIAMOND';
  stats?: {
      streak: number;
      totalPayments: number;
      choresCompleted: number;
      disputesWon: number;
      ranking: number;
  };
  isGuest?: boolean;
  trustScore?: number;
}

export interface Group {
  id: string;
  name: string;
  memberIds: string[];
  emoji?: string;
  color?: string;
  unitAddress?: string;
  landlordId?: string;
  icon?: string;
  createdBy?: string;
}

export interface Bill {
  id: string;
  title: string;
  location: string;
  totalAmount: number;
  userShare: number;
  date: string;
  status: 'PENDING' | 'SETTLED' | 'VERIFYING';
  participantsCount: number;
  imageUrl: string;
  isRent?: boolean;
}

export enum FilterType {
  ALL = 'All',
  UNITS = 'Units',
  TENANTS = 'Tenants',
  PENDING = 'Pending',
  CHORES = 'Chores',
  FRIENDS = 'Friends',
  GROUPS = 'Groups',
  SETTLED = 'Settled'
}

export interface Assignment {
  [itemId: string]: {
    [userId: string]: number;
  };
}

export interface PaymentAssignment {
  [userId: string]: string;
}

export interface BreakdownItem {
  id: string;
  userId: string;
  amount: number;
  date: string;
  status: 'PENDING' | 'PAID';
  billId?: string;
  billTitle?: string;
  paymentMethodId: string;
  groupId?: string;
}

export type ViewState = 
  | 'SPLASH'
  | 'LOGIN'
  | 'REGISTER'
  | 'DASHBOARD' 
  | 'SELECT_MEMBERS' 
  | 'NEW_BILL_OPTIONS' 
  | 'SCAN_CAMERA' 
  | 'EDIT_RECEIPT' 
  | 'ASSIGN_ITEMS'
  | 'BILL_SUMMARY'
  | 'PAYMENT_BREAKDOWN'
  | 'GAMIFICATION'
  | 'CHORE_LOG'
  | 'BOUNTY_BOARD_DETAIL'
  | 'MISSION_CONTROL_DETAIL'
  | 'SUPPORT_CENTER_DETAIL'
  | 'MY_TASKS_DETAIL'
  | 'LIQUIDITY_OVERVIEW'
  | 'LIQUIDITY_DETAIL'
  | 'PAYMENTS_DUE_DETAIL';

export type TrophyTier = 'BRONZE' | 'SILVER' | 'GOLD' | 'PLATINUM';
export type BadgeType = 'TROPHY' | 'SHIELD' | 'LIGHTNING' | 'DIAMOND' | 'STAR';

export interface Achievement {
  id: string;
  title: string;
  description: string;
  tier: TrophyTier;
  badgeType: BadgeType;
  rarityPercent: number;
  rewards: string[];
}

export interface PaymentMethodOption {
  id: string;
  label: string;
  description: string;
  iconName: string;
  color: string;
}

export const PAYMENT_OPTIONS: PaymentMethodOption[] = [
  { id: 'tng', label: 'Touch \'n Go', description: 'Malaysia\'s favorite e-wallet', iconName: 'wallet', color: 'from-blue-400 to-blue-600' },
  { id: 'mae', label: 'MAE', description: 'Maybank QR Pay', iconName: 'qr', color: 'from-yellow-400 to-yellow-600' },
  { id: 'duitnow', label: 'DuitNow', description: 'Instant bank transfer', iconName: 'bank', color: 'from-pink-500 to-rose-600' },
  { id: 'cash', label: 'Cash', description: 'Physical currency', iconName: 'cash', color: 'from-emerald-400 to-teal-600' }
];
